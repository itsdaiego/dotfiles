#!/bin/sh
# Optimistically update the workspace indicator before macOS finishes the
# Mission Control transition. SketchyBar's native space_change event later
# confirms the real selection.
space="$1"

case "$space" in
  [1-9]|10) ;;
  *) exit 2 ;;
esac

# Resolve through PATH on the destination Homebrew install, but retain the
# source Mac's local Yabai fallback. Optional overrides support custom paths.
SKETCHYBAR="${SKETCHYBAR_BIN:-sketchybar}"
if [ -n "${YABAI_BIN:-}" ]; then
  YABAI="$YABAI_BIN"
elif command -v yabai >/dev/null 2>&1; then
  YABAI="$(command -v yabai)"
elif [ -x /usr/local/bin/yabai ]; then
  YABAI=/usr/local/bin/yabai
else
  exit 127
fi

"$SKETCHYBAR" \
  --set space.1 background.drawing=off \
  --set space.2 background.drawing=off \
  --set space.3 background.drawing=off \
  --set space.4 background.drawing=off \
  --set space.5 background.drawing=off \
  --set space.6 background.drawing=off \
  --set space.7 background.drawing=off \
  --set space.8 background.drawing=off \
  --set space.9 background.drawing=off \
  --set space.10 background.drawing=off \
  --set "space.$space" background.drawing=on

exec "$YABAI" -m space --focus "$space"
