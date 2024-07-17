source "$PLUGIN_DIR/wifi.sh"

sketchybar --add item           wifi.control right                      \
                                                                        \
           --set wifi.control   icon=$WIFI_ICN                          \
                                icon.font="$NERD_FONT:Regular:22.0"     \
                                label.drawing=off                       \
                                click_script="$POPUP_CLICK_SCRIPT"      \
                                popup.blur_radius=50                    \
                                popup.background.corner_radius=5        \
                                icon.padding_left=20              \
                                icon.padding_right=20             \
                                icon.color=$FONT_COLOR            \
                                background.color=$BACKGROUND                \
                                background.padding_left=10              \
                                background.corner_radius=10             \
                                background.height=40                    \
                                background.drawing=on                   \
                                                                        \
           --add item           wifi.ssid popup.wifi.control            \
           --set wifi.ssid      icon=$NETWORK_ICN                       \
                                label="${SSID}"                         \
                                                                        \
           --add item           wifi.speed popup.wifi.control           \
           --set wifi.speed     icon=$SPEED_ICN                         \
                                script="$PLUGIN_DIR/wifi_click.sh"      \
                                update_freq=10
