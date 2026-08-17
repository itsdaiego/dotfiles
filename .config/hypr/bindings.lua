-- Personal bindings for Omarchy 4.

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
o.bind("SUPER + SHIFT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("SUPER + SHIFT + X", "GitHub", { webapp = "https://github.com/" })
