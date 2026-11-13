#!/usr/bin/env bash
set -euo pipefail

profiles=("$@")
if [ "${#profiles[@]}" -eq 0 ]; then
    profiles=(personal work)
fi

for profile in "${profiles[@]}"; do
    case "$profile" in
        personal) data_dir="$HOME/.pi-pocket-personal" ;;
        work) data_dir="$HOME/.pi-pocket-work" ;;
        *)
            echo "Unknown profile: $profile. Use personal or work." >&2
            exit 1
            ;;
    esac

    pid_file="$data_dir/server.pid"
    if [ ! -f "$pid_file" ]; then
        echo "Pi Pocket $profile is not running."
        continue
    fi

    pid=$(<"$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Stopped Pi Pocket $profile."
    else
        echo "Pi Pocket $profile was not running."
    fi
    rm -f "$pid_file"
done
