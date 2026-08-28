#!/usr/bin/env sh

# One compact CPU item keeps the right-hand group on the same text scale as
# the workspace switcher. The hidden graphs still receive data for later use.
sketchybar --add item        cpu.percent right              \
           --set cpu.percent icon=󰍛                          \
                             label.font="$FONT:Medium:13.0" \
                             icon.font="$NERD_FONT:Bold:14.0" \
                             label=CPU                       \
                             y_offset=0                      \
                             update_freq=5                   \
                             background.padding_right=4      \
                                                            \
           --add graph       cpu.sys right 1                 \
           --set cpu.sys     drawing=off                     \
                             label.drawing=off               \
                             icon.drawing=off                \
                                                            \
           --add graph       cpu.user right 1                \
           --set cpu.user    drawing=off                     \
                             update_freq=5                   \
                             label.drawing=off               \
                             icon.drawing=off                \
                             script="$PLUGIN_DIR/cpu.sh"
