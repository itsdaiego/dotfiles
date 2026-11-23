#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
guard=$repo_dir/.pi/agent/skills/pi-cli/scripts/run-isolated-pi.sh
test_home=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pi-cli-guard-test.XXXXXX")
stub_bin=$test_home/bin
mkdir -p "$stub_bin"

cleanup() {
  if [ -f "$test_home/stub.pid" ]; then
    kill "$(cat "$test_home/stub.pid")" 2>/dev/null || true
  fi
  rm -R "$test_home"
}
trap cleanup EXIT HUP INT TERM

cat >"$stub_bin/pi" <<'EOF'
#!/bin/sh
printf '%s\n' "delegated=${PI_CLI_DELEGATED-}" >"$TEST_HOME/invocation"
printf '%s\n' "depth=${PI_CLI_DELEGATION_DEPTH-}" >>"$TEST_HOME/invocation"
printf '%s\n' "args=$*" >>"$TEST_HOME/invocation"
printf '%s\n' "$$" >"$TEST_HOME/stub.pid"
if [ "${PI_CLI_TEST_SLEEP-0}" = "1" ]; then
  while :; do sleep 1; done
fi
EOF
chmod +x "$stub_bin/pi"

run_guard() {
  TEST_HOME=$test_home \
  PI_CLI_BIN=$stub_bin/pi \
  PI_CLI_MONITOR_INTERVAL=0.05 \
  "$guard" "$@"
}

if (PI_CLI_DELEGATED=1 run_guard "recursive request") >"$test_home/out" 2>"$test_home/err"; then
  printf 'recursive delegation unexpectedly succeeded\n' >&2
  exit 1
else
  status=$?
fi
test "$status" -eq 70
grep -F 'Refusing recursive Pi CLI delegation' "$test_home/err" >/dev/null
test ! -e "$test_home/invocation"

if (PI_CLI_GLOBAL_PROCESS_COUNT_OVERRIDE=100 run_guard "over budget") >"$test_home/out" 2>"$test_home/err"; then
  printf 'over-budget delegation unexpectedly succeeded\n' >&2
  exit 1
else
  status=$?
fi
test "$status" -eq 75
grep -F 'Pi-related process limit reached' "$test_home/err" >/dev/null
test ! -e "$test_home/invocation"

rm -f "$test_home/invocation" "$test_home/stub.pid"
(
  PI_CLI_GLOBAL_PROCESS_COUNT_OVERRIDE=5 \
  PI_CLI_TREE_PROCESS_COUNT_OVERRIDE=1 \
  run_guard "read the configured integration"
) >/dev/null

grep -Fx 'delegated=1' "$test_home/invocation" >/dev/null
grep -Fx 'depth=1' "$test_home/invocation" >/dev/null
grep -Fx 'args=--no-session -p read the configured integration' "$test_home/invocation" >/dev/null

rm -f "$test_home/invocation" "$test_home/stub.pid"
if (
  PI_CLI_GLOBAL_PROCESS_COUNT_OVERRIDE=5 \
  PI_CLI_TREE_PROCESS_COUNT_OVERRIDE=101 \
  PI_CLI_TEST_SLEEP=1 \
  run_guard "runaway request"
) >"$test_home/out" 2>"$test_home/err"; then
  printf 'runaway delegation unexpectedly succeeded\n' >&2
  exit 1
else
  status=$?
fi
test "$status" -eq 75
grep -F 'Delegated Pi exceeded its process budget' "$test_home/err" >/dev/null
if [ -f "$test_home/stub.pid" ]; then
  ! kill -0 "$(cat "$test_home/stub.pid")" 2>/dev/null
fi

printf 'Pi CLI recursion and process-budget guard checks passed.\n'
