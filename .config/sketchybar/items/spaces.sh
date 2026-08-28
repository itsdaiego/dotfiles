SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

for i in "${!SPACE_ICONS[@]}"
do
    sid=$(($i+1))
    sketchybar --add space space.$sid left                           \
        --set space.$sid associated_space=$sid                       \
                         icon=${SPACE_ICONS[i]}                      \
                         icon.padding_left=8                         \
                         icon.padding_right=8                        \
                         background.padding_left=5                   \
                         background.padding_right=5                  \
                         background.color=$WORKSPACE_ACTIVE          \
                         background.corner_radius=7                  \
                         background.height=22                        \
                         background.drawing=off                      \
                         label.drawing=off                           \
                         update_freq=2                               \
                         script="$PLUGIN_DIR/space.sh"               \
                         click_script="$PLUGIN_DIR/focus_space.sh $sid" \
                         icon.font="$FONT:Medium:13.0"
done
