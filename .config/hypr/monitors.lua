-- Restored from dotfiles after the Omarchy 4 migration.
-- Current desktop outputs: Acer XB271HU primary on the left, LG DualUp on the right.

hl.env("GDK_SCALE", "1")

hl.monitor({ output = "DP-3", mode = "2560x1440@120", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x2880@59.97", position = "2560x0", scale = 1 })

hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", persistent = true })
