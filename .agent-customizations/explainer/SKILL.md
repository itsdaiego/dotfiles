---
name: explainer
description: Explain how a piece of code works and teach where the answer lives. Use when the user runs /explainer, or asks a code question such as "where does X get set", "how do we fetch Y", "what script does Z", "how does this flow work", or "why does this happen". The answer traces the real call chain, cites the file and line for every claim, shows the code that proves it, shows how to find it again, and, when the code is on a branch or MR that is not checked out, opens a worktree so the user can read it. Do not use it to summarize an MR or PR (use read-mr) or a ticket or thread (use read-issue).
---

# Explainer

Answer a code question with two things: the answer, and where it lives. Every claim cites `path:line` the user can open. Each deeper layer adds detail without repeating the one above it.

## Rules

1. Get every line number from a fresh read (`grep -n`, `git grep -n`, Read, `sed -n 'A,Bp'`) — never from memory or an earlier turn.
2. Cite every claim as `path:line` (relative to the repo root) or `path:start-end`. Can't cite it? Label it **Inferred** and say what would confirm it.
3. Quote only the lines that matter, under a location header, with real line numbers. Mark a cut with `…`.
4. Trace the full chain: from the entry point a user or system triggers, to where the value is used or leaves the process (a header on the wire, a DB write, a network call). If it comes from an env var, secret, config, or DB row, say where and how.
5. Tag each claim: **Verified** (ran a command, read a test, hit an endpoint), **From code** (read-only), or **Inferred** (neither).
6. Stay on the question. Cover nearby behavior — a guard, cache, retry, fallback — only when it changes the answer.
7. Never print a secret's value. Name the variable, key, or path that holds it, not the contents.

## Worktree for the code

The user wants to open the code you explain. Read it from a checkout the user can open, not from `git show` output alone.

Add a worktree when the code is on a ref that the current checkout does not have: an MR or PR branch, another branch, a tag, or a commit. Skip it when the current checkout already holds the code at the right state, or when the question is about the current working tree.

1. Resolve the ref to an exact commit: `git fetch origin <branch>`, then `git rev-parse --short origin/<branch>`. For an MR, take the source branch and head SHA from the MR (`glab api projects/<project>/merge_requests/<iid>`).
2. Reuse a worktree that is already at that commit: `git worktree list`. Otherwise create a detached one, so no branch is checked out twice and nothing can be pushed from it by accident:

   ```bash
   git worktree add --detach <repo-root>/.claude/worktrees/explain-<slug>-<shortsha> <sha>
   ```

   `<slug>` is the MR number (`mr-23059`) or a short branch name. Put it under the repository's `.claude/worktrees/` folder, which is inside the session, so the app can open its files.
3. Read every file and take every line number from that worktree (`git -C <worktree> grep -n`, Read). Cite paths relative to the worktree root, which equals the repo root.
4. Treat it as read-only. Do not edit, commit, or push in it. Do not run anything that writes.
5. Put the worktree in the answer: its absolute path, the branch or MR, and the full head SHA. Link files as markdown links with the path and line so the user can click them.
6. Never remove a worktree yourself. Say the one command that removes it (`git worktree remove <path>`) and leave the choice to the user. Removal that needs `--force` or `rm -rf` needs the user's confirmation first.

If the fetch or the worktree command fails, say so, read the code with `git show <ref>:<path>` instead, and note that no worktree exists.

## Research

1. `git grep -n -e <name> -e <CONSTANT> -e <header-name>` across snake_case, CONSTANT_CASE, kebab-case, and the HTTP header form.
2. Read ~20 lines around each hit to classify it: definition, caller, guard, or test.
3. Walk callers up to a real entry point and down to where the value is used. For Butler code a graph covers, use the graph first (below), then confirm each step with a fresh read.
4. Find locking tests: `git grep -n <name> -- '*test*'`.
5. Find its origin: `git log -S '<identifier>' --format='%h %ad %an %s' --date=short | tail -1` for the introducing commit; `git log -L start,end:path` for how a range changed.
6. Verify read-only at runtime when safe — a local request, a log line, a config check. Never run anything that writes, deletes, or spends money.

## Code graph

A graphify code graph maps which functions, classes, and modules call, import, or reference each other. The graph list, with path prefixes and coverage, is the "Known graphs" table in the `walle-review-risk` skill. Use one when the question is about Butler code inside its coverage (leads, lead chase, voice AI, phone systems, MCP plugins).

Graph paths are relative to the graph's prefix — add the prefix for the repo path. Set `G` to the graph's `graph.json`:

- `graphify explain "<symbol>" --graph "$G"` — a node's callers (`<--`) and callees (`-->`), with their files.
- `graphify path "<from>" "<to>" --graph "$G"` — shortest chain between two symbols.
- `graphify query "<question>" --seed "<symbol>" --graph "$G" --budget 1500` — walks outward from a known symbol; always pass `--seed` (a keyword-only query matches unrelated nodes).
- Ambiguous name → exit code 3 with the matches; retry as `path::symbol` or the full node ID.
- For blast radius, run `walle-review-risk`'s script and report its production and test dependent counts.

The graph is a map, not proof: its line numbers trail the commit in its `BUILT_FROM` file, and the AST extractor misses dynamic dispatch (a method called through a registry or `getattr`), so a node with no callers there may still have callers. Never cite a graph line number — read the file and cite that. Code wins when the two disagree; say the graph is stale.

## Answer format

Use these sections, in order. Skip any that would be empty.

### 1. Short answer
2-4 sentences, with the 1-2 most important `path:line` citations inline.

### 2. Where the answer lives
When you opened a worktree, start with one line: `Worktree: <absolute path> — <branch or MR> at <full head SHA>`.

Then a numbered map of the chain, one line per step, execution order:

```
1. path/to/entry.py:120      — entry point: what triggers it
2. path/to/logic.py:178-186  — decides whether the step happens
3. path/to/source.py:72      — where the value comes from
4. path/to/client.py:203-204 — where it gets applied or sent
```

### 3. Depth
Three layers, each deeper than the last.

- **Level 1: What happens.** One short paragraph per step, numbered to match the map.
- **Level 2: The code.** A code block per step, headed by its location, with real line numbers:

  ```python
  # path/to/client.py:200-204
  200      if self._access_token:
  201          headers["Authorization"] = f"Bearer {self._access_token}"
  202      …
  203      if self._eve_key:
  204          headers[EVE_KEY_HEADER] = self._eve_key
  ```

  Follow each block with 1-2 sentences on what matters.
- **Level 3: Edges and history.** Guards, caches, retries, failure behavior, and security checks, each with `path:line`. Locking tests as `path:line test_name`. The introducing commit's short hash, date, author, and subject; when it clarifies the code, show its key hunk as a `diff` block headed by the file and new-side line numbers:

  ```diff
  # path/to/client.py:203-204 (added in abc1234)
  +        if self._eve_key:
  +            headers[EVE_KEY_HEADER] = self._eve_key
  ```

### 4. Find it yourself
The 2-5 commands that found the answer, most useful first.

### 5. Verified vs. inferred
Only what is not **Verified**, and what would confirm it. Omit this section when everything is Verified.

## Style

Short, plain, active-voice sentences. Define a project term on first use. Identifiers, paths, and commands in backticks. Scale the depth layers to the question — a simple question gets a short Level 1 and thin Levels 2-3.
