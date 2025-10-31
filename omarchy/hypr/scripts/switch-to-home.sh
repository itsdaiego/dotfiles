#!/bin/bash
hyprctl keyword monitor "eDP-1,disable"
hyprctl keyword monitor "HDMI-A-2,2560x1440@120,0x0,1.0"
hyprctl keyword monitor "DP-1,2560x2880@59.98,2560x0,1.0"
hyprctl keyword source ~/.config/hypr/monitors-home.conf
