-- Restored from dotfiles after the Omarchy 4 migration.
hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "intl",
    -- Keep the Keychron's physical Alt and Super keys in their normal places.
    kb_options = "",
    repeat_rate = 40,
    repeat_delay = 300,
    numlock_by_default = true,
    touchpad = { scroll_factor = 0.4 },
  },
})

o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
