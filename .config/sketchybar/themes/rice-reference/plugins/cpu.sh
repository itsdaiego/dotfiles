#!/bin/sh
# Reference CPU item with thresholds recoloured for Kitty Melange.
source "$HOME/.config/sketchybar/colors.sh"
cores=$(sysctl -n machdep.cpu.thread_count)
cpu_info=$(ps -eo pcpu,user)
cpu_sys=$(printf '%s\n' "$cpu_info" | grep -v "$(whoami)" | sed 's/[^ 0-9\.]//g' | awk "{sum+=\$1} END {print sum/(100.0 * $cores)}")
cpu_user=$(printf '%s\n' "$cpu_info" | grep "$(whoami)" | sed 's/[^ 0-9\.]//g' | awk "{sum+=\$1} END {print sum/(100.0 * $cores)}")
pct=$(printf '%s %s\n' "$cpu_sys" "$cpu_user" | awk '{printf "%.0f", ($1 + $2) * 100}')
color=$WHITE
if [ "$pct" -ge 80 ]; then color=$RED; elif [ "$pct" -ge 50 ]; then color=$YELLOW; fi
sketchybar --set "$NAME" icon="" icon.color="$color" label="${pct}%"
