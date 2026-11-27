import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  COMMIT_DISCIPLINE,
  inspectStagedDiff,
} from "../../.agent-customizations/atomic-commit-discipline/commit-guard.mjs";

function createLargeStagedCommit() {
  const cwd = mkdtempSync(join(tmpdir(), "atomic-commit-discipline-"));
  execFileSync("git", ["init", "--quiet"], { cwd });
  for (let index = 0; index < 26; index += 1) {
    writeFileSync(join(cwd, `file-${index}.txt`), `change ${index}\n`);
  }
  execFileSync("git", ["add", "."], { cwd });
  return cwd;
}

test("atomic commit guidance allows a necessary larger commit without extra approval", () => {
  assert.match(COMMIT_DISCIPLINE, /must not prevent task completion/i);
  assert.match(COMMIT_DISCIPLINE, /larger commit/i);
  assert.doesNotMatch(COMMIT_DISCIPLINE, /needs explicit user approval/i);
});

test("large staged changes are identified for advisory assessment", () => {
  const cwd = createLargeStagedCommit();
  try {
    const staged = inspectStagedDiff(cwd);
    assert.equal(staged.kind, "changes");
    assert.equal(staged.isLarge, true);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});

test("Pi and Claude integrations do not enforce atomic commit blockers", () => {
  const piExtension = readFileSync(
    new URL("../../.agent-customizations/atomic-commit-discipline/pi-extension.ts", import.meta.url),
    "utf8",
  );
  const claudePlugin = JSON.parse(readFileSync(
    new URL("../../.agent-customizations/atomic-commit-discipline/.claude-plugin/plugin.json", import.meta.url),
    "utf8",
  ));

  assert.doesNotMatch(piExtension, /block:\s*true/);
  assert.doesNotMatch(piExtension, /terminate:\s*true/);
  assert.doesNotMatch(piExtension, /largeCommitApprovedByUser/);
  assert.match(piExtension, /otherwise explain why and continue/i);
  assert.match(piExtension, /advisory: staged\.isLarge/);
  assert.equal(claudePlugin.hooks.PreToolUse, undefined);
});
