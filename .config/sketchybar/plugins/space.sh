#!/usr/bin/env sh
. "$HOME/.config/sketchybar/plugins/icon_map.sh"

sid=$(printf '%s' "$NAME" | awk -F. '{print $NF}')

apps=$(/usr/local/bin/yabai -m query --windows --space "$sid" 2>/dev/null | jq -r '[.[] | select(.subrole == "AXStandardWindow") | .app] | unique | .[]')
if [ -z "$apps" ]; then
  icon_str="$sid"
else
  icon_str=""
  while IFS= read -r app; do
    icon_str="${icon_str}$(icon_for_app "$app") "
  done <<EOF
$apps
EOF
  icon_str="${icon_str% }"
fi

sketchybar --set "$NAME" icon="$icon_str" background.drawing="$SELECTED"
