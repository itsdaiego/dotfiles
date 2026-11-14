#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"

for instruction_file in .codex/AGENTS.md .pi/agent/AGENTS.md .claude/CLAUDE.md; do
  grep -F 'Automatic skill routing' "$instruction_file" >/dev/null
  grep -F 'without requiring a slash command or an exact skill name' "$instruction_file" >/dev/null
  grep -F '`read-mr`' "$instruction_file" >/dev/null
  grep -F '`write-mr-comment`' "$instruction_file" >/dev/null
  grep -F '`review-mr`' "$instruction_file" >/dev/null
  grep -F '`oncall-intake`' "$instruction_file" >/dev/null
  grep -F '`review-queue`' "$instruction_file" >/dev/null
  grep -F '`walle-review-risk`' "$instruction_file" >/dev/null
  grep -F 'Atomic commits' "$instruction_file" >/dev/null
  grep -F 'Make and stage one logical change at a time.' "$instruction_file" >/dev/null
  grep -F 'Before every git commit, inspect the staged diff' "$instruction_file" >/dev/null
done

test -f .claude/skills/walle-review-risk/SKILL.md
test -f .claude/skills/adversarial-review-stop/SKILL.md
test -f .claude/skills/brain/SKILL.md
test -f .claude/skills/brain-update/SKILL.md
test -f .claude/skills/brain-alerts/SKILL.md
test -f .claude/skills/copy-all/SKILL.md
test -f .codex/skills/copy-all/SKILL.md
test -f .claude/skills/rename-session/SKILL.md
test -f .codex/skills/rename-session/SKILL.md
test -f .pi/agent/skills/rename-session/SKILL.md
test -f .pi/pi-personal/skills/rename-session/SKILL.md
test -f .claude/skills/worktree-sweep/SKILL.md
test -f .codex/skills/worktree-sweep/SKILL.md
test -f .pi/agent/skills/worktree-sweep/SKILL.md
test -f .pi/pi-personal/skills/worktree-sweep/SKILL.md
test -f .claude/skills/mr-reference-labels/SKILL.md
test -f .codex/skills/mr-reference-labels/SKILL.md
test -f .pi/agent/skills/mr-reference-labels/SKILL.md
test -f .pi/pi-personal/skills/mr-reference-labels/SKILL.md
test -f .claude/skills/create-doc/SKILL.md
test -f .codex/skills/create-doc/SKILL.md
test -f .pi/agent/skills/create-doc/SKILL.md
test -f .pi/pi-personal/skills/create-doc/SKILL.md
test -f .claude/skills/walle-chat/SKILL.md
test -f .codex/skills/walle-chat/SKILL.md
test -f .pi/agent/skills/walle-chat/SKILL.md
test -f .pi/pi-personal/skills/walle-chat/SKILL.md

printf 'Automatic skill routing checks passed.\n'
