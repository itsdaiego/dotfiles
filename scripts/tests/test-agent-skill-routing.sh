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
  if grep -F '`pi-cli`' "$instruction_file" >/dev/null; then
    grep -F "guarded runner" "$instruction_file" >/dev/null
    grep -F 'PI_CLI_DELEGATED=1' "$instruction_file" >/dev/null
  fi
  grep -F '`review-risk`' "$instruction_file" >/dev/null
  grep -F 'TypeSafe Jev' "$instruction_file" >/dev/null
  grep -F 'Atomic commits' "$instruction_file" >/dev/null
  grep -F 'Make and stage one logical change at a time.' "$instruction_file" >/dev/null
  grep -F 'Before every git commit, inspect the staged diff' "$instruction_file" >/dev/null
done

test -x .pi/agent/skills/pi-cli/scripts/run-isolated-pi.sh
grep -F 'run-isolated-pi.sh' .pi/agent/skills/pi-cli/SKILL.md >/dev/null
grep -F 'exceeds 100 processes' .pi/agent/skills/pi-cli/SKILL.md >/dev/null
grep -F 'do not run this skill and do not spawn another Pi process' .pi/agent/skills/pi-cli/SKILL.md >/dev/null
test -f .pi/agent/extensions/zz-process-budget-guard.ts
test -L .pi/pi-personal/extensions/zz-process-budget-guard.ts
test "$(readlink .pi/pi-personal/extensions/zz-process-budget-guard.ts)" = '../../agent/extensions/zz-process-budget-guard.ts'

test -f .claude/skills/review-risk/SKILL.md
test -f .codex/skills/review-risk/SKILL.md
test -f .pi/pi-personal/skills/review-risk/SKILL.md
test ! -e .claude/skills/walle-review-risk
test ! -e .codex/skills/walle-review-risk
test ! -e .pi/pi-personal/skills/walle-review-risk
test -f .claude/skills/adversarial-review-stop/SKILL.md
test -f .claude/skills/brain/SKILL.md
test -f .claude/skills/brain-update/SKILL.md
test -f .claude/skills/brain-alerts/SKILL.md
test -f .claude/skills/copy-all/SKILL.md
test -f .codex/skills/copy-all/SKILL.md
test -f .claude/skills/table-view/SKILL.md
test -f .codex/skills/table-view/SKILL.md
test -f .pi/agent/skills/table-view/SKILL.md
test -f .pi/pi-personal/skills/table-view/SKILL.md
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

test -f .pi/agent/prompts/try-harder.md
test -L .pi/pi-personal/prompts/try-harder.md
test "$(readlink .pi/pi-personal/prompts/try-harder.md)" = '../../agent/prompts/try-harder.md'
test -f .pi/agent/skills/try-harder/SKILL.md
test -L .pi/pi-personal/skills/try-harder
test "$(readlink .pi/pi-personal/skills/try-harder)" = '../../agent/skills/try-harder'
grep -F 'Load and follow the `try-harder` skill' .pi/agent/prompts/try-harder.md >/dev/null
grep -F 'Treat routine blockers as work to do, not reasons to stop.' .pi/agent/skills/try-harder/SKILL.md >/dev/null
grep -F 'MR or PR conflicts' .pi/agent/skills/try-harder/SKILL.md >/dev/null
grep -F 'local service or dependency is missing' .pi/agent/skills/try-harder/SKILL.md >/dev/null
grep -F 'worktree cleanup' .pi/agent/skills/try-harder/SKILL.md >/dev/null

risk_skill=.pi/agent/skills/review-risk/SKILL.md
grep -F 'complete current open-MR pool with pagination' "$risk_skill" >/dev/null
grep -F 'It never fills a result slot by itself.' "$risk_skill" >/dev/null
grep -F 'Never force the quota.' "$risk_skill" >/dev/null
grep -F '**Backend** without another qualifier means production runtime backend code' "$risk_skill" >/dev/null
grep -F '**Docs do not count** means a docs-only MR cannot fill a slot.' "$risk_skill" >/dev/null
grep -F 'Prompt and Jinja template changes are prompt changes, not documentation changes.' "$risk_skill" >/dev/null
grep -F 'add a short search audit after the result table' "$risk_skill" >/dev/null
grep -F 'scripts/typesafe_risk.py' "$risk_skill" >/dev/null
grep -F 'TypeSafe Jev classification' "$risk_skill" >/dev/null
grep -F 'Apply the deterministic policy before calling Jev.' "$risk_skill" >/dev/null
grep -F 'Skip Jev when an always-human path already makes the result high.' "$risk_skill" >/dev/null

grep -F 'TypeSafe Jev result' .pi/agent/skills/review-mr/SKILL.md >/dev/null
grep -F 'TypeSafe Jev result' .claude/skills/review-mr/SKILL.md >/dev/null
grep -F '`review-risk` for every exact MR head' .agent-customizations/walle-review/SKILL.md >/dev/null
grep -F 'pi.registerCommand("review-risk"' .pi/agent/extensions/mr-commands/index.ts >/dev/null
! grep -F 'pi.registerCommand("walle-review-risk"' .pi/agent/extensions/mr-commands/index.ts >/dev/null

printf 'Automatic skill routing checks passed.\n'
