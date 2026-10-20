import {
  TRACKER_REF_RULE,
  commitBlockReason,
  editBlockReason,
  isGitCommitCommand,
  readFileOrEmpty,
} from "./tracker-refs.mjs";
import { isToolCallEventType, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isAbsolute, resolve } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n${TRACKER_REF_RULE}`,
  }));

  pi.on("tool_call", (event, ctx) => {
    let reason: string | undefined;
    if (isToolCallEventType("bash", event)) {
      if (isGitCommitCommand(event.input.command)) reason = commitBlockReason(ctx.cwd, event.input.command);
    } else if (isToolCallEventType("write", event)) {
      const path = isAbsolute(event.input.path) ? event.input.path : resolve(ctx.cwd, event.input.path);
      reason = editBlockReason(path, readFileOrEmpty(path), event.input.content);
    } else if (isToolCallEventType("edit", event)) {
      const path = isAbsolute(event.input.path) ? event.input.path : resolve(ctx.cwd, event.input.path);
      reason = editBlockReason(
        path,
        event.input.edits.map((edit) => edit.oldText).join("\n"),
        event.input.edits.map((edit) => edit.newText).join("\n"),
      );
    }
    if (reason) return { block: true, reason };
  });
}
