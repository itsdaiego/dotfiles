#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const BRANCH_CLEANUP_RULE = `
## Local branch cleanup

- Keep local repositories clean. Only active branches and their worktrees stay open.
- After an MR or PR merges, after you finish a task on a branch, and when you start work in a repository with many branches, audit local branches.
- A cleanup covers merged and squash-merged branches, branches whose upstream is gone, backup branches (backup/*, *-backup, *.bak, pre-rebase), and worktrees that belong to those branches.
- Get the facts from Git, not from memory. In Pi, call audit_local_branches. In Claude Code, run the local-branch-cleanup skill script.
- Never delete a branch or remove a worktree without explicit user confirmation. Show the list and the exact commands first, then run only the commands the user confirmed.
- Never delete remote branches, never use git worktree remove --force, and never delete a worktree folder with rm. A worktree with uncommitted files stays until the user decides.
`.trim();

const STALE_DAYS = 30;
const BACKUP_PATTERN = /(^|[/_.-])(backup|bak|old|orig|pre-?rebase|pre-?squash|before-[a-z-]+)([/_.-]|\d|$)/i;

function run(cwd, args) {
  return spawnSync("git", ["-C", cwd, ...args], {
    encoding: "utf8",
    windowsHide: true,
    maxBuffer: 64 * 1024 * 1024,
  });
}

function git(cwd, args) {
  const result = run(cwd, args);
  return result.status === 0 ? result.stdout.trimEnd() : undefined;
}

function gitOk(cwd, args) {
  return run(cwd, args).status === 0;
}

function real(path) {
  try {
    return realpathSync(path);
  } catch {
    return path;
  }
}

function shellQuote(value) {
  return /^[\w./@:+-]+$/.test(value) ? value : `'${value.replaceAll("'", "'\\''")}'`;
}

function resolveBase(top) {
  const originHead = git(top, ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"]);
  if (originHead) return originHead;
  return ["origin/main", "origin/master", "main", "master"].find((ref) =>
    gitOk(top, ["rev-parse", "--verify", "--quiet", ref]),
  );
}

function isAncestor(top, sha, base) {
  return gitOk(top, ["merge-base", "--is-ancestor", sha, base]);
}

// Squash merges leave no ancestry, so compare the branch's net patch against base with git cherry.
function isSquashMerged(top, sha, base) {
  const mergeBase = git(top, ["merge-base", base, sha]);
  if (!mergeBase) return false;
  const tree = git(top, ["rev-parse", `${sha}^{tree}`]);
  if (tree === git(top, ["rev-parse", `${mergeBase}^{tree}`])) return true;
  const probe = git(top, [
    "-c", "user.name=branch-audit",
    "-c", "user.email=branch-audit@localhost",
    "commit-tree", tree, "-p", mergeBase, "-m", "branch-audit squash probe",
  ]);
  if (!probe) return false;
  return (git(top, ["cherry", base, probe]) ?? "").startsWith("-");
}

function listWorktrees(top) {
  const porcelain = git(top, ["worktree", "list", "--porcelain"]) ?? "";
  return porcelain.split("\n\n").filter(Boolean).map((block, index) => {
    const fields = Object.fromEntries(block.split("\n").map((line) => {
      const space = line.indexOf(" ");
      return space < 0 ? [line, true] : [line.slice(0, space), line.slice(space + 1)];
    }));
    const path = fields.worktree;
    const prunable = Boolean(fields.prunable);
    const status = prunable ? undefined : git(path, ["status", "--porcelain"]);
    return {
      path,
      isMain: index === 0,
      head: fields.HEAD,
      branch: typeof fields.branch === "string" ? fields.branch.replace(/^refs\/heads\//, "") : null,
      locked: Boolean(fields.locked),
      prunable,
      dirtyFiles: (status ?? "").split("\n").filter(Boolean).length,
    };
  });
}

function backupOrigin(name) {
  return name
    .replace(/^(backup|bak|old)[/_-]/i, "")
    .replace(/[-_.](before|pre|prior)[-_]?[a-z-]*.*$/i, "")
    .replace(/[-_.](backup|bak|old|orig)([-_.].*|\d.*)?$/i, "")
    .replace(/[-_]\d{4,}.*$/, "");
}

function relatedBranches(origin, branchNames, self) {
  if (branchNames.has(origin)) return [origin];
  const token = origin.split("/").at(-1).toLowerCase();
  return [...branchNames].filter((name) => name !== self && name.toLowerCase().includes(token));
}

function listBranches(top) {
  const format = [
    "%(refname:short)",
    "%(objectname)",
    "%(upstream:short)",
    "%(upstream:track)",
    "%(committerdate:unix)",
  ].join("%00");
  const output = git(top, ["for-each-ref", `--format=${format}`, "refs/heads"]) ?? "";
  return output.split("\n").filter(Boolean).map((line) => {
    const [name, sha, upstream, track, date] = line.split("\0");
    return { name, sha, upstream: upstream || null, gone: track.includes("gone"), date: Number(date) };
  });
}

function classifyBranch(top, branch, context) {
  const { base, defaultLocal, currentTop, worktreeByBranch, branchNames } = context;
  const ageDays = Math.floor((Date.now() / 1000 - branch.date) / 86400);
  const worktree = worktreeByBranch.get(branch.name);
  const checkedOutHere = worktree && real(worktree.path) === real(currentTop);
  const result = {
    name: branch.name,
    sha: branch.sha.slice(0, 10),
    ageDays,
    worktree: worktree && !worktree.isMain ? worktree.path : null,
    checkedOut: Boolean(worktree),
  };

  if (branch.name === defaultLocal) return { ...result, verdict: "keep", reasons: ["default branch"] };

  const ancestor = isAncestor(top, branch.sha, base);
  const merged = ancestor || isSquashMerged(top, branch.sha, base);
  const reasons = [];
  let verdict;
  let force = !ancestor || !isAncestor(top, branch.sha, "HEAD");

  if (merged) {
    verdict = "delete";
    reasons.push(ancestor ? `merged into ${base}` : `squash-merged into ${base}`);
    if (branch.gone) reasons.push("upstream gone");
  } else if (BACKUP_PATTERN.test(branch.name)) {
    const holders = (git(top, ["branch", "--contains", branch.sha, "--format=%(refname:short)"]) ?? "")
      .split("\n")
      .filter((name) => name && name !== branch.name);
    const origin = backupOrigin(branch.name);
    if (holders.length) {
      verdict = "delete";
      force = true;
      reasons.push(`backup; its commits are already in ${holders.slice(0, 3).join(", ")}`);
    } else {
      verdict = "review";
      const related = relatedBranches(origin, branchNames, branch.name);
      reasons.push(related.length
        ? `backup with unique commits; related branches: ${related.slice(0, 3).join(", ")}`
        : `backup with unique commits; no related local branch for ${origin}`);
    }
  } else if (branch.gone) {
    verdict = "review";
    reasons.push("upstream deleted, but changes not found in base (merged with later edits, or abandoned)");
  } else if (!branch.upstream && ageDays > STALE_DAYS) {
    verdict = "review";
    reasons.push(`never pushed, last commit ${ageDays} days ago`);
  } else if (ageDays > STALE_DAYS * 3) {
    verdict = "review";
    reasons.push(`no commits for ${ageDays} days`);
  } else {
    verdict = "keep";
    reasons.push(branch.upstream ? "active" : "active, not pushed yet");
  }

  if (checkedOutHere && verdict === "delete") {
    verdict = "review";
    reasons.push("checked out in the current worktree; switch away before deleting");
  } else if (worktree && !worktree.isMain && verdict === "delete" && worktree.dirtyFiles) {
    verdict = "review";
    reasons.push(`worktree ${worktree.path} has ${worktree.dirtyFiles} uncommitted files`);
  } else if (worktree?.isMain && !checkedOutHere && verdict === "delete") {
    verdict = "review";
    reasons.push(`checked out in the main checkout ${worktree.path}`);
  }

  const commands = [];
  if (verdict === "delete") {
    if (worktree && !worktree.isMain) commands.push(`git worktree remove ${shellQuote(worktree.path)}`);
    commands.push(`git branch ${force ? "-D" : "-d"} ${shellQuote(branch.name)}`);
  }
  return { ...result, verdict, reasons, commands };
}

function classifyDetachedWorktree(top, worktree, base) {
  const result = { path: worktree.path, head: worktree.head?.slice(0, 10) };
  if (worktree.prunable) {
    return { ...result, verdict: "delete", reasons: ["folder is missing"], commands: ["git worktree prune"] };
  }
  if (worktree.locked) return { ...result, verdict: "keep", reasons: ["locked"], commands: [] };
  if (worktree.dirtyFiles) {
    return { ...result, verdict: "review", reasons: [`detached, ${worktree.dirtyFiles} uncommitted files`], commands: [] };
  }
  if (isAncestor(top, worktree.head, base) || isSquashMerged(top, worktree.head, base)) {
    return {
      ...result,
      verdict: "delete",
      reasons: [`detached at a commit already in ${base}`],
      commands: [`git worktree remove ${shellQuote(worktree.path)}`],
    };
  }
  return { ...result, verdict: "review", reasons: ["detached with commits not in base"], commands: [] };
}

export function auditLocalBranches(path, { fetch = false } = {}) {
  const currentTop = git(resolve(path), ["rev-parse", "--show-toplevel"]);
  if (!currentTop) return { kind: "not-repository", path: resolve(path) };

  let fetchError = null;
  if (fetch) {
    const fetched = run(currentTop, ["fetch", "--prune", "--quiet", "origin"]);
    if (fetched.status !== 0) fetchError = fetched.stderr.trim() || "git fetch failed";
  }

  const base = resolveBase(currentTop);
  if (!base) return { kind: "no-base", path: currentTop };

  const worktrees = listWorktrees(currentTop);
  const branches = listBranches(currentTop);
  const context = {
    base,
    defaultLocal: base.replace(/^origin\//, ""),
    currentTop,
    worktreeByBranch: new Map(worktrees.filter((w) => w.branch).map((w) => [w.branch, w])),
    branchNames: new Set(branches.map((b) => b.name)),
  };

  return {
    kind: "repository",
    repository: worktrees[0]?.path ?? currentTop,
    base,
    fetched: fetch && !fetchError,
    fetchError,
    branches: branches.map((branch) => classifyBranch(currentTop, branch, context)),
    detachedWorktrees: worktrees
      .filter((w) => !w.isMain && (!w.branch || w.prunable))
      .map((w) => classifyDetachedWorktree(currentTop, w, base)),
  };
}

function formatGroup(title, items, label) {
  if (!items.length) return [];
  return [
    `${title} (${items.length}):`,
    ...items.flatMap((item) => [
      `  ${label(item)} - ${item.reasons.join("; ")}`,
      ...item.commands.map((command) => `      ${command}`),
    ]),
  ];
}

export function formatAudit(audit) {
  if (audit.kind === "not-repository") return `Not a Git repository: ${audit.path}`;
  if (audit.kind === "no-base") return `No default branch found for ${audit.path}. Set origin/HEAD with: git remote set-head origin --auto`;

  const branchLabel = (b) => {
    if (b.worktree) return `${b.name} [worktree ${b.worktree}]`;
    return b.checkedOut ? `${b.name} [main checkout]` : b.name;
  };
  const worktreeLabel = (w) => `worktree ${w.path} (detached ${w.head})`;
  const pick = (list, verdict) => list.filter((item) => item.verdict === verdict);
  const keep = pick(audit.branches, "keep");
  const commands = [...new Set([...audit.detachedWorktrees, ...audit.branches]
    .filter((item) => item.verdict === "delete")
    .flatMap((item) => item.commands))];

  const lines = [
    `Repository: ${audit.repository} (base ${audit.base})`,
    audit.fetchError
      ? `Fetch failed, results use stale remote refs: ${audit.fetchError}`
      : audit.fetched ? "Fetched and pruned origin." : "Not fetched; run with --fetch for current remote state.",
    "",
    ...formatGroup("Delete candidates", pick(audit.branches, "delete"), branchLabel),
    ...formatGroup("Delete candidate worktrees", pick(audit.detachedWorktrees, "delete"), worktreeLabel),
    ...formatGroup("Review with the user", pick(audit.branches, "review"), branchLabel),
    ...formatGroup("Review worktrees", pick(audit.detachedWorktrees, "review"), worktreeLabel),
    `Keep (${keep.length}): ${keep.map(branchLabel).join(", ") || "none"}`,
  ];
  if (commands.length) {
    lines.push("", "Commands for all delete candidates (run only after user confirmation):", ...commands.map((c) => `  ${c}`));
  }
  return lines.join("\n");
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  const args = process.argv.slice(2);
  const fetch = args.includes("--fetch");
  const json = args.includes("--json");
  const path = args.find((arg) => !arg.startsWith("--")) ?? process.cwd();
  const audit = auditLocalBranches(path, { fetch });
  process.stdout.write(`${json ? JSON.stringify(audit, null, 2) : formatAudit(audit)}\n`);
}
