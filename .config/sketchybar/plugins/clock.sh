#!/usr/bin/env sh

source $HOME/.config/sketchybar/colors.sh

sketchybar --set $NAME label="$(date '+%h %d - %H:%M')" \
  icon.drawing=off                     \
  label.color=$FONT_COLOR            \
  label.padding_left=20                \
  label.padding_right=20               \
  background.color=$BACKGROUND           \
  background.corner_radius=10         \
  background.height=40                \
  background.padding_right=10               \
