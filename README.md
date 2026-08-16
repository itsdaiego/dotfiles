# dotfiles

Personal dotfiles that make my life easier! :D

## Shared configuration

`.config/` is the portable source for XDG configuration shared by Omarchy and macOS.

### Herdr

Keep Herdr in `.config/herdr/config.toml` only—do not duplicate it under `omarchy/`.
Both systems use the same compact, borderless pane layout with visible scrollbars. It uses
the host terminal's ANSI palette: Omarchy supplies that palette from its active theme,
while macOS uses the palette of whichever terminal hosts Herdr.
