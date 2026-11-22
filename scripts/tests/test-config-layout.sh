#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"

for legacy_path in \
  .tmux.conf \
  i3 \
  i3blocks \
  omarchy \
  picom \
  rex \
  rofi \
  sketchybar \
  waybar \
  yabai \
  yabairc
do
  test ! -e "$legacy_path"
done

for canonical_path in \
  .config/i3/config \
  .config/i3blocks/config \
  .config/picom/picom.conf \
  .config/rex/init.lua \
  .config/rofi/config \
  .config/tmux/tmux.conf \
  .config/waybar/config.jsonc \
  .config/yabai/yabairc \
  profiles/omarchy
do
  test -e "$canonical_path"
done

if git ls-files | grep -E '(^|/)\.DS_Store$|(^|/)__pycache__/|\.pyc$' >/dev/null; then
  echo "generated files are tracked" >&2
  exit 1
fi

printf 'Dotfile layout checks passed.\n'
