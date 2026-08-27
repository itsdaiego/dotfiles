-- Personal bindings restored from dotfiles after the Omarchy 4 migration.

-- Override Omarchy's default terminal binding (currently Kitty) with Alacritty.
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Alacritty", { launch = "alacritty" })

hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")
o.bind("SUPER + H", "Move window focus left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Move window focus down", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Move window focus up", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Move window focus right", hl.dsp.focus({ direction = "r" }))

-- Press once to record; press again to stop, transcribe, and copy the text.
o.bind("SUPER + D", "Voice dictation (WhisperX toggle)", "/home/daiego/.local/bin/omarchy-voice-toggle")

hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + G")
hl.unbind("SUPER + SHIFT + X")
o.bind("SUPER + SHIFT + C", "Claude", { webapp = "https://claude.com" })
o.bind("SUPER + SHIFT + G", "GameScope + Steam", "omarchy-launch-or-focus gamescope \"STEAM_MULTIPLE_XWAYLANDS=1 gamescope -W 2560 -H 1440 -r 144 -f -e --xwayland-count 2 -- env MANGOHUD=1 steam -gamepadui -fulldesktopres -fullscreen\"")
o.bind("SUPER + SHIFT + X", "GitHub", { webapp = "https://github.com/" })

o.bind("SUPER + Page_Up", "Screenshot area to clipboard", "omarchy capture screenshot region copy")

-- SUPER + P was previously bound to Pseudo window.
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Omarchy menu", "omarchy menu")
