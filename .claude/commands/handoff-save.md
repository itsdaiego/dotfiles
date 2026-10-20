---
name: handoff-save
description: Save caveman-compressed session handoff for next session
---

Save session handoff snapshot.

Target path: `$ARGUMENTS` if given, else `~/.claude/handoffs/handoff-<UTC-timestamp>.md`.

Run `mkdir -p ~/.claude/handoffs` first via Bash, plus `date -u +%Y%m%d-%H%M%S` for timestamp.

File contents (caveman-compressed throughout):
```
# Handoff <timestamp>
- repo: <cwd>
- branch: <current branch from git>
- task: <one-line goal>

## Done
- <bullets — what changed, exact paths>

## Files touched
- <path:lines or path>

## Decisions
- <decision> — why: <reason>

## Open
- <unresolved questions or blockers>

## Next
- <concrete next step(s)>

## Context to remember
- <facts/IDs/errors verbatim>
```

Rules:
- Quote errors, IDs, commit SHAs exact.
- No filler. Fragments OK.
- Skip sections empty.
- Print final path after Write.
