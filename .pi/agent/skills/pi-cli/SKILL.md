---
name: pi-cli
description: Use the user's configured Pi CLI instance for requests that explicitly ask to use Pi CLI, or when a task depends on integrations already authenticated in that CLI. Spawn a fresh non-interactive Pi CLI process instead of trying to connect to the same MCP service from the current session.
---

# Use the configured Pi CLI

Use this skill when Daiego asks to use Pi CLI, or when he asks you to use an integration that is available in his local Pi CLI but is not connected to the current session. Examples include "use Pi CLI", "check Slack in the CLI", and "ask Wall-E through Pi CLI".

## Prevent recursive delegation

If `PI_CLI_DELEGATED=1` or `PI_CLI_DELEGATION_DEPTH` is greater than zero, do not run this skill and do not spawn another Pi process. The current process is already the isolated delegate. Use its configured integrations directly. If the needed integration is unavailable, return that exact error to the parent process.

Never invoke `pi --no-session` directly for this workflow. The guarded runner blocks recursive delegation and stops its delegated process tree if it exceeds 100 processes. A global Pi extension also monitors every session and stops its child processes when they exceed the same hard limit.

## Run a separate Pi process

1. Use the shell tool to run `~/.pi/agent/skills/pi-cli/scripts/run-isolated-pi.sh '<task prompt>'`. This starts a guarded, non-interactive Pi CLI process. It uses the local Pi configuration and integrations, and it does not add a session to the CLI history.
2. Put the user's request and the needed context in the prompt. State that this process is already the delegated Pi and must use integrations directly rather than invoking the `pi-cli` skill or spawning another Pi.
3. Keep the prompt scoped to the user's request. For read requests, tell Pi to make no changes. For a requested action, restate the action clearly and follow all applicable safety and authorization rules.
4. Read the CLI result and report it to Daiego. Preserve relevant names, links, and evidence.

Do not first try to access the same service through the current session's MCP tools. Do not run `pi mcp login`, change MCP configuration, or ask Daiego to reconnect when the CLI may already have valid access. If the guarded process exits with status 70, recursive delegation was blocked. Status 75 means the 100-process budget was reached. Do not retry either failure automatically. Report the exact error instead.

Use the existing `pi` executable on the machine. Do not install another CLI or use an interactive `pi` session for a one-off request.
