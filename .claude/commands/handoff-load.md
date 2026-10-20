---
name: handoff-load
description: Load most recent (or named) session handoff
---

Load handoff snapshot.

Source:
- If `$ARGUMENTS` given → treat as path (absolute or under `~/.claude/handoffs/`).
- Else → `ls -1t ~/.claude/handoffs/handoff-*.md | head -1` to pick newest.

Read file. Output:
- File path loaded
- Task + branch
- Last "Next" bullets (resume points)
- Open questions (if any)

Then ask Daiego: "Resume from Next? Or different angle?"

Caveman-terse. No filler.
