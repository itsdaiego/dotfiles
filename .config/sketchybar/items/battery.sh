#!/usr/bin/env sh

PLUGIN_DIR="$HOME/.config/sketchybar/plugins"
ITEM_DIR="$HOME/.config/sketchybar/items"

source "$PLUGIN_DIR/battery.sh"

sketchybar --add item battery right                      \
           --set battery script="$PLUGIN_DIR/battery.sh" \
                         update_freq=10                  \
                         icon.font="$NERD_FONT:Regular:22.0" \
                         label.drawing=off               \
                         icon.padding_left=20            \
                         icon.padding_right=20           \
                         icon.color=$FONT_COLOR          \
                         background.color=$BACKGROUND     \
                         background.corner_radius=10     \
                         background.padding_right=10     \
                         background.height=40            \
                         background.drawing=on           \
           --subscribe battery system_woke
