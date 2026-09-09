#!/usr/bin/env sh
# icon.color used to be hardcoded (0xff888888 / 0xffffffff), deaf to
# theme-switcher entirely. Source the generated palette instead.
. "$HOME/.config/sketchybar/colors.sh"

YABAI="${YABAI_BIN:-$(command -v yabai 2>/dev/null || printf /usr/local/bin/yabai)}"
active_space=$("$YABAI" -m query --spaces --space | jq '.index')

echo $active_space > /tmp/active_space

for sid in {1..10}
do
    echo $sid >> /tmp/active_compare
    if [ "$sid" -eq "$active_space" ]; then
        sketchybar --set space.$sid icon=󰄯 icon.color=$BLACK
    else
        sketchybar --set space.$sid icon=󰄰 icon.color=$WHITE
    fi
done
