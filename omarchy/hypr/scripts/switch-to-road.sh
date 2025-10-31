#!/bin/bash
hyprctl keyword monitor "HDMI-A-2,disable"
hyprctl keyword monitor "DP-1,disable"
hyprctl keyword monitor "eDP-1,preferred,0x0,1.0"
sleep 0.2
hyprctl keyword source ~/.config/hypr/monitors-road.conf
