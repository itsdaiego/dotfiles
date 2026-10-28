@RTK.md

# Humanizer
- At the start of every session, load the `humanizer` skill. Before every user-visible response, apply it in embedded mode to all natural-language prose, while preserving code, commands, paths, identifiers, data, and other exact technical content. Follow this rule even when the skill's automatic routing description does not match. Do not mention this step unless the user asks.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Test-driven development
- For every behavior change or bug fix, use red → green → refactor: write or update a focused automated test first, run it and confirm it fails for the expected reason, implement the smallest production change that makes it pass, then refactor only while the test suite remains green.
- Do not write production code for a behavior change before its failing test exists. When a test is not practical, explain why and use the strongest relevant verification instead.
- Documentation, configuration-only, and non-behavioral changes do not require a test; run any applicable validation instead.

# Herdr session names
- In a Herdr-managed root session, the shared auto-name integration labels the current tab `pi`, `claude`, or `codex`. Herdr combines that with the workspace/project name on the bold top line, such as `chessan · codex`.
- On the first user prompt, infer a short task description, convert it to a lowercase kebab-case slug with at most 32 characters, and run `herdr agent rename "$HERDR_PANE_ID" "<slug>"` before substantive work. That inferred task name belongs on the lower description line. Preserve an existing task name and never rename a subagent.

# Shared harness maintenance
- When updating the shared Pi, Claude Code, or Codex setup, work in `~/Documents/code-stuff/dotfiles` and follow `docs/agent-config-maintenance.md`.
- Keep authentication, OAuth state, sessions, caches, databases, downloaded plugins, generated system skills, and per-machine trust state out of Git.

# Safety rules
- Run an AWS CLI (`aws`) command only when the operation is demonstrably read-only. Never run mutating or ambiguous AWS commands. Do not bypass this restriction through a script, wrapper, alias, subshell, SDK, or another command. Provide blocked commands for the user to review and run manually.
- Always ask the user for confirmation immediately before a recursive forced deletion, such as `rm -rf <folder>`. Execute only the exact command that the user confirms. Block the command when confirmation is unavailable or denied.

# Writing docs and MR descriptions
Applies to written artifacts only: docs, design docs, Notion and Linear pages, PR/MR descriptions, and commit bodies. It does not change how you write chat replies.
- Write in full, clear sentences. Do not use terse, compressed, or "caveman" style in these artifacts, even when that style is active for chat.
- Never truncate, abbreviate, or drop information to save tokens. Keep every fact, decision, caveat, and reason. Clear beats short.
- The reader may know the code, but must not need to reverse-engineer the text. Say what the system does and why, then name the code that does it.
- Define project terms that are not obvious on first use. Add a short glossary when a doc uses several.
- Use short sentences with one idea each, active voice, and a clear actor.
- Label diagrams with readable steps, not only code names.
- Keep code blocks, commands, exact error text, and identifiers verbatim.
