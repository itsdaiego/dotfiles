import assert from "node:assert/strict"
import { test } from "node:test"
import registerProcessBudgetGuard, {
  findProcessBudgetViolation,
  isBlockedDocumentExtractorTypecheck,
  isRawPiDelegation,
  parseProcessTable,
} from "../../.pi/agent/extensions/zz-process-budget-guard.ts"

function processTable(childCount: number): string {
  const lines = ["42 1 pi"]
  for (let index = 0; index < childCount; index++) {
    const pid = 1000 + index
    const parent = index === 0 ? 42 : 1000 + index - 1
    lines.push(`${pid} ${parent} node /tmp/worker-${index}.js`)
  }
  return lines.join("\n")
}

test("allows up to 100 descendant processes", () => {
  const records = parseProcessTable(processTable(100))
  assert.equal(findProcessBudgetViolation(records, 42, 100), null)
})

test("does not count the guard's own ps inspection process", () => {
  const records = parseProcessTable(`${processTable(100)}\n9999 42 /bin/ps -axo pid=,ppid=,command=`)
  assert.equal(findProcessBudgetViolation(records, 42, 100), null)
})

test("reports the process tree when it exceeds 100 descendants", () => {
  const records = parseProcessTable(processTable(101))
  assert.deepEqual(findProcessBudgetViolation(records, 42, 100), {
    count: 101,
    limit: 100,
    rootPid: 42,
  })
})

test("detects raw Pi delegation through common shell wrappers", () => {
  assert.equal(isRawPiDelegation("pi --no-session -p 'search Gmail'"), true)
  assert.equal(isRawPiDelegation("env FOO=1 /opt/homebrew/bin/pi --no-session -p task"), true)
  assert.equal(isRawPiDelegation("echo ready && pi -p task --no-session"), true)
  assert.equal(isRawPiDelegation("timeout 600 pi --no-session -p task"), true)
  assert.equal(isRawPiDelegation(`bash -c "pi --no-session -p task"`), true)
  assert.equal(isRawPiDelegation("~/.pi/agent/skills/pi-cli/scripts/run-isolated-pi.sh task"), false)
  assert.equal(isRawPiDelegation("rg 'pi --no-session' docs"), false)
})

test("blocks the high-memory document extractor typecheck", () => {
  const command = `cd /tmp/worktrees/butler/topic && direnv exec . bash -lc 'cd src/document_extractor && PATH="$PWD/.venv/bin:$PATH" ./typeCheck.sh'`
  assert.equal(isBlockedDocumentExtractorTypecheck(command, "/tmp/worktrees/butler/topic"), true)
  assert.equal(isBlockedDocumentExtractorTypecheck("./typeCheck.sh", "/tmp/worktrees/butler/topic/src/document_extractor"), true)
  assert.equal(isBlockedDocumentExtractorTypecheck("uv run pyright --threads 8", "/tmp/worktrees/butler/topic/src/document_extractor"), true)
  assert.equal(isBlockedDocumentExtractorTypecheck("./typeCheck.sh", "/tmp/another-project"), false)
  assert.equal(isBlockedDocumentExtractorTypecheck(`rg 'typeCheck.sh' src/document_extractor`, "/tmp/worktrees/butler/topic"), false)
})

test("runs the polling watchdog only while a tool is active", async () => {
  const handlers = new Map<string, Array<(event: unknown, context: unknown) => Promise<unknown>>>()
  let starts = 0
  let stops = 0
  registerProcessBudgetGuard({
    on(event: string, handler: (event: unknown, context: unknown) => Promise<unknown>) {
      handlers.set(event, [...(handlers.get(event) ?? []), handler])
    },
  } as never, {
    inspect: async () => [],
    terminate: async () => undefined,
    setInterval: () => {
      starts++
      return { unref() {} } as never
    },
    clearInterval: () => { stops++ },
    pid: 42,
    limit: 100,
  })

  const context = { abort() {}, ui: { notify() {} } }
  await handlers.get("session_start")?.[0]({}, context)
  assert.equal(starts, 0)

  await handlers.get("tool_call")?.[0]({ toolName: "read", input: { path: "/tmp/a" } }, context)
  assert.equal(starts, 1)
  await handlers.get("tool_result")?.[0]({}, context)
  assert.equal(stops, 1)
})

test("stops the current Pi child tree when it exceeds the hard limit", async () => {
  const handlers = new Map<string, Array<(event: unknown, context: unknown) => Promise<unknown>>>()
  let aborts = 0
  let terminations = 0
  const notifications: string[] = []

  registerProcessBudgetGuard({
    on(event: string, handler: (event: unknown, context: unknown) => Promise<unknown>) {
      handlers.set(event, [...(handlers.get(event) ?? []), handler])
    },
  } as never, {
    inspect: async () => parseProcessTable(processTable(101)),
    terminate: async () => { terminations++ },
    setInterval: () => ({ unref() {} }) as never,
    clearInterval: () => undefined,
    pid: 42,
    limit: 100,
  })

  const handler = handlers.get("tool_call")?.[0]
  assert.ok(handler)
  const result = await handler(
    { toolName: "read", input: { path: "/tmp/file" } },
    {
      abort() { aborts++ },
      ui: { notify(message: string) { notifications.push(message) } },
    },
  )

  assert.equal(aborts, 1)
  assert.equal(terminations, 1)
  assert.match(notifications[0], /Stopped 101 child processes/)
  assert.deepEqual(result, {
    block: true,
    reason: "Process hard limit exceeded: 101 child processes, limit 100.",
    terminate: true,
  })
})

test("blocks raw Pi delegation before bash executes", async () => {
  const handlers = new Map<string, Array<(event: unknown, context: unknown) => Promise<unknown>>>()
  registerProcessBudgetGuard({
    on(event: string, handler: (event: unknown, context: unknown) => Promise<unknown>) {
      handlers.set(event, [...(handlers.get(event) ?? []), handler])
    },
  } as never, {
    inspect: async () => [],
    terminate: async () => undefined,
    setInterval: () => ({ unref() {} }) as never,
    clearInterval: () => undefined,
    pid: 42,
    limit: 100,
  })

  const handler = handlers.get("tool_call")?.[0]
  assert.ok(handler)

  const result = await handler(
    { toolName: "bash", input: { command: "pi --no-session -p task" } },
    { ui: { notify() {} }, abort() {} },
  )
  assert.deepEqual(result, {
    block: true,
    reason: "Raw Pi delegation is blocked. Use the guarded pi-cli runner instead.",
    terminate: true,
  })
})
