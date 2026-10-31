---
name: copy-all
description: Copy the current Claude Code or Codex session's system, developer, and user messages to the clipboard for reuse in another session. Use only when the user invokes /copy-all or asks to export those messages.
---

# Copy conversation inputs

Run the shared exporter immediately. It reads the current harness's local session record and copies a Markdown packet containing its recorded system, developer, and user messages. It excludes assistant responses, reasoning, tool calls, and tool results.

In Claude Code, run:

```sh
node "$CLAUDE_SKILL_DIR/scripts/copy-session.mjs" --claude "$CLAUDE_SESSION_ID"
```

In Codex, run:

```sh
node "$HOME/.codex/skills/copy-all/scripts/copy-session.mjs" --codex "$CODEX_SESSION_ID"
```

Do not reconstruct the transcript from memory or add a summary. Report how many messages it copied and the source session ID printed by the command.

The packet may contain sensitive instructions or user data. It stays in the local clipboard. Do not write it to a repository, upload it, or paste it into another service unless the user asks.
