# Yabai instructions

Read this file before diagnosing, changing, or documenting Yabai on a Mac.

The shared Yabai configuration is the repository-root `yabairc`. The active configuration on a configured Mac is `~/.config/yabairc`. Keep changes to the two files in sync when the local configuration is not already linked to this repository.

## Focus stealing across Spaces

ChatGPT can create a companion overlay that macOS classifies as an `AXDialog`. The overlay stays above other windows and can join every Space. If it activates while a user changes Spaces, it can make the normal ChatGPT window frontmost again. Recording applications can cause a similar jump when macOS follows an application to a Space where it has a window.

Keep the `chatgpt-companion-local` rule in `yabairc`. It matches only ChatGPT windows with the title `ChatGPT`, role `AXWindow`, and subrole `AXDialog`, then sets `sticky=off`. Do not apply the rule to normal ChatGPT windows.

Disable macOS's automatic Space switch on every affected Mac:

```sh
defaults write com.apple.dock workspaces-auto-swoosh -bool false
killall Dock
```

`killall Dock` briefly reloads the Dock and Mission Control. It does not require a Mac restart.

## Scripting-addition setup

Yabai needs its scripting addition to change a window's Space membership. The configuration reloads it after every Dock restart. On each Mac, give the local user passwordless access to that one exact command, then validate and load it:

```sh
printf '%s\n' "$USER ALL=(root) NOPASSWD: /opt/homebrew/bin/yabai --load-sa" | sudo tee /etc/sudoers.d/yabai >/dev/null
sudo chmod 440 /etc/sudoers.d/yabai
sudo visudo -cf /etc/sudoers.d/yabai
sudo /opt/homebrew/bin/yabai --load-sa
```

The sudoers entry permits only `/opt/homebrew/bin/yabai --load-sa`; it does not grant passwordless access to other commands. It requires an administrator password once. Do not edit `/etc/sudoers.d/yabai` without the user's explicit authorization.

## Verify a fix

```sh
sudo -n /opt/homebrew/bin/yabai --load-sa
yabai -m query --windows | jq '.[] | select(.app == "ChatGPT" and .subrole == "AXDialog") | {id, sticky: ."is-sticky"}'
```

The first command must not ask for a password. A ChatGPT companion window must report `"sticky": false`. If an overlay was already open before the rule loaded, unstick it once using its reported ID:

```sh
yabai -m window <window-id> --toggle sticky
```
