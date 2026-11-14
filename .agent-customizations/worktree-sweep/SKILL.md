---
name: worktree-sweep
description: Quickly find Git worktrees that can be removed to reclaim disk space. Use when someone asks to sweep, clean, prune, remove, or reclaim space from worktrees, or invokes /worktree-sweep.
---

# Worktree sweep

Use this for a quick, disk-space-focused worktree cleanup. Do not review code, investigate every branch, or scan the whole computer.

## Sweep

1. Work from each Git repository the user names. If the current directory is not a repository, inspect its immediate child repositories only when that is the clear workspace context.
2. For each repository, fetch and prune `origin`, then list its registered worktrees with `git worktree list --porcelain`.
3. For every non-main worktree, collect only:
   - its path and branch or detached HEAD;
   - whether `git status --porcelain` is empty;
   - its approximate size from `du -sk`;
   - whether its exact HEAD is on `origin/*` or is already contained in the remote default branch.
4. Classify the results without reading diffs:
   - **Remote-backed and clean:** recommend removal. The worktree has no uncommitted files, and its commit is available from `origin`.
   - **Clean, local-only branch:** say that removing the checkout preserves its local branch but does not leave a remote backup. Include it only as an opt-in cleanup candidate.
   - **Dirty:** do not recommend removal. Report the count of changed files and leave it alone.
   - **Missing or stale registration:** report it separately. Do not prune it unless the user confirms the exact command.
5. Report the number of worktrees checked, each category's estimated reclaimable space, and the exact `git worktree remove <path>` commands for candidates. Mention that actual recovered disk space can differ from `du` because Git objects are shared.

## Safety rules

- Never use `git worktree remove --force` or `rm -rf`.
- Never remove a dirty worktree.
- Never delete branches as part of a sweep. Offer branch cleanup separately with `local-branch-cleanup`.
- Do not remove any worktree until the user confirms the displayed commands in this conversation. Run only the confirmed commands.
- After removal, run the same lightweight audit again and report what was removed and what remains.
