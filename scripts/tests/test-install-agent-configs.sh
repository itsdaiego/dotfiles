#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
marker_relative=.pi/agent/.installer-untracked-test-$$
marker_path=$repo_dir/$marker_relative
trap 'rm -f "$marker_path"; rm -R "$test_home"' EXIT HUP INT TERM

touch "$marker_path"
mkdir "$test_home/old-agent-customizations"
ln -s "$test_home/old-agent-customizations" "$test_home/.agent-customizations"
HOME=$test_home "$repo_dir/scripts/install-agent-configs.sh" >/dev/null

test ! -e "$test_home/$marker_relative"
test "$(readlink "$test_home/.agent-customizations")" = "$repo_dir/.agent-customizations"
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
