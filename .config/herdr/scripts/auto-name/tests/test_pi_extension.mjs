import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test, { after } from "node:test";

const stateHome = mkdtempSync(join(tmpdir(), "rex-auto-name-test-"));
after(() => rmSync(stateHome, { recursive: true, force: true }));

process.env.XDG_STATE_HOME = stateHome;
process.env.HERDR_ENV = "";
delete process.env.HERDR_PANE_ID;
delete process.env.HERDR_TAB_ID;
process.env.REX_SESSION = "session:test-rex-session";
process.env.REX_BLOCK = "block:test-rex-block";

const { default: autoName, rexBlockNameLockPath } = await import(
  "../pi-extension.ts?rex-session-test"
);

test("asks each Rex prompt to keep the current pane name on topic", async () => {
  let beforeAgentStart;
  const pi = {
    on(event, handler) {
      if (event === "before_agent_start") {
        beforeAgentStart = handler;
      }
    },
  };

  autoName(pi);
  assert.equal(typeof beforeAgentStart, "function");

  const first = await beforeAgentStart({ systemPrompt: "base prompt" });
  assert.match(first.systemPrompt, /infer a concise task description/);
  assert.match(
    first.systemPrompt,
    /"\$REX_BIN_DIR\/rex" block rename -s "\$REX_SESSION" "\$REX_BLOCK" "<slug>"/,
  );
  assert.match(first.systemPrompt, /session:test-rex-session/);

  const second = await beforeAgentStart({ systemPrompt: "base prompt" });
  assert.match(second.systemPrompt, /block rename/);
});

test("preserves a manually pinned Rex pane name", async () => {
  const lockPath = rexBlockNameLockPath();
  mkdirSync(dirname(lockPath), { recursive: true });
  writeFileSync(lockPath, "eve\n");

  let beforeAgentStart;
  autoName({
    on(event, handler) {
      if (event === "before_agent_start") {
        beforeAgentStart = handler;
      }
    },
  });

  const result = await beforeAgentStart({ systemPrompt: "base prompt" });
  assert.equal(result, undefined);
});
