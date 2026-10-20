#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')

RESET=$'\033[0m'
BOLD_GREEN=$'\033[1;32m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'

# --- [directory]: mirrors starship's directory module (home -> ~, truncate to 3, read-only flag) ---
dir_display="$cwd"
[[ "$dir_display" == "$HOME"* ]] && dir_display="~${dir_display#"$HOME"}"
depth=$(awk -F'/' '{print NF}' <<< "$dir_display")
if [ "$depth" -gt 3 ]; then
  dir_display="…/$(awk -F'/' '{print $(NF-2)"/"$(NF-1)"/"$NF}' <<< "$dir_display")"
fi
ro=""
[ -w "$cwd" ] || ro=" (read only)"
dir_segment=$(printf '%s%s%s%s' "$CYAN" "$dir_display" "$RESET" "$ro")

# --- [git_branch] / [git_commit] / [git_status] / [git_metrics] ---
git_segment=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  # detached HEAD -> mirror [git_commit] (commit_hash_length = 7)
  [ -z "$branch" ] && branch="#$(git -C "$cwd" --no-optional-locks rev-parse --short=7 HEAD 2>/dev/null)"

  porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain=v1 2>/dev/null)
  status_str=""
  ab=$(git -C "$cwd" --no-optional-locks rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null)
  if [ -n "$ab" ]; then
    ahead=$(awk '{print $1}' <<< "$ab")
    behind=$(awk '{print $2}' <<< "$ab")
    [ "${ahead:-0}" -gt 0 ] && status_str+="⇡${ahead}"
    [ "${behind:-0}" -gt 0 ] && status_str+="⇣${behind}"
  fi
  grep -qE '^(UU|AA|DD)' <<< "$porcelain" && status_str+="="
  grep -qE '^\?\?' <<< "$porcelain" && status_str+="?"
  grep -qE '^.[MD]' <<< "$porcelain" && status_str+="!"
  grep -qE '^[MADRC]' <<< "$porcelain" && status_str+="+"
  git -C "$cwd" --no-optional-locks rev-parse --verify refs/stash >/dev/null 2>&1 && status_str+='$'

  # [git_metrics]: format = '([+$added]) ([-$deleted]) '
  shortstat=$(git -C "$cwd" --no-optional-locks diff --shortstat HEAD 2>/dev/null)
  added=$(grep -oE '[0-9]+ insertion' <<< "$shortstat" | grep -oE '[0-9]+')
  deleted=$(grep -oE '[0-9]+ deletion' <<< "$shortstat" | grep -oE '[0-9]+')
  metrics_str=""
  [ -n "$added" ] && metrics_str+="+${added} "
  [ -n "$deleted" ] && metrics_str+="-${deleted} "

  git_segment=$(printf ' %s%s%s %s%s%s %s%s%s' \
    "$YELLOW" "$branch" "$RESET" \
    "$RED" "$status_str" "$RESET" \
    "$DIM" "$metrics_str" "$RESET")
fi

# --- [character]: no shell exit-code is available in Claude Code's status line, so this
#     approximates the vicmd_symbol using Claude Code's own vim-mode field instead of
#     success_symbol/error_symbol (see summary for details) ---
case "$vim_mode" in
  INSERT) char=$(printf '%s I%s' "$BOLD_GREEN" "$RESET") ;;
  NORMAL) char=$(printf '%s N%s' "$BOLD_GREEN" "$RESET") ;;
  "VISUAL"|"VISUAL LINE") char=$(printf '%s V%s' "$BOLD_GREEN" "$RESET") ;;
  *) char=$(printf '%s #%s' "$BOLD_GREEN" "$RESET") ;;
esac

printf '%s%s%s\n' "$dir_segment" "$git_segment" "$char"
