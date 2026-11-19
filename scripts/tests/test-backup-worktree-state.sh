#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/worktree-backup-test.XXXXXX")
repo=$test_root/repo
worktree=$test_root/worktree

cleanup() {
  rm -R "$test_root"
}

trap cleanup EXIT HUP INT TERM

git init -q "$repo"
git -C "$repo" config user.name "Worktree Backup Test"
git -C "$repo" config user.email "worktree-backup@example.com"
printf 'base\n' >"$repo/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit -qm "Add base file"
git -C "$repo" worktree add -qb task/worktree-backup "$worktree"

printf 'staged\n' >>"$worktree/tracked.txt"
git -C "$worktree" add tracked.txt
printf 'unstaged\n' >>"$worktree/tracked.txt"
printf 'untracked\n' >"$worktree/untracked.txt"

git -C "$worktree" diff --binary HEAD >"$test_root/expected-tracked.patch"
git -C "$worktree" diff --binary --cached >"$test_root/expected-staged.patch"
git -C "$worktree" diff --binary >"$test_root/expected-unstaged.patch"

backup_dir=$($repo_dir/scripts/backup-worktree-state.sh "$worktree")
canonical_worktree=$(git -C "$worktree" rev-parse --show-toplevel)
common_git_dir=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)

case "$backup_dir" in
  "$common_git_dir"/worktree-backups/*) ;;
  *)
    printf 'Backup was written outside the common Git directory: %s\n' "$backup_dir" >&2
    exit 1
    ;;
esac

grep -Fx "worktree=$canonical_worktree" "$backup_dir/manifest.txt" >/dev/null
grep -Fx "branch=task/worktree-backup" "$backup_dir/manifest.txt" >/dev/null
grep -Fx "head=$(git -C "$worktree" rev-parse HEAD)" "$backup_dir/manifest.txt" >/dev/null
cmp "$test_root/expected-tracked.patch" "$backup_dir/tracked.patch"
cmp "$test_root/expected-staged.patch" "$backup_dir/staged.patch"
cmp "$test_root/expected-unstaged.patch" "$backup_dir/unstaged.patch"
tar -tzf "$backup_dir/untracked.tar.gz" | grep -Fx 'untracked.txt' >/dev/null

grep -Fx 'untracked.txt' "$backup_dir/untracked-files.txt" >/dev/null

printf 'Worktree backup checks passed.\n'
