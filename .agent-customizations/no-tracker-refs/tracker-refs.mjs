import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, extname, basename, resolve } from "node:path";

// Linear team keys. GPT is left out because it collides with model names (GPT-5).
export const TEAM_KEYS = [
  "AGENT", "ATLAS", "AUDIT", "CASE", "COMM", "DATAPLA", "DATP", "EASE", "EVE",
  "GRO", "INFRSEC", "INTAKE", "MED", "POD", "QA", "SCR", "STAND",
];

const PROSE_EXTENSIONS = new Set([".md", ".mdx", ".markdown", ".mdc", ".txt", ".rst"]);
const SKIPPED_PATH = /(^|\/)(__snapshots__|CHANGELOG[^/]*$|[^/]*\.lock$|package-lock\.json$|pnpm-lock\.yaml$)/;

export const TRACKER_REF_RULE = `
## No tracker references in code

- Do not put Linear ticket IDs (for example INTAKE-405), branch names, MR numbers (!20908), or GitLab/Linear URLs in source code, comments, docstrings, or config descriptions.
- Explain the behavior and the reason in the comment itself. Ticket and MR links belong in the commit message and the MR description.
- Markdown docs are exempt. Hooks block edits and commits that add new references to code files.
`.trim();

const TICKET_PATTERN = new RegExp(`\\b(?:${TEAM_KEYS.join("|")})-\\d+\\b`, "g");
const MR_PATTERN = /(?<![\w!=])![0-9]{4,}\b/g;
const URL_PATTERN = /(?:\/-\/merge_requests\/\d+|\/-\/issues\/\d+|linear\.app\/[\w\-/]+)/g;

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function isCheckedPath(path) {
  if (!path) return false;
  if (PROSE_EXTENSIONS.has(extname(path).toLowerCase())) return false;
  if (/^(README|LICENSE|NOTICE)/i.test(basename(path))) return false;
  return !SKIPPED_PATH.test(path);
}

export function currentBranch(cwd) {
  const result = spawnSync("git", ["branch", "--show-current"], { cwd, encoding: "utf8", windowsHide: true });
  return result.status === 0 ? result.stdout.trim() : "";
}

function branchPatterns(branch) {
  if (!branch) return [];
  const patterns = [];
  if (branch.length >= 8 && branch !== "master" && branch !== "main") {
    patterns.push(new RegExp(escapeRegExp(branch), "g"));
  }
  for (const match of branch.matchAll(/(?:^|[/_-])([a-z]{2,10}-\d+)(?=$|[/_-])/gi)) {
    patterns.push(new RegExp(`\\b${escapeRegExp(match[1])}\\b`, "gi"));
  }
  return patterns;
}

export function findRefs(text, branch = "") {
  if (!text) return [];
  const found = new Map();
  for (const pattern of [TICKET_PATTERN, MR_PATTERN, URL_PATTERN, ...branchPatterns(branch)]) {
    for (const match of text.matchAll(pattern)) {
      if (!found.has(match[0].toLowerCase())) found.set(match[0].toLowerCase(), match[0]);
    }
  }
  return [...found.values()];
}

function withoutExisting(refs, before, branch) {
  const existing = new Set(findRefs(before, branch).map((ref) => ref.toLowerCase()));
  return refs.filter((ref) => !existing.has(ref.toLowerCase()));
}

export function newRefs(before, after, branch = "") {
  return withoutExisting(findRefs(after, branch), before, branch);
}

export function readFileOrEmpty(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

export function editBlockReason(path, before, after) {
  if (!isCheckedPath(path)) return undefined;
  const refs = newRefs(before, after, currentBranch(dirname(path)));
  if (refs.length === 0) return undefined;
  return `This change adds tracker references to ${path}: ${refs.join(", ")}. Remove them. Describe the behavior and the reason in plain words, and put ticket or MR links in the commit message or MR description.`;
}

export function isGitCommitCommand(command) {
  return /\bgit\s+(?:(?:-C\s+\S+)|(?:--git-dir|--work-tree)\s+\S+|(?:-[^\s]+)|(?:--[^\s=]+(?:=\S+)?))*\s*commit(?:\s|$)/.test(command);
}

function resolveGitCwd(command, fallbackCwd) {
  const match = command.match(/\bgit\s+(?:-C\s+|--work-tree=)([^\s]+)/);
  return match?.[1] ? match[1].replace(/^['"]|['"]$/g, "") : fallbackCwd;
}

function git(cwd, args) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8", maxBuffer: 64 * 1024 * 1024, windowsHide: true });
  return result.status === 0 ? result.stdout : undefined;
}

function parseDiff(diffText) {
  const files = new Map();
  let file;
  let lineNumber = 0;
  for (const line of diffText.split("\n")) {
    if (line.startsWith("+++ ")) {
      file = line === "+++ /dev/null" ? undefined : line.slice(6);
      if (file && !files.has(file)) files.set(file, { added: [], removed: "" });
      continue;
    }
    if (line.startsWith("--- ")) continue;
    const hunk = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
    if (hunk) {
      lineNumber = Number(hunk[1]);
      continue;
    }
    if (!file) continue;
    const entry = files.get(file);
    if (line.startsWith("+")) {
      entry.added.push({ lineNumber, text: line.slice(1) });
      lineNumber += 1;
    } else if (line.startsWith("-")) {
      entry.removed += `${line.slice(1)}\n`;
    }
  }
  return files;
}

function stagedDiff(cwd, base) {
  const args = ["diff", "--cached", "--unified=0", "--no-color", "--no-ext-diff"];
  if (base) args.push(base);
  const text = git(cwd, args);
  return text === undefined ? undefined : parseDiff(text);
}

// A merge or cherry-pick stages other people's work. Their commits are theirs to fix, so the
// check covers only the conflict resolution and the commits the local git user authored.
function incomingHeads(cwd) {
  const heads = [];
  for (const ref of ["MERGE_HEAD", "CHERRY_PICK_HEAD"]) {
    const path = git(cwd, ["rev-parse", "--git-path", ref])?.trim();
    const shas = path ? readFileOrEmpty(resolve(cwd, path)).split(/\s+/).filter(Boolean) : [];
    for (const sha of shas) heads.push({ ref, sha });
  }
  return heads;
}

function ownedAddedLines(cwd, heads, ownerEmail) {
  const owned = new Set();
  for (const { ref, sha } of heads) {
    const range = ref === "MERGE_HEAD" ? [`HEAD..${sha}`] : ["-1", sha];
    const log = git(cwd, [
      "log", "--no-merges", "--no-color", "--unified=0", "--format=", "-p",
      `--author=<${escapeRegExp(ownerEmail)}>`, ...range,
    ]);
    if (!log) continue;
    for (const { added } of parseDiff(log).values()) {
      for (const { text } of added) owned.add(text);
    }
  }
  return owned;
}

function lineKeys(files) {
  const keys = new Set();
  for (const [path, { added }] of files) {
    for (const { lineNumber } of added) keys.add(`${path}:${lineNumber}`);
  }
  return keys;
}

export function stagedRefFindings(cwd) {
  const files = stagedDiff(cwd);
  if (!files) return [];
  const branch = currentBranch(cwd);

  const heads = incomingHeads(cwd);
  const ownerEmail = git(cwd, ["config", "user.email"])?.trim();
  // Without an owner identity the check falls back to every staged line.
  const scoped = heads.length > 0 && Boolean(ownerEmail);
  const notInHeads = scoped ? heads.map(({ sha }) => lineKeys(stagedDiff(cwd, sha) ?? new Map())) : [];
  const owned = scoped ? ownedAddedLines(cwd, heads, ownerEmail) : new Set();

  const findings = [];
  for (const [path, { added, removed }] of files) {
    if (!isCheckedPath(path)) continue;
    for (const { lineNumber: number, text } of added) {
      if (scoped) {
        const key = `${path}:${number}`;
        const fromResolution = notInHeads.every((keys) => keys.has(key));
        if (!fromResolution && !owned.has(text)) continue;
      }
      const refs = withoutExisting(findRefs(text, branch), removed, branch);
      if (refs.length) findings.push(`${path}:${number}: ${refs.join(", ")}`);
    }
  }
  return findings;
}

export function commitBlockReason(cwd, command) {
  const findings = stagedRefFindings(resolveGitCwd(command, cwd));
  if (findings.length === 0) return undefined;
  return `The staged diff adds tracker references (ticket IDs, branch names, MR numbers or links) to code:\n${findings.join("\n")}\nRemove them from the code, restage, and commit again. Ticket and MR links belong in the commit message.`;
}
