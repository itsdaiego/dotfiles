#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

sh -n scripts/install-agent-configs.sh
sh -n scripts/tests/test-install-agent-configs.sh
sh -n .local/bin/codex-company
sh -n .local/bin/codex-personal
sh -n .claude/hooks/herdr-agent-state.sh
sh -n .codex/herdr-agent-state.sh

jq empty .claude/settings.json .codex/hooks.json .codex-personal/hooks.json .pi/settings.json \
  .pi/agent/keybindings.json .pi/agent/mcp-adapter.json .pi/agent/settings.json \
  .pi/pi-personal/settings.json .pi/pi-work/settings.json

codex_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-codex-check.XXXXXX")
trap 'rm -rf "$codex_check_dir"' EXIT HUP INT TERM
cp .codex/config.toml "$codex_check_dir/config.toml"
CODEX_HOME=$codex_check_dir codex features list | awk '$1 == "hooks" && $3 == "true" { found = 1 } END { exit !found }'
cp .codex/Codex.config.toml "$codex_check_dir/config.toml"
CODEX_HOME=$codex_check_dir codex features list >/dev/null
cp .codex-personal/config.toml "$codex_check_dir/config.toml"
CODEX_HOME=$codex_check_dir codex features list | awk '$1 == "hooks" && $3 == "true" { found = 1 } END { exit !found }'
cp .codex-personal/Codex-Personal.config.toml "$codex_check_dir/config.toml"
CODEX_HOME=$codex_check_dir codex features list >/dev/null
python3 -m unittest discover -s .agent-customizations/herdr-auto-name/tests -v
python3 -m unittest discover -s .agent-customizations/start-reviewer/scripts -p 'test_*.py' -v
sh scripts/tests/test-install-agent-configs.sh

find .agent-customizations .codex .codex-personal .claude .pi .local/bin -type l -print | while IFS= read -r link; do
  case "$link" in
    */btw.ts) continue ;;
  esac
  test -e "$link" || {
    printf 'Broken managed link: %s\n' "$link" >&2
    exit 1
  }
done

compare_profile_tree() {
  relative_dir=$1
  personal_dir=.pi/pi-personal/$relative_dir
  work_dir=.pi/pi-work/$relative_dir
  personal_inventory=$codex_check_dir/personal-$relative_dir
  work_inventory=$codex_check_dir/work-$relative_dir

  find "$personal_dir" -mindepth 1 -print | sed "s#^$personal_dir/##" | sort >"$personal_inventory"
  find "$work_dir" -mindepth 1 -print | sed "s#^$work_dir/##" | sort >"$work_inventory"
  diff -u "$personal_inventory" "$work_inventory"

  while IFS= read -r relative_path; do
    personal_path=$personal_dir/$relative_path
    work_path=$work_dir/$relative_path

    if [ -L "$personal_path" ]; then
      test -L "$work_path"
      test "$(readlink "$personal_path")" = "$(readlink "$work_path")"
    elif [ -f "$personal_path" ]; then
      cmp "$personal_path" "$work_path"
    else
      test -d "$personal_path" && test -d "$work_path"
    fi
  done <"$personal_inventory"
}

compare_profile_tree agents
compare_profile_tree extensions
compare_profile_tree prompts
compare_profile_tree skills

git diff --check

printf 'Agent configuration checks passed.\n'
