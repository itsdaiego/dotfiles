#!/bin/bash

if hyprctl monitors | grep -q "HDMI-A-2" && hyprctl monitors | grep -q "DP-1"; then
    hyprctl keyword source ~/.config/hypr/monitors-home.conf
else
    hyprctl keyword source ~/.config/hypr/monitors-road.conf
fi
