#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_dir=$(mktemp -d /tmp/herdr-agent-picker-test.XXXXXX)
fake_bin=$test_dir/bin
fzf_input=$test_dir/fzf-input
fzf_args=$test_dir/fzf-args
herdr_calls=$test_dir/herdr-calls

cleanup() {
  rm -rf "$test_dir"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$fake_bin"

cat >"$fake_bin/herdr" <<'EOF'
#!/bin/sh
if [ "$1 $2" = "agent list" ]; then
  cat <<'JSON'
{"result":{"agents":[{"workspace_id":"workspace-1","agent":"claude","name":"lead-attribution","agent_status":"working","pane_id":"pane-1","tab_id":"tab-1"},{"workspace_id":"workspace-1","agent":"codex","agent_status":"idle","pane_id":"pane-2","tab_id":"tab-2"}]}}
JSON
elif [ "$1 $2" = "workspace list" ]; then
  cat <<'JSON'
{"result":{"workspaces":[{"workspace_id":"workspace-1","label":"eve"}]}}
JSON
else
  printf '%s\n' "$*" >>"$HERDR_CALLS"
fi
EOF
chmod +x "$fake_bin/herdr"

cat >"$fake_bin/fzf" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$FZF_ARGS"
cat >"$FZF_INPUT"
head -n 1 "$FZF_INPUT"
EOF
chmod +x "$fake_bin/fzf"

PATH="$fake_bin:$PATH" \
  HERDR_CALLS=$herdr_calls \
  FZF_ARGS=$fzf_args \
  FZF_INPUT=$fzf_input \
  "$repo_dir/.local/bin/herdr-agent-picker"

expected=$(cat <<'EOF'
eve       claude working   lead-attribution	pane-1	tab-1
eve       codex  idle      -	pane-2	tab-2
EOF
)
test "$(cat "$fzf_input")" = "$expected"
grep -Fx -- '--with-nth=1' "$fzf_args" >/dev/null
expected_header='--header=workspace agent  status    session'
grep -Fx -- "$expected_header" "$fzf_args" >/dev/null
grep -Fx 'agent focus pane-1' "$herdr_calls" >/dev/null

printf 'Herdr agent picker session-name checks passed.\n'
