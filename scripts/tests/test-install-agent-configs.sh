#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
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
mkdir -p "$stale_root/.agent-customizations/herdr-auto-name"
printf 'stale hook\n' >"$stale_root/.agent-customizations/herdr-auto-name/user_prompt_hook.py"
ln -s "$stale_root/.agent-customizations" "$test_home/.agent-customizations"
mkdir -p "$stale_root/walle-review-risk" "$test_home/.pi/agent/skills"
printf 'stale skill\n' >"$stale_root/walle-review-risk/SKILL.md"
ln -s "$stale_root/walle-review-risk" \
  "$test_home/.pi/agent/skills/walle-review-risk"
HOME=$test_home "$repo_dir/scripts/install-agent-configs.sh" >/dev/null

test ! -L "$test_home/.agent-customizations"
test "$(readlink "$test_home/.agent-customizations/herdr-auto-name/user_prompt_hook.py")" = \
  "$repo_dir/.agent-customizations/herdr-auto-name/user_prompt_hook.py"
test ! -L "$stale_root/.agent-customizations/herdr-auto-name/user_prompt_hook.py"
grep -Fx 'stale hook' \
  "$stale_root/.agent-customizations/herdr-auto-name/user_prompt_hook.py" >/dev/null
test ! -L "$test_home/.pi/agent/skills/walle-review-risk"
test "$(readlink "$test_home/.pi/agent/skills/walle-review-risk/SKILL.md")" = \
  "$repo_dir/.pi/agent/skills/walle-review-risk/SKILL.md"
test ! -L "$stale_root/walle-review-risk/SKILL.md"
grep -Fx 'stale skill' "$stale_root/walle-review-risk/SKILL.md" >/dev/null
test ! -e "$test_home/.pi/agent/sessions/$(basename -- "$generated_source")"
test "$(readlink "$test_home/.codex-personal/config.toml")" = "$repo_dir/.codex-personal/config.toml"
test "$(readlink "$test_home/.local/bin/codex-personal")" = "$repo_dir/.local/bin/codex-personal"
test "$(readlink "$test_home/.local/bin/codex-company")" = "$repo_dir/.local/bin/codex-company"
test "$(readlink "$test_home/.codex-personal/AGENTS.md")" = "$test_home/.pi/pi-personal/AGENTS.md"
test "$(readlink "$test_home/.codex-personal/skills")" = "$test_home/.codex/skills"
test "$(readlink "$test_home/.codex/rules/default.rules")" = "$repo_dir/.codex/rules/default.rules"
test "$(readlink "$test_home/.codex-personal/rules/default.rules")" = "$test_home/.codex/rules/default.rules"
grep -F 'prefix_rule(pattern=["herdr", "agent", "rename"], decision="allow")' \
  "$test_home/.codex/rules/default.rules" >/dev/null
grep -F 'prefix_rule(pattern=["herdr", "agent", "rename"], decision="allow")' \
  "$test_home/.codex-personal/rules/default.rules" >/dev/null

printf 'Installer portability checks passed.\n'
