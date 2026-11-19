#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pi-durable-test.XXXXXX")
stub_bin=$test_home/bin
mkdir -p "$stub_bin"

cleanup() {
  if [ -f "$test_home/.pi-pocket-work/server.pid" ]; then
    kill "$(cat "$test_home/.pi-pocket-work/server.pid")" 2>/dev/null || true
  fi
  rm -R "$test_home"
}
trap cleanup EXIT HUP INT TERM

cat >"$stub_bin/pi-pocket" <<'EOF'
#!/bin/sh
port=
previous=
for argument in "$@"; do
  if [ "$previous" = "--port" ]; then
    port=$argument
    break
  fi
  previous=$argument
done

{
  printf 'agent_dir=%s\n' "${PI_CODING_AGENT_DIR-<unset>}"
  printf 'session_dir=%s\n' "${PI_CODING_AGENT_SESSION_DIR-<unset>}"
  printf 'args=%s\n' "$*"
} >"$HOME/pi-pocket-invocation"
touch "$HOME/listening-$port"
while :; do sleep 1; done
EOF
chmod +x "$stub_bin/pi-pocket"

cat >"$stub_bin/lsof" <<'EOF'
#!/bin/sh
port=
for argument in "$@"; do
  case "$argument" in
    -iTCP:*) port=${argument#-iTCP:} ;;
  esac
done
test -n "$port" && test -f "$HOME/listening-$port"
EOF
chmod +x "$stub_bin/lsof"

cat >"$stub_bin/tailscale" <<'EOF'
#!/bin/sh
printf '100.64.0.1\n'
EOF
chmod +x "$stub_bin/tailscale"

HOME=$test_home PATH=$stub_bin:$PATH "$repo_dir/pi-durable/start.sh" work >/dev/null

grep -Fx "agent_dir=$test_home/.pi/pi-work" "$test_home/pi-pocket-invocation" >/dev/null
grep -Fx 'session_dir=<unset>' "$test_home/pi-pocket-invocation" >/dev/null
grep -F -- "--port 8789 --data $test_home/.pi-pocket-work" \
  "$test_home/pi-pocket-invocation" >/dev/null

printf 'Pi Pocket work-profile launcher checks passed.\n'
