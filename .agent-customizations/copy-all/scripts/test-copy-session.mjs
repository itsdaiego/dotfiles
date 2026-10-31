#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const script = join(import.meta.dirname, "copy-session.mjs");
const directory = mkdtempSync(join(tmpdir(), "copy-all-test-"));

function run(kind, records) {
  const fixture = join(directory, `${kind}.jsonl`);
  writeFileSync(fixture, `${records.map((record) => JSON.stringify(record)).join("\n")}\n`);
  const result = spawnSync(process.execPath, [script, `--${kind}`, "test-session", "--input", fixture, "--stdout"], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}

try {
  const codex = run("codex", [
    { type: "session_meta", payload: { base_instructions: { text: "System instruction" } } },
    { type: "response_item", payload: { type: "message", role: "developer", content: [{ type: "input_text", text: "Developer instruction" }] } },
    { type: "response_item", payload: { type: "message", role: "user", content: [{ type: "input_text", text: "User prompt" }] } },
    { type: "response_item", payload: { type: "message", role: "assistant", content: [{ type: "output_text", text: "Assistant reply" }] } },
  ]);
  assert.match(codex, /System instruction/);
  assert.match(codex, /Developer instruction/);
  assert.match(codex, /User prompt/);
  assert.doesNotMatch(codex, /Assistant reply/);

  const claude = run("claude", [
    { type: "attachment", renderedRole: "system", attachment: { content: "System attachment" } },
    { type: "attachment", renderedRole: "user", attachment: { content: "User instructions" } },
    { type: "user", message: { role: "user", content: "User prompt" } },
    { type: "assistant", message: { role: "assistant", content: "Assistant reply" } },
    { type: "user", message: { role: "user", content: [{ type: "tool_result", content: "Tool output" }] } },
  ]);
  assert.match(claude, /System attachment/);
  assert.match(claude, /User instructions/);
  assert.match(claude, /User prompt/);
  assert.doesNotMatch(claude, /Assistant reply|Tool output/);
  process.stdout.write("copy-session tests passed\n");
} finally {
  rmSync(directory, { recursive: true, force: true });
}
