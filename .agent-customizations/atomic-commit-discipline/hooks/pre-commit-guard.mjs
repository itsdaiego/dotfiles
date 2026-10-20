import { readFileSync } from "node:fs";
import { commitBlockReason, isGitCommitCommand } from "../commit-guard.mjs";

let input;
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}

const command = input.tool_input?.command;
if (typeof command !== "string" || !isGitCommitCommand(command)) {
  process.exit(0);
}

const reason = commitBlockReason(input.cwd ?? process.cwd(), command);
if (reason) {
  process.stdout.write(JSON.stringify({ decision: "block", reason }));
}
