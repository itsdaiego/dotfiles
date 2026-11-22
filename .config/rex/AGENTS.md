# Rex instructions

Read this file before diagnosing, changing, or documenting Rex on a Mac.

The shared Rex configuration is the repository `.config/rex/init.lua` and `.config/rex/large-picker.py`, mirroring `tmux`-style bindings from `~/.config/herdr/config.toml`. The active configuration on a configured Mac is `~/.config/rex/init.lua` and `~/.config/rex/large-picker.py`. Keep changes to the two pairs of files in sync when the local configuration is not already linked to this repository.

Reload Rex after an `init.lua` change with `Ctrl+B`, then `R`, or `rex config reload`. Run `rex config check` afterward; it should report zero diagnostics.

## Keybindings

`Ctrl+B` enters a one-key tmux-style prefix mode (`rex.mode("tmux_prefix", ...)`), used instead of Rex key sequences so number keys reliably switch sessions by index.

| Key | Action |
| --- | --- |
| `Ctrl+B`, then `W` | Large picker listing every running program; opens the exact selected pane |
| `Ctrl+B`, then `A` | Large picker listing agents with their Rex session names |
| `Ctrl+B`, then `N` / `P` | Next / previous tab |
| `Ctrl+B`, then `X` | Close the focused pane |
| `Ctrl+B`, then `Z` | Toggle maximize/restore on the focused pane |
| `Ctrl+B`, then `0`–`9` | Go to session by Herdr's zero-based order |
| `Ctrl+B`, then `B` | Toggle the sidebar |
| `Ctrl+B`, then `S` | Split down |
| `Ctrl+B`, then `V` | Split right |
| `Ctrl+B`, then `R` | Reload the Rex config |
| `Ctrl+B`, then `H`/`J`/`K`/`L` | Focus pane in that direction |
| `Alt+H`/`J`/`K`/`L` | Focus pane in that direction, without the prefix |
| `Alt+Arrow` | Resize the focused pane 10% in that direction |
| `Ctrl+B`, then `Alt+H`/`J`/`K`/`L` | Resize the focused pane 1% in that direction |
| `Ctrl+B`, then `Shift+R` | Enter resize mode (arrows or `H`/`J`/`K`/`L`; exit with Enter, Escape, or the same chord again) |
| `Ctrl+B` twice | Send a literal `Ctrl+B` to the terminal |

The two pickers (`large_program_picker`, `large_agent_picker`) open as large floating panes at 84% of the window's width and 78% of its height, because Rex's native session/pane switchers have a fixed size too small for a vertical display. `picker_snapshot()` gathers one in-process Rex snapshot before opening a picker; querying each pane's process separately made the picker take 1–2 seconds instead of about 0.5.

## Keeping focus zoomed across panes

Rex's native `pane.focus` ends any zoom in the window when it moves focus (confirmed in `session.focus_direction`'s API notes: "Moving focus ends any zoom in the window"). That means `Ctrl+B Z` to maximize a pane, then moving focus to a neighbor, used to reset the whole window back to its tiled layout instead of staying maximized on the newly focused pane.

`zoom_aware_focus` in `init.lua` wraps `session.focus_direction` and `session.zoom_block`: it reads whether the active window is zoomed before moving focus, moves focus in the requested direction, then re-zooms the window on the pane focus landed on if it was zoomed before. All of the direction bindings above (`Ctrl+B H`/`J`/`K`/`L` and `Alt+H`/`J`/`K`/`L`) use this action instead of the native `pane.focus`. When the window isn't zoomed, it behaves exactly like `pane.focus`.

## Sidebar size patch

Rex's sidebar text setting caps out at 15pt in its own UI, and the sidebar is pinned to the right and always visible. The current setup patches past that cap directly in `/Users/daiego/Library/Preferences/com.superlogical.rex.plist`, since Rex is a signed, closed-source app and patching its binary would be brittle:

- Sidebar text: 25pt
- Sidebar width: 600
- Backup of the original binary: `~/Library/Application Support/com.superlogical.rex/Patches/Rex-2042-original.app`

A Rex update can overwrite this patch and reset the sidebar to its default size and width. The settings UI's own size control still caps at 15pt; using it can also reset the patched value.

## Session naming and notifications

New Pi sessions automatically rename their Rex session by topic, and the `rename-session` skill supports Herdr, Rex, and Claude Code Remote as naming targets — see `.agent-customizations/rename-session/SKILL.md`. Rex also shows a macOS notification when an agent finishes while Rex is in the background (no sound or Dock badge, matching the Herdr setup), configured in the same preferences file as the sidebar patch.
