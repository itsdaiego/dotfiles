#!/bin/sh

source $HOME/.config/sketchybar/icons.sh
source $HOME/.config/sketchybar/colors.sh

if [[ $(defaults read -g AppleInterfaceStyle 2>/dev/null) == "Dark" ]]
then
    sketchybar -m --set appearance icon="$SUN_ICN"
else
    sketchybar -m --set appearance icon="$MOON_ICN"
fi

sketchybar --set appearance             \
           label.drawing=off                       \
           icon.padding_left=20                    \
           icon.padding_right=20                   \
           icon.color=$FONT_COLOR                  \
           background.color=$BACKGROUND                \
           background.corner_radius=10             \
           background.height=40                    \
           background.drawing=on

