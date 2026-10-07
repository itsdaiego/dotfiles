---
name: write-mr
description: Use when writing, rewriting, or reviewing a GitLab MR or GitHub PR description. Produces a human-readable description that opens with a short summary of the key ideas, states why the change exists, shows the behavior before and after the change, and keeps every fact (paths, numbers, commands, rollout steps) intact. Also use when the user says an MR description is too dense, too verbose, hard to parse, or "reads like an LLM wrote it".
---

# Writing MR descriptions

An MR description has two readers:

1. **The skimmer** (reviewer picking up the MR, PM, on-call engineer reading it six months later). They read the top 5 lines and decide whether they need more.
2. **The reviewer** who reads everything. They need the details, but grouped so they never have to reverse-engineer what the change does.

Companion skill: `read-mr` digests an existing MR for a reader. This skill writes the description.

Common failures this skill fixes:

- **Buried point.** The description opens with history ("X was added in !9147 to...") and the actual change shows up in paragraph two.
- **Change list = file list.** Bullets walk the diff file by file, so the reader learns *where* code moved but not *what behaves differently*.
- **Dense and compressed at the same time.** Long, but every sentence packs three identifiers and no explanation. Verbose and encoded.
- **No before/after.** The reader has to imagine the old behavior to understand the new one.
- **Undefined terms.** Project jargon (`fleet cap`, `per_entity_dedup`, `fork point`, `enveloped path`) used without saying what it means.
- **Stale sections.** "Required before merge" or "TODO" sections left in after they are done or no longer true.

## Workflow

1. **Gather facts first.** Read the diff (`git diff <target>...HEAD` or the MR diff), the commits, the linked ticket, and any existing description. Note every concrete fact: paths, routes, flags, numbers, commands run and their results, rollout constraints, open questions.
2. **Write the summary last, put it first.** After you understand the change, write 2–4 sentences that a skimmer can stop after.
3. **Fill the template below.** Drop a section only when it truly has nothing to say. Never drop a fact to make the text shorter.
4. **Run the self-check** at the bottom before you hand it over.
5. **Do not post or edit the MR without asking.** Show the draft. Update the MR (`glab mr update <iid> --description-file ...` or the GitLab MCP) only after the user confirms.

## Template

```markdown
## Summary

<2–4 sentences. What changes, for whom, and why. Key ideas only — not every
change. A reader who stops here should know what the MR does and whether it
affects them.>

## Why

<The problem or motivation in plain words. Include evidence when you have it:
numbers, logs, incidents, the ticket's ask. One short paragraph or a few
bullets.>

## Before and after

| | Before | After |
|---|---|---|
| <behavior 1> | <what happened before> | <what happens now> |
| <behavior 2> | ... | ... |

<Describe observable behavior: what a user, CSM, worker, or caller sees.
Not "edited foo.py". Use a table when there are 2+ comparable behaviors;
use two short paragraphs ("Before: ... After: ...") for a single one.>

## What changed

<Group by concern, not by file. Each group gets a short bold heading and
bullets. Each bullet says what it does, then names the code that does it.>

**<Concern 1>**
- <What and why>. (`path/to/file.py`, `SomeClass`)

**<Concern 2>**
- ...

## Impact and rollout

- **Who is affected:** <users / orgs / services, with counts if known>
- **Deploy order:** <constraints, or "none">
- **Migration:** <needed or not, and why>
- **Rollback:** <what happens on revert, anything to restore>

## Testing

- `<exact command>`: <result, e.g. 49 passed>
- <Manual check: what you did and what you saw>

## Out of scope / open questions

- <Things deliberately left out, with the reason>
- <Questions the reviewer should weigh in on>

## Context

- Linear: <link>
- Slack: <link>
- Related MRs: !<n>
```

## Writing rules

- **Lead with the point.** The first sentence of the Summary states the change. History goes in Why.
- **Full sentences, one idea each.** Active voice, clear actor. No caveman or telegraphic style, even if the chat is using it.
- **Behavior over files.** "Orgs with intake on now see the Telephony section" beats "`IntegrationsTab`: show section when `LeadsPage` is on". Name the file *after* the behavior, in parentheses or at the end.
- **Define jargon on first use.** "fleet cap (the max number of concurrent runs across all orgs)". If the MR uses 3+ project terms, add a short glossary under Why.
- **Keep every fact verbatim.** Paths, commands, error text, route paths, flag names, counts, dates, SHAs. Clarity never justifies dropping one.
- **Tables for comparisons, bullets for lists, prose for reasoning.** Do not bullet a chain of reasoning.
- **Bold sparingly.** Only for the one or two things a skimmer must not miss (a breaking change, a deploy-order rule, a data-loss risk).
- **Remove stale content.** Before merge, delete "Required before merge" and TODO sections that are done. If something is still pending, say so in the Summary.
- **No filler.** Cut "This MR aims to", "In order to", "It is worth noting that".
- **Ticket IDs and links belong here**, not in code comments.

## Self-check

Before handing the draft over, confirm each line:

- [ ] Someone who reads only the Summary knows what changes and why.
- [ ] The Before and after section describes behavior, not files.
- [ ] Every "What changed" bullet starts with what it does, not where it is.
- [ ] Every project term is defined on first use.
- [ ] Every fact from the diff and old description is still present (paths, numbers, commands, rollout, rollback, open questions).
- [ ] Risky items (deploy order, rollback, lost access, data deletion) are visible in Impact and rollout, not buried in a bullet.
- [ ] No stale "before merge" or TODO sections.
- [ ] Testing lists exact commands and results.
