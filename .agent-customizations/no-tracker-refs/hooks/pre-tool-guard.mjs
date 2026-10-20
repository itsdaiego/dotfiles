import { readFileSync } from "node:fs";
import {
  commitBlockReason,
  editBlockReason,
  isGitCommitCommand,
  readFileOrEmpty,
} from "../tracker-refs.mjs";

let input;
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}

const tool = input.tool_name;
const args = input.tool_input ?? {};
let reason;

if (tool === "Bash") {
  if (typeof args.command === "string" && isGitCommitCommand(args.command)) {
    reason = commitBlockReason(input.cwd ?? process.cwd(), args.command);
  }
} else if (tool === "Write") {
  reason = editBlockReason(args.file_path, readFileOrEmpty(args.file_path), args.content ?? "");
} else if (tool === "Edit") {
  reason = editBlockReason(args.file_path, args.old_string ?? "", args.new_string ?? "");
} else if (tool === "MultiEdit") {
  const edits = args.edits ?? [];
  reason = editBlockReason(
    args.file_path,
    edits.map((edit) => edit.old_string ?? "").join("\n"),
    edits.map((edit) => edit.new_string ?? "").join("\n"),
  );
} else if (tool === "NotebookEdit") {
  reason = editBlockReason(args.notebook_path, readFileOrEmpty(args.notebook_path), args.new_source ?? "");
}

if (reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  }));
}
