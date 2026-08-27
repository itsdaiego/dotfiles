-- Performance overrides restored from dotfiles.
hl.config({
  decoration = { blur = { enabled = false } },
  misc = { vrr = 2, disable_autoreload = false },
  cursor = { no_hardware_cursors = true },
})

hl.curve("snappy", { type = "bezier", points = { { 0.1, 0.9 }, { 0.1, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "default", style = "popin 90%" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = false })
