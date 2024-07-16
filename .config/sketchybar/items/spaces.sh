#!/usr/bin/env sh

PLUGIN_DIR="$HOME/.config/sketchybar/plugins"
FONT="JetBrainsMono Nerd Font"

# Add spaces and set properties
for i in {1..10}
do
    sid=$(($i))
    sketchybar --add space space.$sid left                                  \
               --set space.$sid associated_space=$sid                       \
                                 icon=󰄯                                     \
                                 icon.padding_left=10                       \
                                 icon.padding_right=15                      \
                                 icon.color=0xff888888                      \
                                 label.drawing=off                          \
                                 script="$PLUGIN_DIR/spaces.sh"              \
                                 click_script="yabai -m space --focus $sid" \
                                 icon.font="$FONT:Bold:22.0"                \
               --subscribe space.$sid front_app_switched space_changed window_focus
done

# Script to update the workspace icons
cat << 'EOF' > "$PLUGIN_DIR/spaces.sh"
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
EOF

chmod +x "$PLUGIN_DIR/spaces.sh"
