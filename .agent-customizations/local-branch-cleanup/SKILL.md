---
name: local-branch-cleanup
description: Use to keep a local Git repository clean - after an MR or PR merges, after you finish work on a branch, when a repository has many local branches or worktrees, or when the user asks to clean up, prune, or tidy branches, backup branches, or worktrees. Finds merged and squash-merged branches, branches whose upstream is gone, backup branches, and stale worktrees, then deletes only what the user confirms.
---

# Local branch cleanup

Only active branches, and the worktrees that hold them, stay in a local repository. A branch is no
longer needed when its changes are in the default branch. Backup branches and worktrees go with it.

## When to run

- After an MR or PR merges.
- After you finish a task on a branch, or before you start a new one.
- When `git branch` shows many branches, or `git worktree list` shows worktrees you do not recognize.
- When the user asks to clean up branches, backups, or worktrees.

## Steps

1. Run the audit. It fetches and prunes `origin`, then classifies every local branch and worktree.
   It changes no branch or worktree.

   ```bash
   node ~/.claude/skills/local-branch-cleanup/branches.mjs --fetch [<repo-path>]
   ```

   With no path, it audits the current directory. Add `--json` for machine-readable output.
2. Read the three groups:
   - **Delete candidates**: merged or squash-merged into the base branch, a backup branch whose
     commits another branch already holds, a clean worktree at a commit already in base, or a
     worktree whose folder is missing.
   - **Review with the user**: unique commits that are not in base. Examples are a backup with
     unique commits, a branch whose upstream is gone but whose changes are not in base, a branch
     that is old or was never pushed, and a merged branch in a worktree with uncommitted files.
   - **Keep**: the default branch and active branches.
3. Show Daiego the delete candidates with their exact commands, and the review items with their
   reasons. Ask which ones to delete. Recommend the delete candidates. For each review item, say
   what would be lost.
4. Run only the commands Daiego confirmed, in the order the audit printed them. A worktree must be
   removed before its branch can be deleted.
5. Run the audit again and report what was deleted and what remains, with the repository path.

## Rules

- Never delete a branch or remove a worktree without Daiego's confirmation in this conversation.
  Approval for one cleanup does not cover the next one.
- Never delete remote branches. GitLab deletes the source branch when the MR merges.
- Never use `git worktree remove --force`, and never delete a worktree folder with `rm`. If a
  worktree has uncommitted files, tell Daiego and leave it.
- `git branch -D` is correct for squash-merged branches, because Git cannot see a squash merge as a
  merge. The audit prints `-D` only after it confirms that the changes are in base, or that
  another branch holds the commits.
- If the fetch fails, say so. The results then use stale remote refs, and "upstream gone" can be
  wrong.

## How detection works

- **Merged**: the branch tip is an ancestor of the base branch (`origin/HEAD`, else `origin/main`
  or `origin/master`).
- **Squash-merged**: the script builds a temporary commit with the branch's net diff on top of the
  merge base. It then asks `git cherry` whether base already has an equivalent patch. A branch
  that was squash-merged and then changed again is not detected. It shows as "upstream gone" in
  the review group.
- **Backup branches**: names with `backup`, `bak`, `old`, `orig`, `pre-rebase`, `prerebase`,
  `pre-squash`, or `before-<something>`. A backup is a delete candidate when another local branch
  contains its tip. Otherwise it goes to review with the related branches listed.
