import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";

export const LARGE_COMMIT_FILE_LIMIT = 25;
export const LARGE_COMMIT_LINE_LIMIT = 1200;

export const COMMIT_DISCIPLINE = `
## Atomic commits

- Make and stage one logical change at a time. Do not mix a feature or bug fix with cleanup, refactors, formatting, dependency updates, generated output for unrelated work, or another task.
- Before staging, inspect the working diff. Stage only the files or hunks that implement the current logical change.
- Each commit must stand alone: its message states the outcome, its diff contains everything required for that outcome, and it leaves the repository in a valid, testable state.
- Run the relevant checks before each commit. Do not include unrelated pre-existing changes just because they are present.
- Prefer small, reviewable commits. Split independent behavior changes into separate commits. Keep required generated files with the source change that generated them.
- Before every git commit, inspect the staged diff and explain its one outcome and verification. In Pi, call assess_atomic_commit immediately before the commit.
- A staged change over ${LARGE_COMMIT_FILE_LIMIT} files or ${LARGE_COMMIT_LINE_LIMIT} changed lines needs explicit user approval before the agent commits it. Explain why it cannot be split first.
- Follow the repository's commit and authorization rules. Never create a commit unless the user has authorized it.
`.trim();

function git(cwd, args) {
  return spawnSync("git", args, {
    cwd,
    encoding: "utf8",
    windowsHide: true,
  });
}

function output(result) {
  return `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
}

function resolveGitCwd(command, fallbackCwd) {
  const match = command.match(/\bgit\s+(?:-C\s+|--work-tree=)([^\s]+)/);
  if (!match?.[1]) return fallbackCwd;
  return match[1].replace(/^['"]|['"]$/g, "");
}

export function isGitCommitCommand(command) {
  return /\bgit\s+(?:(?:-C\s+\S+)|(?:--git-dir|--work-tree)\s+\S+|(?:-[^\s]+)|(?:--[^\s=]+(?:=\S+)?))*\s*commit(?:\s|$)/.test(command);
}

export function hasLargeCommitOverride(command) {
  return /(?:^|\s)ATOMIC_COMMIT_ALLOW_LARGE=1(?:\s|$)/.test(command);
}

export function inspectStagedDiff(cwd, command = "") {
  const gitCwd = resolveGitCwd(command, cwd);
  const repository = git(gitCwd, ["rev-parse", "--is-inside-work-tree"]);
  if (repository.status !== 0 || repository.stdout.trim() !== "true") {
    return { kind: "not-repository", cwd: gitCwd };
  }

  const hasChanges = git(gitCwd, ["diff", "--cached", "--quiet"]);
  if (hasChanges.status === 0) {
    return { kind: "empty", cwd: gitCwd };
  }

  const names = git(gitCwd, ["diff", "--cached", "--name-only"]);
  const files = names.stdout.split("\n").filter(Boolean);
  const numstat = git(gitCwd, ["diff", "--cached", "--numstat"]);
  const changedLines = numstat.stdout.split("\n").filter(Boolean).reduce((total, line) => {
    const [added, removed] = line.split("\t");
    return total + (Number(added) || 0) + (Number(removed) || 0);
  }, 0);
  const whitespace = git(gitCwd, ["diff", "--cached", "--check"]);
  const raw = git(gitCwd, ["diff", "--cached", "--raw", "--no-renames"]);
  const fingerprint = createHash("sha256").update(raw.stdout).digest("hex");

  return {
    kind: "changes",
    cwd: gitCwd,
    files,
    changedLines,
    fingerprint,
    whitespaceErrors: whitespace.status === 0 ? "" : output(whitespace),
    isLarge: files.length > LARGE_COMMIT_FILE_LIMIT || changedLines > LARGE_COMMIT_LINE_LIMIT,
  };
}

export function commitBlockReason(cwd, command) {
  const staged = inspectStagedDiff(cwd, command);
  if (staged.kind !== "changes") return undefined;
  if (staged.whitespaceErrors) {
    return `The staged diff has whitespace errors:\n${staged.whitespaceErrors}`;
  }
  if (staged.isLarge && !hasLargeCommitOverride(command)) {
    return `The staged diff changes ${staged.files.length} files and ${staged.changedLines} lines. Split it into smaller commits, or ask the user to approve an inseparable large commit. After approval, rerun the commit with ATOMIC_COMMIT_ALLOW_LARGE=1.`;
  }
  return undefined;
}
