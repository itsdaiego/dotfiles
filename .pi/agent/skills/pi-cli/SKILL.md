---
name: pi-cli
description: Use the user's configured Pi CLI instance for requests that explicitly ask to use Pi CLI, or when a task depends on integrations already authenticated in that CLI. Spawn a fresh non-interactive Pi CLI process instead of trying to connect to the same MCP service from the current session.
---

# Use the configured Pi CLI

Use this skill when Daiego asks to use Pi CLI, or when he asks you to use an integration that is available in his local Pi CLI but is not connected to the current session. Examples include "use Pi CLI", "check Slack in the CLI", and "ask Wall-E through Pi CLI".

## Run a separate Pi process

1. Use the shell tool to run `pi --no-session -p '<task prompt>'`. This starts a fresh, non-interactive Pi CLI process. It uses the local Pi configuration and integrations, and it does not add a session to the CLI history.
2. Put the user's request and the needed context in the prompt. The new process cannot rely on this conversation's context. Ask it to use its configured integration and return the requested result.
3. Keep the prompt scoped to the user's request. For read requests, tell Pi to make no changes. For a requested action, restate the action clearly and follow all applicable safety and authorization rules.
4. Read the CLI result and report it to Daiego. Preserve relevant names, links, and evidence.

Do not first try to access the same service through the current session's MCP tools. Do not run `pi mcp login`, change MCP configuration, or ask Daiego to reconnect when the CLI may already have valid access. If the spawned Pi process cannot use an integration, report the exact error. Do not silently switch to a different credential path or claim access succeeded.

Use the existing `pi` executable on the machine. Do not install another CLI or use an interactive `pi` session for a one-off request.
