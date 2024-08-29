#!/bin/bash

if [ "$SELECTED" = "true" ]; then
  sketchybar --set $NAME background.color=0xffAE5630
else
  sketchybar --set $NAME background.color=0xff2C2B28
fi
