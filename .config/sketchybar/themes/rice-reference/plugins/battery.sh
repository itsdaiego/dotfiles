#!/bin/sh
# Reference battery glyphs using Melange semantic colours.
source "$HOME/.config/sketchybar/colors.sh"
pct=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -n "$pct" ] || exit 0
charging=$(pmset -g batt | grep -c 'AC Power' || true)
if [ "$charging" -gt 0 ]; then
  icon="󰂅"
elif [ "$pct" -ge 90 ]; then icon="󰁹"
elif [ "$pct" -ge 70 ]; then icon="󰂂"
elif [ "$pct" -ge 50 ]; then icon="󰁿"
elif [ "$pct" -ge 30 ]; then icon="󰁽"
elif [ "$pct" -ge 10 ]; then icon="󰁺"
else icon="󰂎"
fi
color=$GREEN
if [ "$pct" -lt 20 ]; then color=$RED; elif [ "$pct" -lt 50 ]; then color=$ORANGE; elif [ "$pct" -lt 70 ]; then color=$YELLOW; fi
sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="${pct}%"
