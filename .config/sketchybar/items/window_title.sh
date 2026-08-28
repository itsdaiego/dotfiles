#!/usr/bin/env sh

sketchybar --add item window_title left                     \
--set window_title    script="$PLUGIN_DIR/window_title.sh" \
icon.drawing=off                     \
label.font="$FONT:Medium:16.0"           \
label.padding_right=6                    \
--subscribe window_title front_app_switched
