#!/bin/bash

VOLUME=$(osascript -e 'output volume of (get volume settings)')
MUTED=$(osascript -e 'output muted of (get volume settings)')

if [ "$MUTED" = "true" ]; then
  ICON="󰝟"
elif [ $VOLUME -eq 0 ]; then
  ICON="󰕿"
elif [ $VOLUME -lt 30 ]; then
  ICON="󰖀"
elif [ $VOLUME -lt 70 ]; then
  ICON="󰖀"
else
  ICON="󰕾"
fi

sketchybar --set $NAME icon="$ICON" label="${VOLUME}%"
