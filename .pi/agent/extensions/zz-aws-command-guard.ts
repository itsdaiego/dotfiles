import { lstatSync } from "node:fs"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const AWS_BLOCK_REASON =
  "Only demonstrably read-only AWS CLI commands are allowed. This command is mutating or cannot be classified safely."
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

type AwsInvocation = {
  service: string
  operation: string
  args: string[]
}

function containsAwsCommand(command: string): boolean {
  return /\baws\b/i.test(command)
}

function unquote(token: string): string {
  if (
    token.length >= 2 &&
    ((token.startsWith('"') && token.endsWith('"')) ||
      (token.startsWith("'") && token.endsWith("'")))
  ) {
    return token.slice(1, -1)
  }
  return token
}

function parseAwsInvocation(command: string): AwsInvocation | null {
  // Reject shell composition because a second command can hide a mutation.
  if (/[;&|`\n]|\$\(/.test(command)) return null

  const tokens = command.match(/"(?:\\.|[^"])*"|'[^']*'|\S+/g)?.map(unquote) ?? []
  const awsIndex = tokens.findIndex((token) => token.split("/").at(-1)?.toLowerCase() === "aws")
  if (awsIndex < 0) return null

  let index = awsIndex + 1
  if (tokens[index] === "--version" || tokens[index] === "help") {
    return { service: "help", operation: "help", args: [] }
  }

  while (index < tokens.length && tokens[index].startsWith("-")) {
    const option = tokens[index]
    index += GLOBAL_OPTIONS_WITH_VALUES.has(option) ? 2 : 1
  }

  const service = tokens[index]?.toLowerCase()
  const operation = tokens[index + 1]?.toLowerCase()
  if (!service || !operation) return null
  return { service, operation, args: tokens.slice(index + 2) }
}

function isReadOnlyS3Transfer(invocation: AwsInvocation): boolean {
  if (invocation.service !== "s3") return false
  if (invocation.operation !== "cp" && invocation.operation !== "sync") return false

  const [source, destination] = invocation.args
  return source?.startsWith("s3://") === true && destination?.startsWith("s3://") === false
}

function isReadOnlyAwsCommand(command: string): boolean {
  const invocation = parseAwsInvocation(command)
  if (!invocation) return false

  if (invocation.service === "help" || invocation.operation === "help") return true
  if (invocation.service === "s3" && invocation.operation === "ls") return true
  if (invocation.service === "logs" && invocation.operation === "tail") return true
  if (invocation.operation === "wait") return true
  if (isReadOnlyS3Transfer(invocation)) return true

  return READ_ONLY_OPERATION_PREFIXES.some(
    (prefix) => invocation.operation === prefix || invocation.operation.startsWith(`${prefix}-`),
  )
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

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return

    const command = event.input.command as string
    if (containsAwsCommand(command) && !isReadOnlyAwsCommand(command)) {
      if (ctx.hasUI) ctx.ui.notify(AWS_BLOCK_REASON, "warning")
      return { block: true, reason: AWS_BLOCK_REASON, terminate: true }
    }

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
    if (containsAwsCommand(event.command) && !isReadOnlyAwsCommand(event.command)) {
      return blockedUserBashResult(AWS_BLOCK_REASON)
    }
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
