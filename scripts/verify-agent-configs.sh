#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

sh -n scripts/install-agent-configs.sh
sh -n scripts/backup-worktree-state.sh
sh -n scripts/tests/test-backup-worktree-state.sh
sh -n scripts/tests/test-install-agent-configs.sh
sh -n scripts/tests/test-pi-durable.sh
sh -n scripts/tests/test-pi-cli-guard.sh
sh -n scripts/tests/test-agent-skill-routing.sh
sh -n .pi/agent/skills/pi-cli/scripts/run-isolated-pi.sh
sh -n scripts/tests/test-herdr-agent-picker.sh
sh -n scripts/tests/test-herdr-agent-picker-session-name.sh
sh -n .local/bin/codex-company
sh -n .local/bin/codex-personal
sh -n .claude/hooks/herdr-agent-state.sh
sh -n .codex/herdr-agent-state.sh

jq empty .claude/settings.json .codex/hooks.json .codex-personal/hooks.json .pi/settings.json \
  .pi/agent/keybindings.json .pi/agent/mcp-adapter.json .pi/agent/settings.json \
  .pi/pi-personal/settings.json
jq -e '.packages | index("git:github.com/dmmulroy/pi-claude-cli") != null' \
  .pi/pi-personal/settings.json >/dev/null

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
python3 -m unittest discover -s .config/herdr/scripts/auto-name/tests -v
python3 -m unittest discover -s .agent-customizations/start-reviewer/scripts -p 'test_*.py' -v
python3 -m unittest discover -s .agent-customizations/review-queue/scripts -p 'test_*.py' -v
python3 -m unittest discover -s .pi/agent/skills/review-risk/scripts -p 'test_*.py' -v
sh scripts/tests/test-backup-worktree-state.sh
sh scripts/tests/test-install-agent-configs.sh
sh scripts/tests/test-pi-durable.sh
sh scripts/tests/test-pi-cli-guard.sh
sh scripts/tests/test-agent-skill-routing.sh
sh scripts/tests/test-herdr-agent-picker.sh
sh scripts/tests/test-herdr-agent-picker-session-name.sh
pocket_extension_check=$codex_check_dir/pi-pocket-extension
mkdir -p "$pocket_extension_check"
cp pi-durable/extensions/*.ts "$pocket_extension_check/"
ln -s /opt/homebrew/lib/node_modules/pi-pocket/node_modules "$pocket_extension_check/node_modules"
node --experimental-strip-types -e \
  'import(process.argv[1]).then(async (module) => { const extension = module.default({ cwdOf: () => "/tmp/work/src/document_extractor" }); const beforeTool = extension.hooks?.[0]?.handlers?.beforeTool; const blocked = await beforeTool?.({ name: "bash", arguments: { command: "./typeCheck.sh" } }, { conversationId: 1 }); if (!blocked?.block) process.exit(1) })' \
  "$pocket_extension_check/document-extractor-typecheck-guard.ts"
node --experimental-strip-types --test "$pocket_extension_check/jev-auto.test.ts"
node --experimental-strip-types --test .pi/agent/extensions/tests/jev-auto.test.ts
node --experimental-strip-types --test scripts/tests/pi-aws-command-guard.test.ts
node --experimental-strip-types --test scripts/tests/pi-process-budget-guard.test.ts
node --experimental-strip-types --test scripts/tests/pi-pocket-typecheck-guard.test.ts

find .config/herdr/scripts .agent-customizations .codex .codex-personal .claude .pi .local/bin -type l -print | while IFS= read -r link; do
  case "$link" in
    */btw.ts) continue ;;
  esac
  test -e "$link" || {
    printf 'Broken managed link: %s\n' "$link" >&2
    exit 1
  }
done

test ! -e .pi/pi-work

git diff --check

printf 'Agent configuration checks passed.\n'
