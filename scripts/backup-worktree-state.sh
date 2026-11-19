#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s <worktree-path>\n' "$0" >&2
  exit 2
fi

worktree=$(git -C "$1" rev-parse --show-toplevel)
branch=$(git -C "$worktree" symbolic-ref --quiet --short HEAD) || {
  printf 'Refusing to back up a detached worktree: %s\n' "$worktree" >&2
  exit 1
}
head=$(git -C "$worktree" rev-parse HEAD)
common_git_dir=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
safe_branch=$(printf '%s' "$branch" | tr '/[:space:]' '--')
backup_dir=$common_git_dir/worktree-backups/$timestamp-$safe_branch-$$

mkdir -p "$backup_dir"

{
  printf 'worktree=%s\n' "$worktree"
  printf 'branch=%s\n' "$branch"
  printf 'head=%s\n' "$head"
  printf 'created_at=%s\n' "$timestamp"
} >"$backup_dir/manifest.txt"

git -C "$worktree" diff --binary HEAD >"$backup_dir/tracked.patch"
git -C "$worktree" diff --binary --cached >"$backup_dir/staged.patch"
git -C "$worktree" diff --binary >"$backup_dir/unstaged.patch"
git -C "$worktree" ls-files --others --exclude-standard >"$backup_dir/untracked-files.txt"
git -C "$worktree" ls-files --others --exclude-standard -z >"$backup_dir/untracked-files.bin"

python3 - "$worktree" "$backup_dir/untracked-files.bin" "$backup_dir/untracked.tar.gz" <<'PY'
import os
import sys
import tarfile

worktree, list_path, archive_path = sys.argv[1:]
with open(list_path, "rb") as paths_file:
    paths = [path for path in paths_file.read().split(b"\0") if path]

with tarfile.open(archive_path, "w:gz") as archive:
    for raw_path in paths:
        relative_path = os.fsdecode(raw_path)
        archive.add(
            os.path.join(worktree, relative_path),
            arcname=relative_path,
            recursive=False,
        )
PY

rm -f "$backup_dir/untracked-files.bin"
printf '%s\n' "$backup_dir"
