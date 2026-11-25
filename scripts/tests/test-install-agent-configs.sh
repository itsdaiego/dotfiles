#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
common_git_dir=$(git -C "$repo_dir" rev-parse --path-format=absolute --git-common-dir)
stable_repo_dir=$(dirname -- "$common_git_dir")
test_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
generated_source=$repo_dir/.pi/agent/sessions/install-test-generated-$$.jsonl

cleanup() {
  rm -f "$generated_source"
  rmdir "$(dirname -- "$generated_source")" 2>/dev/null || true
  rm -R "$test_home"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$(dirname -- "$generated_source")"
printf 'generated session\n' >"$generated_source"

stale_root=$test_home/stale-checkout
mkdir -p "$stale_root/.config/herdr/scripts/auto-name" "$test_home/.config/herdr"
printf 'stale hook\n' >"$stale_root/.config/herdr/scripts/auto-name/user_prompt_hook.py"
ln -s "$stale_root/.config/herdr/scripts" "$test_home/.config/herdr/scripts"
mkdir -p "$stale_root/walle-review-risk" "$test_home/.pi/agent/skills"
printf 'stale skill\n' >"$stale_root/walle-review-risk/SKILL.md"
ln -s "$stale_root/walle-review-risk" \
  "$test_home/.pi/agent/skills/walle-review-risk"
HOME=$test_home "$repo_dir/scripts/install-agent-configs.sh" >/dev/null

test ! -L "$test_home/.config/herdr/scripts"
test "$(readlink "$test_home/.config/herdr/scripts/auto-name/user_prompt_hook.py")" = \
  "$stable_repo_dir/.config/herdr/scripts/auto-name/user_prompt_hook.py"
test ! -L "$stale_root/.config/herdr/scripts/auto-name/user_prompt_hook.py"
grep -Fx 'stale hook' \
  "$stale_root/.config/herdr/scripts/auto-name/user_prompt_hook.py" >/dev/null
test ! -e "$test_home/.pi/agent/skills/walle-review-risk"
test ! -L "$test_home/.pi/agent/skills/walle-review-risk"
test "$(readlink "$test_home/.pi/agent/skills/review-risk/SKILL.md")" = \
  "$stable_repo_dir/.pi/agent/skills/review-risk/SKILL.md"
test ! -L "$stale_root/walle-review-risk/SKILL.md"
grep -Fx 'stale skill' "$stale_root/walle-review-risk/SKILL.md" >/dev/null
test ! -e "$test_home/.pi/agent/sessions/$(basename -- "$generated_source")"
test -L "$test_home/.pi/pi-work"
test "$(readlink "$test_home/.pi/pi-work")" = "$test_home/.pi/agent"
test "$(readlink "$test_home/.codex-personal/config.toml")" = "$stable_repo_dir/.codex-personal/config.toml"
test "$(readlink "$test_home/.ai/README.md")" = "$stable_repo_dir/.ai/README.md"
test "$(readlink "$test_home/.local/bin/codex-personal")" = "$stable_repo_dir/.local/bin/codex-personal"
test "$(readlink "$test_home/.local/bin/codex-company")" = "$stable_repo_dir/.local/bin/codex-company"
for pocket_profile in .pi-pocket-work .pi-pocket-personal; do
  for extension_file in \
    _document-extractor-typecheck-guard.ts \
    _jev-auto-policy.ts \
    document-extractor-typecheck-guard.ts \
    jev-auto.ts
  do
    test ! -L "$test_home/$pocket_profile/extensions/$extension_file"
    cmp \
      "$stable_repo_dir/pi-durable/extensions/$extension_file" \
      "$test_home/$pocket_profile/extensions/$extension_file"
  done
done
test "$(readlink "$test_home/.codex-personal/AGENTS.md")" = "$test_home/.pi/pi-personal/AGENTS.md"
test "$(readlink "$test_home/.codex-personal/skills")" = "$test_home/.codex/skills"
test "$(readlink "$test_home/.codex/rules/default.rules")" = "$stable_repo_dir/.codex/rules/default.rules"
test "$(readlink "$test_home/.codex-personal/rules/default.rules")" = "$test_home/.codex/rules/default.rules"
test ! -e "$test_home/.claude/skills/walle-review-risk"
test "$(readlink "$test_home/.claude/skills/review-risk")" = \
  "$stable_repo_dir/.pi/agent/skills/review-risk"
test "$(readlink "$test_home/.codex/skills/review-risk")" = \
  "$stable_repo_dir/.pi/agent/skills/review-risk"
test "$(readlink "$test_home/.pi/pi-personal/skills/review-risk")" = \
  "$stable_repo_dir/.pi/agent/skills/review-risk"
test "$(readlink "$repo_dir/.pi/pi-personal/extensions/jev-auto.ts")" = \
  "../../agent/extensions/jev-auto.ts"
test "$(readlink "$test_home/.claude/skills/adversarial-review-stop")" = \
  "$stable_repo_dir/.pi/agent/skills/adversarial-review-stop"
test "$(readlink "$test_home/.claude/skills/brain")" = "$stable_repo_dir/.pi/agent/skills/brain"
test "$(readlink "$test_home/.claude/skills/copy-all")" = \
  "$stable_repo_dir/.agent-customizations/copy-all"
test "$(readlink "$test_home/.codex/skills/copy-all")" = \
  "$stable_repo_dir/.agent-customizations/copy-all"
test "$(readlink "$test_home/.codex-personal/skills/copy-all")" = \
  "$stable_repo_dir/.agent-customizations/copy-all"
grep -F 'prefix_rule(pattern=["herdr", "agent", "rename"], decision="allow")' \
  "$test_home/.codex/rules/default.rules" >/dev/null
grep -F 'prefix_rule(pattern=["herdr", "agent", "rename"], decision="allow")' \
  "$test_home/.codex-personal/rules/default.rules" >/dev/null

printf 'Installer portability checks passed.\n'
