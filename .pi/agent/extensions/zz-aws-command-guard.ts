import { lstatSync } from "node:fs"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const AWS_NO_UI_REASON =
  "This AWS command can write to AWS or cannot be classified as read-only. It needs user confirmation in an interactive Pi session."
const AWS_DENIED_REASON =
  "User denied this AWS command. Do not retry it through another command, script, or tool."
const DELETE_BLOCK_REASON =
  "Recursive forced deletion requires explicit user confirmation in an interactive Pi session."

const READ_ONLY_OPERATION_PREFIXES = [
  "batch-get",
  "check",
  "describe",
  "filter",
  "get",
  "head",
  "list",
  "lookup",
  "query",
  "scan",
  "search",
  "select",
  "simulate",
  "test",
  "validate",
]

const GLOBAL_OPTIONS_WITH_VALUES = new Set([
  "--ca-bundle",
  "--cli-binary-format",
  "--cli-connect-timeout",
  "--cli-read-timeout",
  "--color",
  "--endpoint-url",
  "--output",
  "--profile",
  "--query",
  "--region",
])

const S3_TRANSFER_OPTIONS_WITH_VALUES = new Set([
  ...GLOBAL_OPTIONS_WITH_VALUES,
  "--exclude",
  "--include",
  "--expected-size",
  "--page-size",
  "--request-payer",
  "--sse-c",
  "--sse-c-key",
  "--source-region",
])

// Keywords and wrappers that can stand before the real command word of a segment.
const LEADING_KEYWORDS = new Set(["!", "{", "}", "then", "do", "else", "elif", "if", "while", "until", "time"])
const COMMAND_WRAPPERS = new Set([
  "caffeinate",
  "command",
  "env",
  "exec",
  "nice",
  "nohup",
  "parallel",
  "rtk",
  "sudo",
  "timeout",
  "watch",
  "xargs",
])
const SHELLS = new Set(["bash", "dash", "sh", "zsh"])

export type AwsCommandClass = "none" | "read" | "ask"

type ShellParse = {
  segments: string[][]
  hasSubstitution: boolean
}

function parseShell(command: string): ShellParse {
  const segments: string[][] = []
  let tokens: string[] = []
  let token = ""
  let inToken = false
  let hasSubstitution = false

  const endToken = () => {
    if (inToken) tokens.push(token)
    token = ""
    inToken = false
  }
  const endSegment = () => {
    endToken()
    if (tokens.length > 0) segments.push(tokens)
    tokens = []
  }

  for (let i = 0; i < command.length; i++) {
    const char = command[i]
    if (char === "'") {
      const close = command.indexOf("'", i + 1)
      const stop = close < 0 ? command.length : close
      token += command.slice(i + 1, stop)
      inToken = true
      i = stop
    } else if (char === '"') {
      inToken = true
      for (i++; i < command.length && command[i] !== '"'; i++) {
        if (command[i] === "\\" && i + 1 < command.length) {
          token += command[++i]
        } else {
          if (command[i] === "`" || (command[i] === "$" && command[i + 1] === "(")) hasSubstitution = true
          token += command[i]
        }
      }
    } else if (char === "\\") {
      if (command[i + 1] !== "\n") token += command[i + 1] ?? ""
      inToken = true
      i++
    } else if (char === "`" || (char === "$" && command[i + 1] === "(")) {
      hasSubstitution = true
      token += char
      inToken = true
    } else if ((char === "<" || char === ">") && command[i + 1] === "(") {
      hasSubstitution = true
      token += char
      inToken = true
    } else if (";&|\n()".includes(char)) {
      endSegment()
    } else if (/\s/.test(char)) {
      endToken()
    } else {
      token += char
      inToken = true
    }
  }
  endSegment()
  return { segments, hasSubstitution }
}

function basename(word: string): string {
  return word.split("/").at(-1)?.toLowerCase() ?? ""
}

function isAssignment(word: string): boolean {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(word)
}

function positionalArgs(args: string[], optionsWithValues: Set<string>): string[] {
  const positional: string[] = []
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === "--") {
      positional.push(...args.slice(i + 1))
      break
    }
    if (arg.startsWith("-") && arg !== "-") {
      if (optionsWithValues.has(arg)) i++
      continue
    }
    if (/^\d*[<>]/.test(arg)) {
      // A redirection such as `> out.txt` or `2>/dev/null` is not an AWS argument.
      if (/^\d*[<>]+&?$/.test(arg)) i++
      continue
    }
    positional.push(arg)
  }
  return positional
}

function classifyAwsArgs(args: string[]): AwsCommandClass {
  let index = 0
  while (index < args.length && args[index].startsWith("-")) {
    const option = args[index]
    if (option === "--version") return "read"
    index += GLOBAL_OPTIONS_WITH_VALUES.has(option) ? 2 : 1
  }

  const service = args[index]?.toLowerCase()
  const operation = args[index + 1]?.toLowerCase()
  const rest = args.slice(index + 2)
  if (!service || service === "help") return "read"
  if (!operation) return "ask"
  if (operation === "help" || rest.at(-1) === "help") return "read"

  if (service === "sso" && (operation === "login" || operation === "logout")) return "read"
  if (service === "configure" && (operation === "list" || operation === "get" || operation === "list-profiles")) {
    return "read"
  }
  if (service === "s3" && (operation === "ls" || operation === "presign")) return "read"
  if (service === "logs" && operation === "tail") return "read"
  if (operation === "wait") return "read"

  if (service === "s3" && (operation === "cp" || operation === "sync")) {
    const [source, destination] = positionalArgs(rest, S3_TRANSFER_OPTIONS_WITH_VALUES)
    const downloads = source?.startsWith("s3://") === true && destination !== undefined && !destination.startsWith("s3://")
    return downloads ? "read" : "ask"
  }

  const readOnly = READ_ONLY_OPERATION_PREFIXES.some(
    (prefix) => operation === prefix || operation.startsWith(`${prefix}-`),
  )
  return readOnly ? "read" : "ask"
}

function strongest(a: AwsCommandClass, b: AwsCommandClass): AwsCommandClass {
  const rank = { none: 0, read: 1, ask: 2 }
  return rank[a] >= rank[b] ? a : b
}

function classifySegment(tokens: string[], depth: number): AwsCommandClass {
  let i = 0
  while (i < tokens.length && (isAssignment(tokens[i]) || LEADING_KEYWORDS.has(tokens[i]))) i++
  const word = tokens[i]
  if (word === undefined) return "none"
  const name = basename(word)
  const rest = tokens.slice(i + 1)

  if (name === "aws") return classifyAwsArgs(rest)

  if (COMMAND_WRAPPERS.has(name)) {
    // Wrapper options can take values, so find the wrapped aws call by name.
    const awsIndex = rest.findIndex((arg) => basename(arg) === "aws")
    return awsIndex < 0 ? "none" : classifyAwsArgs(rest.slice(awsIndex + 1))
  }

  if (SHELLS.has(name) || name === "eval") {
    const scriptIndex = name === "eval" ? 0 : rest.findIndex((arg) => /^-[A-Za-z]*c[A-Za-z]*$/.test(arg)) + 1
    if (scriptIndex <= 0 && name !== "eval") return "none"
    const script = name === "eval" ? rest.join(" ") : rest[scriptIndex]
    return script === undefined ? "none" : classify(script, depth + 1)
  }

  return "none"
}

function classify(command: string, depth: number): AwsCommandClass {
  if (depth > 4) return /\baws\b/i.test(command) ? "ask" : "none"

  const { segments, hasSubstitution } = parseShell(command)
  // A substitution can run aws in a place the segment parser does not inspect.
  if (hasSubstitution && /\baws\b/i.test(command)) return "ask"

  return segments.reduce<AwsCommandClass>(
    (result, segment) => strongest(result, classifySegment(segment, depth)),
    "none",
  )
}

/**
 * Classify the AWS CLI calls in a shell command.
 * "none" means no aws call, "read" means every aws call is read-only,
 * and "ask" means at least one call can write or cannot be classified.
 */
export function classifyAwsCommand(command: string): AwsCommandClass {
  return classify(command, 0)
}

type RecursiveForcedDelete = {
  command: string
  index: number
}

function recursiveForcedDeletes(command: string): RecursiveForcedDelete[] {
  const deletes: RecursiveForcedDelete[] = []
  for (const match of command.matchAll(/\brm\b([^;&|\n]*)/gi)) {
    const args = match[1]
    const recursive = /(?:^|\s)(?:--recursive|-[a-z]*r[a-z]*)(?=\s|$)/i.test(args)
    const forced = /(?:^|\s)(?:--force|-[a-z]*f[a-z]*)(?=\s|$)/i.test(args)
    if (recursive && forced) {
      deletes.push({ command: match[0], index: match.index ?? 0 })
    }
  }
  return deletes
}

function isTmpChildPath(value: string): boolean {
  if (!value.startsWith("/tmp/")) return false

  const child = value.slice("/tmp/".length)
  const isDirectTmpChild =
    child.length > 0 &&
    !child.includes("/") &&
    child !== "." &&
    child !== ".." &&
    !/[\\\0*?[\]{}]/.test(child)
  if (!isDirectTmpChild) return false

  try {
    return !lstatSync(value).isSymbolicLink()
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "ENOENT"
  }
}

function tmpChildVariableValue(command: string, before: number, variable: string): string | null {
  const previousLine = command
    .slice(0, before)
    .replace(/\s+$/, "")
    .split(/\r?\n/)
    .at(-1)
  const assignment = previousLine?.match(
    /^\s*(?:readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)=(?:"([^"$`\\]*)"|'([^'$`\\]*)'|([^\s"'$`\\]+))\s*$/,
  )
  if (!assignment || assignment[1] !== variable) return null

  const value = assignment[2] ?? assignment[3] ?? assignment[4]
  return value && isTmpChildPath(value) ? value : null
}

function isApprovedTmpDelete(command: string, deletion: RecursiveForcedDelete): boolean {
  const tokens = deletion.command.trim().split(/\s+/)
  if (tokens.shift()?.toLowerCase() !== "rm") return false

  let recursive = false
  let forced = false
  while (tokens[0]?.startsWith("-")) {
    const option = tokens.shift()
    if (option === "--") break
    if (option === "--recursive") recursive = true
    else if (option === "--force") forced = true
    else if (/^-[A-Za-z]+$/.test(option ?? "")) {
      recursive ||= option?.includes("r") ?? false
      forced ||= option?.includes("f") ?? false
    } else {
      return false
    }
  }
  if (!recursive || !forced || tokens.length !== 1) return false

  const target = tokens[0]
  const variable = target.match(/^(?:"\$([A-Za-z_][A-Za-z0-9_]*)"|\$([A-Za-z_][A-Za-z0-9_]*))$/)
  if (variable) {
    return tmpChildVariableValue(command, deletion.index, variable[1] ?? variable[2]) !== null
  }

  const literal = target.match(/^(?:"([^"$`\\]+)"|'([^'$`\\]+)'|([^\s"'$`\\]+))$/)
  return literal !== null && isTmpChildPath(literal[1] ?? literal[2] ?? literal[3])
}

function canAutoApproveTmpDeletes(command: string, deletions: RecursiveForcedDelete[]): boolean {
  return deletions.length > 0 && deletions.every((deletion) => isApprovedTmpDelete(command, deletion))
}

function blockedUserBashResult(reason: string) {
  return {
    result: {
      output: reason,
      exitCode: 126,
      cancelled: false,
      truncated: false,
    },
  }
}

type GuardContext = {
  hasUI: boolean
  ui: { confirm(title: string, message: string): Promise<boolean> }
}

// Returns a block reason, or null when the command may run.
async function awsBlockReason(command: string, ctx: GuardContext): Promise<string | null> {
  if (classifyAwsCommand(command) !== "ask") return null
  if (!ctx.hasUI) return AWS_NO_UI_REASON

  const allowed = await ctx.ui.confirm(
    "Allow AWS command?",
    `This command can write to AWS, or it cannot be classified as read-only:\n\n${command}`,
  )
  return allowed ? null : AWS_DENIED_REASON
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return

    const command = event.input.command as string
    const awsReason = await awsBlockReason(command, ctx)
    if (awsReason) return { block: true, reason: awsReason }

    const deletions = recursiveForcedDeletes(command)
    if (deletions.length === 0 || canAutoApproveTmpDeletes(command, deletions)) return
    if (!ctx.hasUI) return { block: true, reason: DELETE_BLOCK_REASON, terminate: true }

    const allowed = await ctx.ui.confirm(
      "Allow recursive forced deletion?",
      `The command can delete entire folders without recovery:\n\n${command}`,
    )
    if (!allowed) return { block: true, reason: "User denied recursive forced deletion." }
  })

  pi.on("user_bash", async (event, ctx) => {
    const awsReason = await awsBlockReason(event.command, ctx)
    if (awsReason) return blockedUserBashResult(awsReason)

    const deletions = recursiveForcedDeletes(event.command)
    if (deletions.length === 0 || canAutoApproveTmpDeletes(event.command, deletions)) return
    if (!ctx.hasUI) return blockedUserBashResult(DELETE_BLOCK_REASON)

    const allowed = await ctx.ui.confirm(
      "Allow recursive forced deletion?",
      `The command can delete entire folders without recovery:\n\n${event.command}`,
    )
    if (!allowed) return blockedUserBashResult("User denied recursive forced deletion.")
  })
}
