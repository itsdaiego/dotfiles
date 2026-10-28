#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
trap 'rm -R "$test_home"' EXIT HUP INT TERM

HOME=$test_home "$repo_dir/scripts/install-agent-configs.sh" >/dev/null

test "$(readlink "$test_home/.codex-personal/config.toml")" = "$repo_dir/.codex-personal/config.toml"
test "$(readlink "$test_home/.local/bin/codex-personal")" = "$repo_dir/.local/bin/codex-personal"
test "$(readlink "$test_home/.local/bin/codex-company")" = "$repo_dir/.local/bin/codex-company"
test "$(readlink "$test_home/.codex-personal/AGENTS.md")" = "$test_home/.pi/pi-personal/AGENTS.md"
test "$(readlink "$test_home/.codex-personal/skills")" = "$test_home/.codex/skills"

printf 'Installer portability checks passed.\n'
