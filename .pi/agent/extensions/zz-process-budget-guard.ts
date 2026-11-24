import { execFile } from "node:child_process"
import { promisify } from "node:util"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const execFileAsync = promisify(execFile)
const RAW_PI_REASON = "Raw Pi delegation is blocked. Use the guarded pi-cli runner instead."
const DOCUMENT_EXTRACTOR_TYPECHECK_REASON =
  "Blocked: document_extractor/typeCheck.sh starts eight Pyright workers and exhausted system memory. Skip this check and report that it was not run."
const DEFAULT_LIMIT = 100
const MONITOR_INTERVAL_MS = 1000

export type ProcessRecord = {
  pid: number
  ppid: number
  command: string
}

export type ProcessBudgetViolation = {
  count: number
  limit: number
  rootPid: number
}

type GuardContext = {
  abort(): void
  ui: { notify(message: string, level: "info" | "warning" | "error"): void }
}

type TimerHandle = ReturnType<typeof setInterval>

export type ProcessBudgetDependencies = {
  inspect(): Promise<ProcessRecord[]>
  terminate(records: ProcessRecord[], rootPid: number): Promise<void>
  setInterval(callback: () => void, milliseconds: number): TimerHandle
  clearInterval(handle: TimerHandle): void
  pid: number
  limit: number
}

export function parseProcessTable(output: string): ProcessRecord[] {
  const records: ProcessRecord[] = []
  for (const line of output.split("\n")) {
    const match = line.match(/^\s*(\d+)\s+(\d+)\s+(.*)$/)
    if (!match) continue
    const command = match[3]
    if (command === "/bin/ps -axo pid=,ppid=,command=") continue
    records.push({
      pid: Number(match[1]),
      ppid: Number(match[2]),
      command,
    })
  }
  return records
}

function descendantDepths(records: ProcessRecord[], rootPid: number): Map<number, number> {
  const children = new Map<number, number[]>()
  for (const record of records) {
    children.set(record.ppid, [...(children.get(record.ppid) ?? []), record.pid])
  }

  const depths = new Map<number, number>()
  const queue: Array<{ pid: number; depth: number }> = [{ pid: rootPid, depth: 0 }]
  while (queue.length > 0) {
    const current = queue.shift()
    if (!current) break
    for (const child of children.get(current.pid) ?? []) {
      if (child === rootPid || depths.has(child)) continue
      depths.set(child, current.depth + 1)
      queue.push({ pid: child, depth: current.depth + 1 })
    }
  }
  return depths
}

export function findProcessBudgetViolation(
  records: ProcessRecord[],
  rootPid: number,
  limit = DEFAULT_LIMIT,
): ProcessBudgetViolation | null {
  const count = descendantDepths(records, rootPid).size
  return count > limit ? { count, limit, rootPid } : null
}

function shellSegments(command: string): string[][] {
  const segments: string[][] = []
  let tokens: string[] = []
  let token = ""
  let quote: "'" | '"' | null = null

  const endToken = () => {
    if (token.length > 0) tokens.push(token)
    token = ""
  }
  const endSegment = () => {
    endToken()
    if (tokens.length > 0) segments.push(tokens)
    tokens = []
  }

  for (let index = 0; index < command.length; index++) {
    const character = command[index]
    if (quote) {
      if (character === quote) quote = null
      else if (character === "\\" && quote === '"' && index + 1 < command.length) token += command[++index]
      else token += character
      continue
    }
    if (character === "'" || character === '"') {
      quote = character
    } else if (character === "\\" && index + 1 < command.length) {
      token += command[++index]
    } else if (";&|\n()".includes(character)) {
      endSegment()
    } else if (/\s/.test(character)) {
      endToken()
    } else {
      token += character
    }
  }
  endSegment()
  return segments
}

function basename(value: string): string {
  return value.split("/").at(-1) ?? value
}

function segmentRunsRawPi(tokens: string[], depth: number): boolean {
  if (depth > 3) return false
  let index = 0
  while (index < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) index++

  const wrappers = new Set(["command", "env", "exec", "nice", "nohup", "timeout"])
  while (index < tokens.length && wrappers.has(basename(tokens[index]))) {
    const wrapper = basename(tokens[index++])
    if (wrapper === "timeout") {
      while (index < tokens.length && tokens[index].startsWith("-")) index++
      if (index < tokens.length) index++
    } else if (wrapper === "nice") {
      while (index < tokens.length && tokens[index].startsWith("-")) {
        const option = tokens[index++]
        if (option === "-n" || option === "--adjustment") index++
      }
    } else {
      while (index < tokens.length && tokens[index].startsWith("-")) index++
    }
    while (index < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) index++
  }

  const executable = basename(tokens[index] ?? "")
  const args = tokens.slice(index + 1)
  if ((executable === "pi" || executable === "pi-work" || executable === "pi-personal") && args.includes("--no-session")) {
    return true
  }

  if (["bash", "dash", "sh", "zsh"].includes(executable)) {
    const commandIndex = args.findIndex((argument) => /^-[A-Za-z]*c[A-Za-z]*$/.test(argument))
    const script = commandIndex >= 0 ? args[commandIndex + 1] : undefined
    return script ? isRawPiDelegation(script, depth + 1) : false
  }
  return false
}

export function isRawPiDelegation(command: string, depth = 0): boolean {
  return shellSegments(command).some((segment) => segmentRunsRawPi(segment, depth))
}

function segmentRunsDocumentExtractorTypecheck(tokens: string[], contextMatches: boolean, depth: number): boolean {
  if (depth > 3) return false

  const shellIndex = tokens.findIndex((token) => ["bash", "dash", "sh", "zsh"].includes(basename(token)))
  if (shellIndex >= 0) {
    const shellArgs = tokens.slice(shellIndex + 1)
    const commandIndex = shellArgs.findIndex((argument) => /^-[A-Za-z]*c[A-Za-z]*$/.test(argument))
    const script = commandIndex >= 0 ? shellArgs[commandIndex + 1] : undefined
    if (script && isBlockedDocumentExtractorTypecheck(script, contextMatches ? "/src/document_extractor" : "", depth + 1)) {
      return true
    }
  }

  let index = 0
  while (index < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])) index++
  const executable = basename(tokens[index] ?? "")
  const args = tokens.slice(index + 1)

  if (executable === "typeCheck.sh") return contextMatches
  return (
    contextMatches &&
    executable === "uv" &&
    args[0] === "run" &&
    basename(args[1] ?? "") === "pyright" &&
    args.some((argument) => argument === "--threads" || argument.startsWith("--threads="))
  )
}

export function isBlockedDocumentExtractorTypecheck(command: string, cwd: string = "", depth = 0): boolean {
  const contextMatches =
    cwd.includes("/src/document_extractor") ||
    command.includes("src/document_extractor") ||
    command.includes("document_extractor/typeCheck.sh")
  return shellSegments(command).some((segment) =>
    segmentRunsDocumentExtractorTypecheck(segment, contextMatches, depth),
  )
}

async function inspectProcesses(): Promise<ProcessRecord[]> {
  const { stdout } = await execFileAsync("/bin/ps", ["-axo", "pid=,ppid=,command="], {
    maxBuffer: 10 * 1024 * 1024,
  })
  return parseProcessTable(stdout)
}

function isAlive(pid: number): boolean {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

async function terminateDescendants(records: ProcessRecord[], rootPid: number): Promise<void> {
  const depths = descendantDepths(records, rootPid)
  const pids = [...depths.entries()]
    .sort((left, right) => right[1] - left[1])
    .map(([pid]) => pid)

  for (const pid of pids) {
    try {
      process.kill(pid, "SIGTERM")
    } catch {}
  }

  await new Promise((resolve) => setTimeout(resolve, 1000))
  for (const pid of pids) {
    if (!isAlive(pid)) continue
    try {
      process.kill(pid, "SIGKILL")
    } catch {}
  }
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

function defaultDependencies(): ProcessBudgetDependencies {
  const configuredLimit = Number(process.env.PI_PROCESS_HARD_LIMIT ?? DEFAULT_LIMIT)
  return {
    inspect: inspectProcesses,
    terminate: terminateDescendants,
    setInterval,
    clearInterval,
    pid: process.pid,
    limit: Number.isSafeInteger(configuredLimit) && configuredLimit > 0 ? configuredLimit : DEFAULT_LIMIT,
  }
}

export default function registerProcessBudgetGuard(
  pi: ExtensionAPI,
  providedDependencies?: ProcessBudgetDependencies,
) {
  const dependencies = providedDependencies ?? defaultDependencies()
  let timer: TimerHandle | undefined
  let activeToolCalls = 0
  let checkInProgress = false

  const enforceBudget = async (ctx: GuardContext): Promise<ProcessBudgetViolation | null> => {
    if (checkInProgress) return null
    checkInProgress = true
    try {
      const records = await dependencies.inspect()
      const violation = findProcessBudgetViolation(records, dependencies.pid, dependencies.limit)
      if (!violation) return null

      ctx.abort()
      await dependencies.terminate(records, dependencies.pid)
      ctx.ui.notify(
        `Stopped ${violation.count} child processes after the hard limit of ${violation.limit} was exceeded.`,
        "error",
      )
      return violation
    } finally {
      checkInProgress = false
    }
  }

  const startMonitoring = (ctx: GuardContext) => {
    if (timer) return
    timer = dependencies.setInterval(() => {
      void enforceBudget(ctx).catch((error: unknown) => {
        ctx.ui.notify(`Process guard check failed: ${String(error)}`, "warning")
      })
    }, MONITOR_INTERVAL_MS)
    timer.unref?.()
  }

  const stopMonitoring = () => {
    if (timer) dependencies.clearInterval(timer)
    timer = undefined
  }

  pi.on("session_start", async (_event, ctx) => {
    await enforceBudget(ctx)
  })

  pi.on("session_shutdown", () => {
    activeToolCalls = 0
    stopMonitoring()
  })

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "bash") {
      const command = event.input.command as string
      if (isBlockedDocumentExtractorTypecheck(command, ctx.cwd)) {
        return { block: true, reason: DOCUMENT_EXTRACTOR_TYPECHECK_REASON, terminate: true }
      }
      if (isRawPiDelegation(command)) {
        return { block: true, reason: RAW_PI_REASON, terminate: true }
      }
    }

    const violation = await enforceBudget(ctx)
    if (violation) {
      return {
        block: true,
        reason: `Process hard limit exceeded: ${violation.count} child processes, limit ${violation.limit}.`,
        terminate: true,
      }
    }

    activeToolCalls++
    startMonitoring(ctx)
  })

  pi.on("tool_result", async (_event, ctx) => {
    try {
      await enforceBudget(ctx)
    } finally {
      activeToolCalls = Math.max(0, activeToolCalls - 1)
      if (activeToolCalls === 0) stopMonitoring()
    }
  })

  pi.on("user_bash", async (event) => {
    if (isBlockedDocumentExtractorTypecheck(event.command, event.cwd)) {
      return blockedUserBashResult(DOCUMENT_EXTRACTOR_TYPECHECK_REASON)
    }
    if (isRawPiDelegation(event.command)) return blockedUserBashResult(RAW_PI_REASON)
  })
}
