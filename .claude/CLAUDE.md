@RTK.md

# Humanizer
- At the start of every session, load the `humanizer` skill. Before every user-visible response, apply it in embedded mode to all natural-language prose, while preserving code, commands, paths, identifiers, data, and other exact technical content. Follow this rule even when the skill's automatic routing description does not match. Do not mention this step unless the user asks.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

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
