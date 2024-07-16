#!/usr/bin/env sh

source $HOME/.config/sketchybar/colors.sh
source $HOME/.config/sketchybar/icons.sh

sketchybar --add item space_separator left                            \
--add item window_title left                               \
--set window_title    script="$PLUGIN_DIR/window_title.sh" \
icon.drawing=off                     \
label.color=$FONT_COLOR              \
label.padding_left=20                    \
label.padding_right=20                   \
background.color=$BORDER_COLOR   \
background.height=40                 \
background.corner_radius=10          \
--subscribe window_title front_app_switched
