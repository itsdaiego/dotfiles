---
name: change-location-reporting
description: Use before reporting any change you made - file edits, commits, pushes, generated files, or config changes - so the report names the exact worktree path and branch. Also use when the user asks where a change was made, which branch or worktree was used, or whether the main checkout was touched.
---

# Change location reporting

Every report of a change names where the change was made. The reader must never have to guess
whether you worked in their main checkout, a separate worktree, or a detached HEAD.

## Steps

1. Collect every location you changed in this task: each Git worktree, and each file outside Git.
2. Get the facts from Git, not from memory. Run the script with each location:

   ```bash
   node ~/.claude/skills/change-location-reporting/location.mjs <path> [<path>...]
   ```

   With no path, it reports the current directory. For each path, it prints the worktree, the branch or
   detached HEAD, the upstream, whether it is the main checkout, and the uncommitted file count.
3. In the report, give for each location:
   - The absolute worktree path, and whether it is the main checkout or a separate worktree.
   - The branch. On a detached HEAD, give the commit and the remote branch you pushed to, if any.
   - The changes you made there: files, commits, or pushes.
4. When you worked in a separate worktree, say whether the main checkout changed. If it did not
   change, say that too.
5. For a file outside a Git repository, give its absolute path.

## Example

> Worktree `/private/tmp/butler-mr-20644-fix` (separate worktree, detached HEAD at `624099df65`),
> pushed to `origin/dyego/intake-429-...`. The main checkout `~/Documents/code-stuff/eve/butler`
> did not change: it is still on `dyego/intake-429-...` at `12dc402a7e`.
