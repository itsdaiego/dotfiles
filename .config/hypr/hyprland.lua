-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")

-- Keep the fullscreen Gamescope session on workspace 2 of the primary display.
o.window("gamescope", { workspace = "2" })
