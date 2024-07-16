#!/usr/bin/env sh

active_space=$(/usr/local/bin/yabai -m query --spaces --space | jq '.index')

echo $active_space > /tmp/active_space

for sid in {1..10}
do
    echo $sid >> /tmp/active_compare
    if [ "$sid" -eq "$active_space" ]; then
        sketchybar --set space.$sid icon=󰄯 icon.color=0xff888888
    else
        sketchybar --set space.$sid icon=󰄰 icon.color=0xffffffff
    fi
done
