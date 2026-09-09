#!/bin/bash

APP="Spotify"
if ! pgrep -xq "$APP"; then
  sketchybar --set media drawing=off
  exit 0
fi

STATE=$(osascript -e 'tell application "Spotify" to player state as string')
if [ "$STATE" = "playing" ]; then
  TITLE=$(osascript -e 'tell application "Spotify" to name of current track as string')
  ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track as string')
  MEDIA="$TITLE - $ARTIST"
  sketchybar --set media label="$MEDIA" drawing=on
else
  sketchybar --set media drawing=off
fi