import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const BLOCK_REASON =
  "Gmail access is read-only here. This call sends, writes, labels, trashes, or otherwise mutates email and is blocked by policy. Ask the user to do it themselves."

const GMAIL_SERVER_NAMES = [
  "9a1da8de-2b8c-4b74-bc22-8291a670ac6b",
  "claude_ai_Gmail",
  "gmail",
  "google-workspace",
  "google_workspace",
  "googleworkspace",
]

const GMAIL_MUTATING_OPERATIONS = [
  "send_message",
  "reply",
  "forward",
  "create_draft",
  "update_draft",
  "delete_draft",
  "create_label",
  "update_label",
  "delete_label",
  "label_message",
  "label_thread",
  "unlabel_message",
  "unlabel_thread",
  "update_message_labels",
  "apply_sensitive_message_label",
  "apply_sensitive_thread_label",
  "mark_message_spam",
  "unmark_message_spam",
  "mark_thread_spam",
  "unmark_thread_spam",
  "trash_message",
  "untrash_message",
  "trash_thread",
  "untrash_thread",
]

const GMAIL_WRITE_TOOL_NAME = new RegExp(
  `^mcp__(${GMAIL_SERVER_NAMES.join("|")})__(${GMAIL_MUTATING_OPERATIONS.join("|")})$`,
)

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!GMAIL_WRITE_TOOL_NAME.test(event.toolName)) return

    if (ctx.hasUI) ctx.ui.notify(BLOCK_REASON, "warning")
    return { block: true, reason: BLOCK_REASON, terminate: true }
  })
}
