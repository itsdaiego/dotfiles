#!/bin/sh

set -eu

EX_RECURSIVE=70
EX_RESOURCE_LIMIT=75

die() {
  printf '%s\n' "$1" >&2
  exit "$2"
}

require_non_negative_integer() {
  case $2 in
    ''|*[!0-9]*) die "$1 must be a non-negative integer, got: $2" 64 ;;
  esac
}

if [ "$#" -ne 1 ]; then
  die "Usage: $0 '<task prompt>'" 64
fi

prompt=$1
depth=${PI_CLI_DELEGATION_DEPTH:-0}
global_process_limit=${PI_CLI_GLOBAL_PROCESS_LIMIT:-100}
tree_process_limit=${PI_CLI_TREE_PROCESS_LIMIT:-100}
monitor_interval=${PI_CLI_MONITOR_INTERVAL:-0.5}
pi_bin=${PI_CLI_BIN:-pi}

require_non_negative_integer PI_CLI_DELEGATION_DEPTH "$depth"
require_non_negative_integer PI_CLI_GLOBAL_PROCESS_LIMIT "$global_process_limit"
require_non_negative_integer PI_CLI_TREE_PROCESS_LIMIT "$tree_process_limit"

if [ "${PI_CLI_DELEGATED:-0}" = "1" ] || [ "$depth" -gt 0 ]; then
  die "Refusing recursive Pi CLI delegation. The current process is already an isolated Pi delegate." "$EX_RECURSIVE"
fi

count_pi_related_processes() {
  if [ -n "${PI_CLI_GLOBAL_PROCESS_COUNT_OVERRIDE:-}" ]; then
    printf '%s\n' "$PI_CLI_GLOBAL_PROCESS_COUNT_OVERRIDE"
    return
  fi

  uid=$(id -u)
  /bin/ps -axo uid=,ucomm=,command= | /usr/bin/awk -v uid="$uid" '
    $1 == uid {
      executable = $2
      if ((executable == "node" || executable == "npm") &&
          ($3 == "pi" || $3 == "pi-work" || $3 == "pi-personal" ||
           $3 ~ /\/pi$/ || $3 ~ /\/pi-work$/ || $3 ~ /\/pi-personal$/ ||
           $0 ~ /pi-pocket/ || $0 ~ /pi-coding-agent/ || $0 ~ /playwright-mcp/ ||
           $0 ~ /gws-mcp-server/ || $0 ~ /next-devtools-mcp/)) {
        count++
      }
    }
    END { print count + 0 }
  '
}

descendant_pids() {
  root_pid=$1
  /bin/ps -axo pid=,ppid= | /usr/bin/awk -v root="$root_pid" '
    { parent[$1] = $2 }
    END {
      for (pid in parent) {
        current = pid
        steps = 0
        while (current in parent && current > 1 && steps < 10000) {
          if (current == root) {
            print pid
            break
          }
          current = parent[current]
          steps++
        }
      }
    }
  '
}

count_tree_processes() {
  if [ -n "${PI_CLI_TREE_PROCESS_COUNT_OVERRIDE:-}" ]; then
    printf '%s\n' "$PI_CLI_TREE_PROCESS_COUNT_OVERRIDE"
    return
  fi
  descendant_pids "$1" | /usr/bin/awk 'NF { count++ } END { print count + 0 }'
}

terminate_tree() {
  root_pid=$1
  pids=$(descendant_pids "$root_pid" 2>/dev/null || true)
  case " $pids " in
    *" $root_pid "*) ;;
    *) pids="$pids $root_pid" ;;
  esac

  for pid in $pids; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  attempts=0
  while kill -0 "$root_pid" 2>/dev/null && [ "$attempts" -lt 20 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
  done

  for pid in $pids; do
    kill -KILL "$pid" 2>/dev/null || true
  done
  wait "$root_pid" 2>/dev/null || true
}

global_process_count=$(count_pi_related_processes)
require_non_negative_integer detected_Pi_process_count "$global_process_count"
if [ "$global_process_count" -ge "$global_process_limit" ]; then
  die "Pi-related process limit reached: $global_process_count active, limit $global_process_limit. Refusing to spawn another Pi." "$EX_RESOURCE_LIMIT"
fi

next_depth=$((depth + 1))
PI_CLI_DELEGATED=1 PI_CLI_DELEGATION_DEPTH=$next_depth \
  "$pi_bin" --no-session -p "$prompt" &
child_pid=$!

on_signal() {
  trap - HUP INT TERM
  terminate_tree "$child_pid"
  exit 130
}
trap on_signal HUP INT TERM

while kill -0 "$child_pid" 2>/dev/null; do
  tree_process_count=$(count_tree_processes "$child_pid")
  require_non_negative_integer detected_tree_process_count "$tree_process_count"

  if [ "$tree_process_count" -gt "$tree_process_limit" ]; then
    printf 'Delegated Pi exceeded its process budget: %s processes; limit is %s. Stopping it.\n' \
      "$tree_process_count" "$tree_process_limit" >&2
    trap - HUP INT TERM
    terminate_tree "$child_pid"
    exit "$EX_RESOURCE_LIMIT"
  fi

  sleep "$monitor_interval"
done

trap - HUP INT TERM
set +e
wait "$child_pid"
status=$?
set -e
exit "$status"
