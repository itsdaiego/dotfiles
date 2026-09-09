#!/usr/bin/env sh

# front_app_switched supplies the front app's name in $INFO.
APP="${INFO:-$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)}"
ICON="$("$HOME/.config/sketchybar/plugins/icon_map.sh" "$APP")"

sketchybar --set "$NAME" label="$APP" icon="$ICON"
