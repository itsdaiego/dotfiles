#!/bin/sh
# Maps a yabai window "app" name to a Nerd Font (Font Awesome) glyph.
# Falls back to a generic window glyph for anything unmapped.
icon_for_app() {
  case "$1" in
    "Google Chrome"|"Google Chrome Canary") printf '%s' "" ;;
    Safari) printf '%s' "" ;;
    Code|"Visual Studio Code"|Cursor) printf '%s' "" ;;
    Finder) printf '%s' "" ;;
    Terminal|Ghostty|iTerm2|kitty) printf '%s' "" ;;
    Spotify) printf '%s' "" ;;
    Mail) printf '%s' "" ;;
    Messages) printf '%s' "" ;;
    *) printf '%s' "" ;;
  esac
}
