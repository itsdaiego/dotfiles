#!/bin/sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:

sketchybar --set "$NAME" background.drawing="$SELECTED"