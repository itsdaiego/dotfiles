#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
backup_root="$HOME/.dotfiles-backups/$(date '+%Y%m%dT%H%M%S')"

link_target() {
  source_path=$1
  target_path=$2
  relative_path=${target_path#"$HOME"/}
  target_dir=$(dirname -- "$target_path")

  mkdir -p -- "$target_dir"

  if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
    return
  fi

  if [ -e "$target_path" ] && [ "$source_path" -ef "$target_path" ]; then
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path=$backup_root/$relative_path
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_path" "$backup_path"
  fi

  ln -s -- "$source_path" "$target_path"
}

link_one() {
  source_path=$1
  relative_path=${source_path#"$repo_dir"/}
  prepare_target_dir "$(dirname -- "$relative_path")"
  link_target "$source_path" "$HOME/$relative_path"
}

prepare_target_dir() {
  [ "$1" = "." ] && return

  parent_dir=$(dirname -- "$1")
  prepare_target_dir "$parent_dir"

  source_dir=$repo_dir/$1
  target_dir=$HOME/$1
  if [ -L "$target_dir" ] && [ -d "$source_dir" ] && ! [ "$source_dir" -ef "$target_dir" ]; then
    backup_path=$backup_root/$1
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_dir" "$backup_path"
  fi
  mkdir -p -- "$target_dir"
}

prepare_config_root() {
  relative_root=$1
  source_root=$repo_dir/$relative_root
  target_root=$HOME/$relative_root

  if [ -L "$target_root" ] && ! [ "$source_root" -ef "$target_root" ]; then
    backup_path=$backup_root/$relative_root
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_root" "$backup_path"
    mkdir -p -- "$target_root"
  fi
}

for config_root in .config/herdr/scripts .agent-customizations .codex .codex-personal .claude .pi .local/bin; do
  prepare_config_root "$config_root"
  git -C "$repo_dir" ls-files -- "$config_root" | while IFS= read -r relative_path; do
    link_one "$repo_dir/$relative_path"
  done
done

link_target "$HOME/.pi/pi-personal/AGENTS.md" "$HOME/.codex-personal/AGENTS.md"
link_target "$HOME/.codex/skills" "$HOME/.codex-personal/skills"
link_target "$HOME/.codex/rules/default.rules" "$HOME/.codex-personal/rules/default.rules"

if [ -d "$backup_root" ]; then
  printf 'Existing files were backed up under %s\n' "$backup_root"
fi

printf 'Codex company/personal, Claude Code, and Pi configuration now points at %s\n' "$repo_dir"
