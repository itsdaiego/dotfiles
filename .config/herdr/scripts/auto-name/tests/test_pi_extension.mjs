import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test, { afterEach } from "node:test";

const stateHome = mkdtempSync(join(tmpdir(), "pi-auto-name-test-"));
process.env.XDG_STATE_HOME = stateHome;
process.env.HERDR_ENV = "";
delete process.env.HERDR_PANE_ID;
delete process.env.HERDR_TAB_ID;
process.env.REX_SESSION = "session:test-rex-session";
process.env.REX_BLOCK = "block:test-rex-block";
process.env.REX_BIN_DIR = "/Applications/Rex.app/Contents/MacOS";

const { default: autoName, rexBlockNameLockPath } = await import(
  "../pi-extension.ts?pi-session-test"
);

afterEach(() => {
  rmSync(stateHome, { recursive: true, force: true });
  mkdirSync(stateHome, { recursive: true });
});

function setup(initialName) {
  let sessionName = initialName;
  let beforeAgentStart;
  let namingTool;
  const execCalls = [];
  const pi = {
    getSessionName: () => sessionName,
    setSessionName: (name) => {
      sessionName = name;
    },
    exec: async (command, args) => {
      execCalls.push({ command, args });
      return { code: 0, stdout: "", stderr: "" };
    },
    on(event, handler) {
      if (event === "before_agent_start") beforeAgentStart = handler;
    },
    registerTool(tool) {
      namingTool = tool;
    },
  };

  autoName(pi);
  assert.equal(typeof beforeAgentStart, "function");
  assert.equal(namingTool?.name, "set_agent_session_name");
  return { beforeAgentStart, namingTool, execCalls, getName: () => sessionName };
}

test("names the Pi session semantically and mirrors it to the current Rex agent", async () => {
  const state = setup(undefined);

  const first = await state.beforeAgentStart(
    { systemPrompt: "base prompt" },
    { mode: "tui" },
  );
  assert.match(first.systemPrompt, /infer a concise task description/);
  assert.match(first.systemPrompt, /set_agent_session_name/);

  await state.namingTool.execute("call-1", { name: "Rex Session Rename" });
  assert.equal(state.getName(), "rex-session-rename");
  assert.deepEqual(state.execCalls, [
    {
      command: "/Applications/Rex.app/Contents/MacOS/rex",
      args: [
        "block",
        "rename",
        "-s",
        "session:test-rex-session",
        "block:test-rex-block",
        "rex-session-rename",
      ],
    },
  ]);

  const second = await state.beforeAgentStart(
    { systemPrompt: "base prompt" },
    { mode: "tui" },
  );
  assert.equal(second, undefined);
});

test("does not rename an already named Pi session", async () => {
  const state = setup("existing-task-name");
  const result = await state.beforeAgentStart(
    { systemPrompt: "base prompt" },
    { mode: "tui" },
  );
  assert.equal(result, undefined);
});

test("does not auto-name non-interactive Pi subagents", async () => {
  const state = setup(undefined);
  const result = await state.beforeAgentStart(
    { systemPrompt: "base prompt" },
    { mode: "json" },
  );
  assert.equal(result, undefined);
});

test("keeps an explicit Rex label pinned while still naming the Pi session", async () => {
  const lockPath = rexBlockNameLockPath();
  mkdirSync(dirname(lockPath), { recursive: true });
  writeFileSync(lockPath, "eve\n");
  const state = setup(undefined);

  await state.namingTool.execute("call-1", { name: "Meaningful Pi Session" });
  assert.equal(state.getName(), "meaningful-pi-session");
  assert.deepEqual(state.execCalls, []);
});
