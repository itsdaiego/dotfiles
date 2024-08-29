#!/bin/bash

WIFI_DEVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $2}')
WIFI_INFO=$(networksetup -getairportnetwork $WIFI_DEVICE)
SSID=$(echo "$WIFI_INFO" | awk -F': ' '{print $2}')

if [ -z "$SSID" ]; then
  ICON="󰤭"
  LABEL="Disconnected"
else
  SIGNAL_STRENGTH=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk -F': ' '/agrCtlRSSI/ {print $2}')
  
  if [ $SIGNAL_STRENGTH -gt -50 ]; then
    ICON="󰤨"
  elif [ $SIGNAL_STRENGTH -gt -60 ]; then
    ICON="󰤥"
  elif [ $SIGNAL_STRENGTH -gt -70 ]; then
    ICON="󰤢"
  else
    ICON="󰤟"
  fi
  
  LABEL="$SSID"
fi

sketchybar --set $NAME icon="$ICON" label="$LABEL"
