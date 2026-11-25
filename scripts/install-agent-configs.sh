#!/bin/sh

set -eu

script_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
common_git_dir=$(git -C "$script_repo_dir" rev-parse --path-format=absolute --git-common-dir)
repo_dir=$(dirname -- "$common_git_dir")
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
  link_target "$(resolve_source_path "$source_path")" "$HOME/$relative_path"
}

copy_target() {
  source_path=$1
  target_path=$2
  relative_path=${target_path#"$HOME"/}

  mkdir -p -- "$(dirname -- "$target_path")"

  if [ -f "$target_path" ] && ! [ -L "$target_path" ] && cmp -s "$source_path" "$target_path"; then
    return
  fi

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    backup_path=$backup_root/$relative_path
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_path" "$backup_path"
  fi

  cp -- "$source_path" "$target_path"
}

resolve_source_path() {
  source_path=$1
  original_source_path=$source_path

  while [ -L "$source_path" ]; do
    link_path=$(readlink "$source_path")
    case "$link_path" in
      /*) source_path=$link_path ;;
      *) source_path=$(dirname -- "$source_path")/$link_path ;;
    esac
    source_dir=$(CDPATH= cd -P -- "$(dirname -- "$source_path")" 2>/dev/null && pwd) || {
      printf '%s\n' "$original_source_path"
      return
    }
    source_path=$source_dir/$(basename -- "$source_path")
  done

  printf '%s\n' "$source_path"
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

retire_renamed_path() {
  target_path=$1
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    relative_path=${target_path#"$HOME"/}
    backup_path=$backup_root/$relative_path
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_path" "$backup_path"
  fi
}

for old_review_risk_path in \
  "$HOME/.pi/agent/skills/walle-review-risk" \
  "$HOME/.pi/pi-personal/skills/walle-review-risk" \
  "$HOME/.claude/skills/walle-review-risk" \
  "$HOME/.codex/skills/walle-review-risk"
do
  retire_renamed_path "$old_review_risk_path"
done

for config_root in .ai .config/herdr/scripts .agent-customizations .codex .codex-personal .claude .pi .local/bin; do
  prepare_config_root "$config_root"
  git -C "$repo_dir" ls-files -- "$config_root" | while IFS= read -r relative_path; do
    link_one "$repo_dir/$relative_path"
  done
done

for pocket_profile in .pi-pocket-work .pi-pocket-personal; do
  for extension_file in \
    _document-extractor-typecheck-guard.ts \
    _jev-auto-policy.ts \
    document-extractor-typecheck-guard.ts \
    jev-auto.ts
  do
    copy_target \
      "$repo_dir/pi-durable/extensions/$extension_file" \
      "$HOME/$pocket_profile/extensions/$extension_file"
  done
done

link_target "$HOME/.pi/agent" "$HOME/.pi/pi-work"
link_target "$HOME/.pi/pi-personal/AGENTS.md" "$HOME/.codex-personal/AGENTS.md"
link_target "$HOME/.codex/skills" "$HOME/.codex-personal/skills"
link_target "$HOME/.codex/rules/default.rules" "$HOME/.codex-personal/rules/default.rules"

if [ -d "$backup_root" ]; then
  printf 'Existing files were backed up under %s\n' "$backup_root"
fi

printf 'Codex company/personal, Claude Code, and Pi configuration now points at %s\n' "$repo_dir"
