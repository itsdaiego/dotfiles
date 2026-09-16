@RTK.md
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Safety rules
- Never execute an AWS CLI (`aws`) command. Do not bypass this restriction through a script, wrapper, alias, subshell, or another command. Provide the command for the user to review and run manually.
- Always ask the user for confirmation immediately before a recursive forced deletion, such as `rm -rf <folder>`. Execute only the exact command that the user confirms. Block the command when confirmation is unavailable or denied.
