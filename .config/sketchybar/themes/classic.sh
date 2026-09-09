#!/bin/sh
PLUGIN_DIR="$HOME/.config/sketchybar/plugins"
ITEM_DIR="$HOME/.config/sketchybar/items"

source $HOME/.config/sketchybar/colors.sh
source $HOME/.config/sketchybar/icons.sh

export FONT="JetBrainsMono Nerd Font"
export NERD_FONT="JetBrainsMono Nerd Font"

# Keep the bar at the top; Yabai reserves space below it for windows.
sketchybar --bar height=32              \
                 blur_radius=60         \
                 position=top           \
                 margin=0               \
                 y_offset=2             \
                 padding_left=8         \
                 padding_right=8        \
                 color=$TRANSPARENT     \
                 shadow=off

sketchybar --default updates=when_shown                       \
                     drawing=on                               \
                     icon.font="$NERD_FONT:Bold:14.0"      \
                     icon.color=$WHITE                        \
                     label.font="$FONT:Light:13.0"          \
                     label.color=$WHITE                       \
                     label.padding_left=4                     \
                     label.padding_right=4                    \
                     icon.padding_left=4                      \
                     icon.padding_right=4

source $ITEM_DIR/spaces.sh
source $ITEM_DIR/window_title.sh
source $ITEM_DIR/clock.sh
source $ITEM_DIR/battery.sh
source $ITEM_DIR/cpu.sh
source $ITEM_DIR/vpn.sh
source $ITEM_DIR/wifi.sh
source $ITEM_DIR/darkside.sh

# Keep all status controls on a consistent, larger type scale.
sketchybar --set clock label.font="$FONT:Light:16.0"              \
           --set battery icon.font="$NERD_FONT:Bold:17.0"         \
                         label.font="$FONT:Light:16.0"             \
           --set cpu.percent icon.font="$NERD_FONT:Bold:17.0"     \
                             label.font="$FONT:Medium:16.0"        \
           --set wifi.control icon.font="$NERD_FONT:Bold:17.0"    \
           --set appearance icon.font="$NERD_FONT:Bold:17.0"      \
           --set vpn icon.font="$NERD_FONT:Bold:17.0"

# Apple logo, then workspaces, then the app title -- all in one left group.
sketchybar --add bracket left_cluster space.1 space.2 space.3 space.4 space.5 space.6 space.7 space.8 space.9 space.10 window_title \
           --set left_cluster background.color=$GROUP_BG                         \
                              background.border_color=$GROUP_BORDER               \
                              background.border_width=1                           \
                              background.corner_radius=10                         \
                              background.height=28                                \
                              background.padding_left=9                           \
                              background.padding_right=9                          \
                              background.shadow.drawing=on                        \
                              background.shadow.color=0x66000000                  \
                              background.shadow.distance=3                        \
           --add bracket status_cluster clock battery cpu.top cpu.percent cpu.sys cpu.user vpn wifi.control appearance \
           --set status_cluster background.color=$GROUP_BG                         \
                                background.border_color=$GROUP_BORDER               \
                                background.border_width=1                           \
                                background.corner_radius=10                         \
                                background.height=28                                \
                                background.padding_left=9                           \
                                background.padding_right=9                          \
                                background.shadow.drawing=on                        \
                                background.shadow.color=0x66000000                  \
                                background.shadow.distance=3

sketchybar --update

echo "sketchybar configuration loaded.."
