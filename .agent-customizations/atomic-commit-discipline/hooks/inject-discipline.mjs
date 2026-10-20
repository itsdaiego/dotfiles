import { readFileSync } from "node:fs";
import { COMMIT_DISCIPLINE } from "../commit-guard.mjs";

let eventName = "SessionStart";
try {
  const input = JSON.parse(readFileSync(0, "utf8"));
  eventName = input.hook_event_name ?? eventName;
} catch {
  // SessionStart hooks can run without JSON input.
}

if (eventName === "UserPromptSubmit") {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: COMMIT_DISCIPLINE,
    },
  }));
} else {
  process.stdout.write(COMMIT_DISCIPLINE);
}
