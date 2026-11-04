---
name: explainer
description: Explain how a piece of code works and teach where the answer lives. Use when the user runs /explainer, or asks a code question such as "where does X get set", "how do we fetch Y", "what script does Z", "how does this flow work", or "why does this happen". The answer traces the real call chain, cites the file and line for every claim, shows the code that proves it, and shows how to find it again. Do not use it to summarize an MR or PR (use read-mr) or a ticket or thread (use read-issue).
---

# Explainer

Answer a question about code so the user learns two things: the answer itself, and where in the code the answer lives. Each claim points to a file and line the user can open. Each deeper layer adds detail without repeating the one above it.

## Rules

1. **Read the code before you answer.** Get every line number from a fresh read: `grep -n`, `git grep -n`, the Read tool, or `sed -n 'A,Bp'`. Never take a line number from memory or from an earlier turn, because the file may have changed since.
2. **Cite every claim as `path:line`.** Paths are relative to the repository root, so they stay clickable. A range is `path:start-end`. If you cannot cite a claim, label it **Inferred** and say what would confirm it.
3. **Show the proof.** For each step in the chain, quote the few lines that matter, in a code block headed by its location. Give real line numbers in the margin. Cut unrelated lines and mark the cut with `…`.
4. **Follow the chain to both ends.** Start at the entry point a user or system triggers. End where the value is used or leaves the process, such as a header on the wire, a DB write, or a network call. When the value comes from somewhere else, such as an env var, a secret store, config, or a DB row, say where that is and how it gets there.
5. **Separate what you checked from what you assumed.** Running a command, reading a test, or hitting an endpoint counts as **Verified**. Reading the code alone counts as **From code**. Anything else is **Inferred**.
6. **Stay inside the question.** Cover nearby behavior only when it changes the answer, such as a guard that skips the step, a cache, a retry, or a fallback.
7. **Never print secret values.** Show the variable, key name, or path that holds a secret, and never its contents.

## How to research

1. Search for the identifiers in the question: `git grep -n -e <name> -e <CONSTANT> -e <header-name>`. Try the different spellings: snake_case, CONSTANT_CASE, kebab-case, and the HTTP header form.
2. For each hit, read about 20 lines around it to learn its role: definition, caller, guard, or test.
3. Walk up the callers until you reach a real entry point. Walk down until the value is used. For Butler code that a code graph covers, use the graph to find the callers and the path between two symbols quickly (see "Use the code graph" below). Then confirm each step with a fresh read.
4. Find the tests that lock the behavior in: `git grep -n <name> -- '*test*'`.
5. Find where the code came from: `git log -S '<identifier>' --format='%h %ad %an %s' --date=short | tail -1` gives the commit that introduced it, and `git log -L start,end:path` shows how a range changed.
6. When it is safe and read-only, verify at runtime: a local request, a log line, or a check that a config value is set. Do not run anything that writes, deletes, or spends money.

## Use the code graph

A graphify code graph maps which functions, classes, and modules call, import, or reference each other. The list of graphs, with their path prefixes and the folders they cover, is the "Known graphs" table in the `walle-review-risk` skill. Use a graph when the question is about Butler code inside that coverage, such as leads, lead chase, voice AI, phone systems, or MCP plugins.

Graph paths are relative to the graph's prefix. Add the prefix to get a repository path. Set `G` to the graph's `graph.json`:

- `graphify explain "<symbol>" --graph "$G"` lists a node's callers (`<--`) and callees (`-->`), with their files.
- `graphify path "<from>" "<to>" --graph "$G"` gives the shortest chain between two symbols, such as an entry point and the place a value is used.
- `graphify query "<question>" --seed "<symbol>" --graph "$G" --budget 1500` walks outward from a known symbol. Pass `--seed`, because keyword-only queries match unrelated nodes.
- When a name is ambiguous, the command exits with code 3 and lists the matches. Retry with `path::symbol` or the full node ID.
- To show how far a change to the code would reach, run the `walle-review-risk` blast-radius script and report its production and test dependent counts.

The graph is a map, not proof. Its line numbers come from the commit in its `BUILT_FROM` file, and the AST extractor misses dynamic dispatch, such as a method called through a registry or `getattr`. So a node with no callers in the graph may still have callers. Never cite a line number from the graph. Read the file and cite that line. When the graph and the code disagree, trust the code and say the graph is stale.

## Answer format

Use these sections in this order. Leave out any section that would be empty.

### 1. Short answer
Two to four sentences that answer the question, with the one or two most important `path:line` citations inline.

### 2. Where the answer lives
A numbered map of the chain, one line per step, in execution order:

```
1. path/to/entry.py:120      — entry point: what triggers it
2. path/to/logic.py:178-186  — decides whether the step happens
3. path/to/source.py:72      — where the value comes from
4. path/to/client.py:203-204 — where it gets applied or sent
```

Keep each role short, but write it as plain words the user can understand.

### 3. Depth
Three layers, each going deeper than the last.

- **Level 1: What happens.** Explain the flow in plain words, one short paragraph per step in the map. Name the step number for each.
- **Level 2: The code.** For each step, a code block headed by its location, with real line numbers:

  ```python
  # path/to/client.py:200-204
  200      if self._access_token:
  201          headers["Authorization"] = f"Bearer {self._access_token}"
  202      …
  203      if self._eve_key:
  204          headers[EVE_KEY_HEADER] = self._eve_key
  ```

  Follow each block with one or two sentences about the lines that matter.
- **Level 3: Edges and history.** Cover the guards, caches, retries, failure behavior, and security checks, each with `path:line`. List the tests that cover the behavior as `path:line test_name`. Name the commit that introduced the behavior, with its short hash, date, author, and subject. When that commit helps explain the code, show its key hunk in a `diff` block headed by the file and the new-side line numbers:

  ```diff
  # path/to/client.py:203-204 (added in abc1234)
  +        if self._eve_key:
  +            headers[EVE_KEY_HEADER] = self._eve_key
  ```

### 4. Find it yourself
The two to five commands that found the answer, so the user can repeat them on another question. Put the most useful command first.

### 5. Verified vs. inferred
List anything that is not **Verified**, and say what would confirm it. Leave this section out when everything is verified.

## Style

- Write short, plain sentences in active voice.
- Define a project term the first time you use it.
- Put identifiers, paths, and commands in backticks.
- Use the depth layers to match the question: answer a simple question in a short Level 1 and keep Levels 2 and 3 brief.
