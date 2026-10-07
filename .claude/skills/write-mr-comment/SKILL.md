---
name: write-mr-comment
description: Use when writing a review comment on someone else's GitLab MR or GitHub PR — an inline diff comment, a thread reply, or a general review note. Produces a comment the author can act on fast, opening with a one-line TL;DR of the problem, then the proposed fix, then the key facts that back it up (paths, lines, inputs, error text, evidence). Also use when the user says a review comment is too long, too vague, unclear, harsh, or "reads like an LLM wrote it", or when turning review findings (e.g. from review-mr or code-review) into comments to post.
---

# Writing MR review comments

A review comment has one reader: the MR author, usually mid-task, who wants to know three things fast:

1. **What is wrong?** (the TL;DR of the problem)
2. **What should I do?** (the proposed fix)
3. **Why should I believe you?** (the key facts)

If the author has to re-read the comment or open three files to figure out what you mean, the comment failed.

Companion skills: `write-mr` writes MR descriptions, `read-mr` digests an MR, `review-mr` finds the issues. This skill turns an issue into a comment.

Common failures this skill fixes:

- **Buried point.** The comment opens with "I was looking at this and noticed that when..." and the actual problem shows up in sentence four.
- **Problem with no fix.** "This looks off" or "Not sure about this" — the author has to guess what you want.
- **Fix with no reason.** "Use `get_or_create` here" — the author cannot tell if it is a bug, a preference, or a nit.
- **Cryptic TL;DR.** "**blocking:** stale ctx on re-entry breaks the dedupe path" — the author has to guess what "ctx", "re-entry", and "the dedupe path" mean before they even know what is wrong.
- **Vague trigger.** "This might break in some cases" instead of naming the input or state that breaks it.
- **No severity.** The author cannot tell a blocker from a nit, so they either argue every comment or ignore all of them.
- **Essay comments.** Five paragraphs for a one-line fix. Or a wall of identifiers with no explanation.
- **Harsh or preachy tone.** "Why would you do this?" or lecturing about best practices.

## Workflow

1. **Gather facts first.** Read the diff hunk, the surrounding code, and anything the comment depends on (callers, tests, config, the MR description). Confirm the problem is real: trace the input, run the test, or check the code path. Never comment on something you have not verified — if you are not sure, write it as a question.
2. **Pick the anchor.** Inline comment on the exact line when the issue lives in one place. General MR note when it spans many files or is about the overall approach. Reply in the existing thread when one already covers it.
3. **Fill the template below.** Drop a section only when it truly has nothing to say. Never drop a fact to make the text shorter.
4. **Run the self-check** at the bottom.
5. **Do not post without asking.** Show the draft(s) to the user. Post only after the user confirms, using `glab mr note <iid> -m ...`, `glab api` for inline discussions, or the GitLab MCP (`save_note`, `save_merge_request_review`). Post exactly what the user approved.

## Template

```markdown
**<label>:** <One-sentence TL;DR of the problem: what goes wrong, and when.>

**Fix:** <What to change, concretely. One sentence, or a suggestion block /
short code snippet when the change is small.>

<Key facts, as 1–4 bullets. Only what the author needs to believe the problem
and apply the fix:>
- <Trigger: the input, state, or path that hits it, e.g. "`org.settings` is `None` for orgs created before 2025-03">
- <Effect: what the user/caller sees, with exact error text if any>
- <Evidence: file:line, the caller, a failing test, a log line, a query result>
- <Trade-off or alternative, if the fix has one>
```

### The label + TL;DR line matters most

The first line (the label and the one-sentence summary) is the part of the comment that must be clearest. Many authors read only this line, in a notification, in the MR overview, or in a list of open threads. A `blocking` line especially has to stand on its own: the author must understand what breaks, when, and for whom without reading the bullets, opening a file, or guessing what you meant.

Rules for this line:

- **Plain words, full sentence.** Write it as a normal English sentence with a subject and a verb. No shorthand, no abbreviations ("ctx", "cfg", "dup", "w/o"), no arrows, no fragments.
- **No terms the reader has to guess.** Do not lean on a name you made up while reviewing ("the dedupe path", "the second loop", "the race"). Do not use an internal identifier alone as if it explained itself. If you name a function, field, or table, also say in plain words what it does or what goes wrong with it.
- **Say the concrete effect.** Name what actually happens: a crash with which error, wrong data written where, a request that hangs, a user who sees what. "Is broken", "has issues", or "is wrong" is not an effect.
- **Say the trigger.** Name when it happens: which input, state, or path. A reader should be able to reproduce it from this line alone.
- **One issue.** If the line needs "and" to join two problems, split the comment.
- **Test it.** Read the line as if you were a teammate who has not seen the review and only knows the codebase. If they would need to ask "what do you mean by X?", rewrite it.

**Cryptic:**

> **blocking:** stale ctx on re-entry breaks the dedupe path.

**Clear:**

> **blocking:** When a webhook is retried, `handle_intake_event` reuses the request context from the first attempt, so the duplicate check compares against the old event ID and the same intake gets created twice.

### Labels

Start every comment with one label so the author knows how much it matters:

| Label | Meaning | Merge? |
|---|---|---|
| `blocking` | Bug, data loss, security issue, broken contract | Must fix before merge |
| `suggestion` | Clear improvement, but the MR works without it | Author decides |
| `question` | You are not sure; you need the author's context | Needs an answer |
| `nit` | Style, naming, tiny cleanup | Ignore freely |
| `follow-up` | Real issue, out of scope for this MR | Ticket it, do not block |

For a `question`, replace **Fix:** with what you think the answer might be or what you would check: "**If so:** ...". For a `nit`, one line is usually enough — skip the facts.

### Suggestion blocks

When the fix is a small, exact change on the commented lines, use a suggestion block so the author can apply it in one click:

````markdown
```suggestion
if org.settings is None:
    return DEFAULT_SETTINGS
```
````

On GitLab, a multi-line suggestion uses `` ```suggestion:-0+2 `` (lines above/below the anchor). Only use suggestion blocks on inline comments.

## Examples

**Bad:**

> I was looking through this function and I think there might be an issue with how settings are handled. In some cases it seems like the settings could be missing, which might cause problems down the line. Maybe we should think about handling that? Not sure, just a thought.

**Good:**

> **blocking:** `load_intake_config` crashes with `AttributeError: 'NoneType' object has no attribute 'intake'` for orgs that have no settings row.
>
> **Fix:** Return `DEFAULT_SETTINGS` when `org.settings` is `None` (suggestion below).
>
> - Orgs created before the settings backfill have `settings = NULL` — 212 orgs in prod (`select count(*) from orgs where settings_id is null`).
> - `IntakeWorker.run` calls this on every job (`workers/intake.py:88`), so the whole job fails, not just the config read.

**Good nit:**

> **nit:** `getOrgCfg` → `get_org_config` to match the rest of the module.

## Writing rules

- **Lead with the problem.** The first sentence states what goes wrong. No warm-up.
- **Make the first line self-explanatory.** It must be understandable on its own, with no terms the author has to guess. See "The label + TL;DR line matters most" above.
- **Name the trigger.** Say exactly which input, state, or path hits the problem. "When X, Y happens" beats "this might break".
- **Always propose a fix.** Even a rough one. If you truly have none, it is a `question`.
- **Facts verbatim.** Paths, line numbers, function names, error text, counts, commands, query results. Never paraphrase an error message.
- **Short.** TL;DR + fix + up to 4 bullets. If it needs more, it is probably a design discussion: say so in one line and offer a call or a thread on the MR.
- **Full sentences, plain words.** No caveman or telegraphic style, even if the chat is using it. Define project jargon the author might not know.
- **Kind and direct.** Talk about the code, not the person ("this call drops the error", not "you forgot the error"). No sarcasm, no "obviously", no "why would you". No lecturing about best practices — state the concrete consequence instead.
- **One issue per comment.** Two problems on the same line → two comments, so each can be resolved separately.
- **No filler.** Cut "I think maybe", "Just a thought", "It is worth noting that", "Great work but".
- **Do not repeat the code back.** The author can see the diff. Quote only the part that matters.

## Self-check

Before handing the draft(s) over, confirm each line:

- [ ] The first sentence alone tells the author what is wrong and when.
- [ ] The first sentence is a plain, full sentence with no shorthand, no invented names, and no identifier left unexplained. A teammate who did not see the review would not have to guess what any word means.
- [ ] The comment has a label, and the label matches the real severity.
- [ ] There is a concrete fix (or, for a question, what you would check).
- [ ] The trigger is named: input, state, or code path — not "in some cases".
- [ ] Every fact is verbatim and verified (paths, lines, errors, numbers).
- [ ] It is short enough to read in under 30 seconds.
- [ ] The tone is about the code, not the person.
- [ ] Nothing has been posted yet — the user approves first.
