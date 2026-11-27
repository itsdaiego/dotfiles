---
name: ask-away
description: Grill a merge request, pull request, branch, or feature one short question at a time to find gaps in the implementation. Use when the user runs /ask-away, says "ask away", "hit me", "grill me on this MR", "find the gaps", or asks for review questions about a change. Each question quotes the code it is about and probes a critical path, trade-off, or failure mode. Do not use it to quiz the user's knowledge, to summarize a change (use read-mr), or to write a full review report (use review-mr).
---

# Ask away

Find what a change gets wrong or leaves out by asking about it, one sharp question at a time. The questions test the implementation, not the person. The user answers, you check the answer against the code, and the conversation narrows in on real gaps.

## Format rules

- Ask exactly one question per message.
- Every question quotes the code it is about. Use a short excerpt from the change, with a source header that gives the path, the line range, and the exact commit.
- Keep the text around the code to five lines or fewer: a few short bullets that set up a concrete scenario and end with the question.
- Number the questions (`Q1`, `Q2`, …) and give each a short title.
- Ask about the most critical code first. Skip style, naming, and minor nits.

Use this shape:

````markdown
**Q1: <short title>**

**Source:** `path/to/file.py:120-131` (<MR or branch> at `<short sha>`)
```python
<the lines the question is about>
```

- <the scenario, in one line>
- <what happens in the code, in one line>
- <the question>
````

## What to ask about

Rank the candidate questions by how much harm the gap could cause, then ask the worst one first. Look for:

- **Design decisions.** Why two paths, a thread, a queue, a cache, or a new table? What would break with the simpler option?
- **Idempotency and duplicates.** Can a retry, a race, or two parallel paths write twice, create a second record, or charge twice?
- **Retries.** Is every retryable failure retried, and is every non-retryable failure kept from being retried? Who retries after a crash?
- **Timeouts and deadlines.** Is the deadline a hard limit or only a per-request timeout? What is still running after it?
- **Failure and partial failure.** What state is left after each step fails? Is the user or the system told?
- **Persistence and transactions.** Is related state committed together? Is anything written outside a transaction that should be inside one?
- **Locks and external calls.** Does a row lock, a database connection, or a transaction stay open while waiting on an external service?
- **Data correctness.** Can the change write to the wrong record, the wrong tenant, or overwrite newer data?
- **Observability.** Will anyone know when this fails, drops data, or falls back? Is there a log, metric, or alert for it?
- **Rollout.** What does the feature flag actually turn off? Does turning it off leave stranded state behind?
- **Tests.** Which of the failure modes above has no test?

## Workflow

1. Identify the change from the request: an MR or PR link, a number, a branch, or the current conversation. If nothing identifies it, ask for the one reference you need.
2. Open a read-only worktree at the exact head, following the `explainer` skill's worktree rules, so every quote and line number comes from code the user can open. Reuse an existing worktree at the same commit.
3. Read the description and the full diff before the first question. Follow the changed code into its callers and into any external service it talks to, far enough to know what happens when a call fails.
4. For a Butler change, run the `review-risk` assessment before the first question. Add its result to the first message as one line: the risk, the review-attention label, and the reason.
5. Ask `Q1`.
6. After each answer, reply with:
   - **Feedback:** one to three bullets on what the answer gets right and what the code shows differently, with `path:line` citations.
   - The next question, in the same format.
7. When the user goes off on a side question, answer it directly and briefly (one line when they ask for one line), then continue with the next numbered question when they ask to resume.
8. When the user asks for a summary, list the gaps found so far, each with its location and whether the conversation confirmed it, ruled it out, or left it open.

## Rules

- Read the code before every claim. Get every line number from a fresh read, never from memory or from a code graph.
- Mark anything you did not verify as inferred, and say what would confirm it.
- A gap is a concrete scenario that the code handles badly. Do not ask about a risk the code already handles. Cite the line that handles it if it comes up.
- Never comment on, approve, or edit the MR. This skill is read-only.
- Write the prose in plain, short sentences.
