#!/usr/bin/env bash
set -euo pipefail

profiles=("$@")
if [ "${#profiles[@]}" -eq 0 ]; then
    profiles=(personal work)
fi

if ! command -v pi-pocket >/dev/null; then
    echo "pi-pocket is not installed. Run: npm install -g pi-pocket" >&2
    exit 1
fi

for profile in "${profiles[@]}"; do
    case "$profile" in
        personal)
            agent_dir="$HOME/.pi/pi-personal"
            port=8788
            data_dir="$HOME/.pi-pocket-personal"
            ;;
        work)
            agent_dir="$HOME/.pi/pi-work"
            port=8789
            data_dir="$HOME/.pi-pocket-work"
            ;;
        *)
            echo "Unknown profile: $profile. Use personal or work." >&2
            exit 1
            ;;
    esac

    pid_file="$data_dir/server.pid"
    log_file="$data_dir/server.log"

    if [ -f "$pid_file" ] && kill -0 "$(<"$pid_file")" 2>/dev/null; then
        echo "Pi Pocket $profile is already running on port $port."
        continue
    fi

    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Port $port is already in use; Pi Pocket $profile was not started." >&2
        exit 1
    fi

    mkdir -p "$data_dir"
    env \
        PI_CODING_AGENT_DIR="$agent_dir" \
        PI_CODING_AGENT_SESSION_DIR="$HOME/.pi/agent/sessions" \
        nohup pi-pocket --access tailscale --port "$port" --data "$data_dir" --cwd "$HOME" \
        >"$log_file" 2>&1 &
    echo "$!" >"$pid_file"

    for _ in $(seq 1 10); do
        if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Pi Pocket $profile did not start. Read $log_file." >&2
        exit 1
    fi

    echo "Pi Pocket $profile is running at http://$(tailscale ip -4):$port"
done
