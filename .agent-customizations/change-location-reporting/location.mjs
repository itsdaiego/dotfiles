#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const CHANGE_LOCATION_RULE = `
## Change location

- Every time you report a change (an edit, a commit, a push, generated output, or a config change), name where you made it.
- In a Git repository, give the absolute worktree path and the branch. On a detached HEAD, give the commit and the remote branch you pushed to, if any.
- Say whether the location is the user's main checkout or a separate worktree. When you worked in a separate worktree, say whether the main checkout changed.
- For a file outside a Git repository, give its absolute path.
- When changes span several locations, list each location with its changes.
- Before you report, get the facts from Git, not from memory. In Pi, call describe_change_location. In Claude Code, run the change-location-reporting skill script.
`.trim();

function git(cwd, args) {
  const result = spawnSync("git", ["-C", cwd, ...args], { encoding: "utf8", windowsHide: true });
  return result.status === 0 ? result.stdout.trim() : undefined;
}

function mainWorktreePath(cwd) {
  const list = git(cwd, ["worktree", "list", "--porcelain"]);
  const first = list?.split("\n").find((line) => line.startsWith("worktree "));
  return first?.slice("worktree ".length);
}

export function describeChangeLocation(path) {
  const target = resolve(path);
  const top = git(target, ["rev-parse", "--show-toplevel"]);
  if (!top) {
    return { kind: "not-repository", path: target };
  }
  const branch = git(top, ["symbolic-ref", "--quiet", "--short", "HEAD"]);
  const mainPath = mainWorktreePath(top);
  const real = (p) => (p ? realpathSync(p) : p);
  return {
    kind: "repository",
    worktree: top,
    isMainCheckout: real(top) === real(mainPath),
    mainCheckout: mainPath,
    branch: branch ?? null,
    head: git(top, ["rev-parse", "--short", "HEAD"]),
    upstream: git(top, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]) ?? null,
    dirtyFiles: (git(top, ["status", "--porcelain"]) ?? "").split("\n").filter(Boolean).length,
  };
}

export function formatChangeLocation(location) {
  if (location.kind === "not-repository") {
    return `Not a Git repository: ${location.path}`;
  }
  const ref = location.branch ? `branch ${location.branch}` : `detached HEAD at ${location.head}`;
  const kind = location.isMainCheckout ? "main checkout" : `separate worktree; main checkout is ${location.mainCheckout}`;
  const upstream = location.upstream ? `, tracking ${location.upstream}` : "";
  return [
    `Worktree: ${location.worktree} (${kind})`,
    `Ref: ${ref} (HEAD ${location.head})${upstream}`,
    `Uncommitted files: ${location.dirtyFiles}`,
  ].join("\n");
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  const paths = process.argv.slice(2);
  const targets = paths.length ? paths : [process.cwd()];
  process.stdout.write(`${targets.map((path) => formatChangeLocation(describeChangeLocation(path))).join("\n\n")}\n`);
}
