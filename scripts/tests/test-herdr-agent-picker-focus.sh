#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-agent-picker-test.XXXXXX")

cleanup() {
  rm -rf "$test_dir"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$test_dir/bin"
cat >"$test_dir/bin/herdr" <<'EOF'
#!/bin/sh
set -eu

case "$1 $2" in
  'agent list')
    printf '%s\n' '{"result":{"agents":[{"workspace_id":"w2","agent":"pi","agent_status":"working","name":"target","pane_id":"w2:p20","tab_id":"w2:t14"}]}}'
    ;;
  'workspace list')
    printf '%s\n' '{"result":{"workspaces":[{"workspace_id":"w2","label":"chesscan"}]}}'
    ;;
  'agent focus'|'tab focus')
    printf '%s %s\n' "$1 $2" "$3" >>"$HERDR_TEST_LOG"
    ;;
esac
EOF
cat >"$test_dir/bin/fzf" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$FZF_TEST_ARGS"
cat >/dev/null
printf 'chesscan pi working target\tw2:p20\tw2:t14\n'
EOF
chmod +x "$test_dir/bin/herdr" "$test_dir/bin/fzf"

PATH="$test_dir/bin:$PATH" HERDR_TEST_LOG="$test_dir/commands" \
  FZF_TEST_ARGS="$test_dir/fzf-arguments" \
  "$repo_dir/.local/bin/herdr-agent-picker"

test "$(cat "$test_dir/commands")" = "agent focus w2:p20
tab focus w2:t14"
grep -Fx -- '--layout=reverse' "$test_dir/fzf-arguments" >/dev/null
printf 'Herdr agent picker focus checks passed.\n'
