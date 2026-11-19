---
name: brain-oncall
description: Keep a plain Markdown file of Daiego's oncall-intake related items (bug reports, production issues flagged to @oncall-intake, INTAKE- tickets raised through on-call channels) for a bounded stretch of time. Use when Daiego runs /brain-oncall, asks to be "kept on" oncall-intake things for a stretch ("until Friday"), or wants a running note file of oncall-intake items distinct from the live dashboard and from the full /brain sweep.
---

# Brain oncall

Narrower, file-based sibling of [[brain]], scoped only to oncall-intake. Where the
`oncall-intake` skill polls Slack every 5 minutes into `~/ai/eve/oncall-intake/pings.json`
(no leading dot — a separate directory from this one) and serves a live dashboard, this
skill keeps a hand-maintained Markdown note at `~/.ai/eve/oncall-intake-brain.md` — same
family as `~/.ai/eve/brain.md` / `log.md`. No JSON, no server, no poller: adding or closing
an item means editing this one file.

## When to use this vs. the other two

- **oncall-intake** (dashboard skill): "who pinged me", "what's pending", move an item
  between pending/doing/done. Live, automatic, per-ping, backed by `pings.json`.
- **brain** / **brain-update**: the full cross-service sweep and the general shared to-do
  file at `~/.ai/eve/brain.md`.
- **brain-oncall** (this skill): Daiego asked to be kept posted on oncall-intake-flavored
  items for a bounded stretch ("until Friday", "this week") and wants them noted in one
  file he can read back later, separate from the live dashboard's rolling state and from
  the general brain.

## File

`~/.ai/eve/oncall-intake-brain.md`. Frontmatter:

```yaml
---
title: Oncall-intake brain
tags: [eve, oncall-intake]
updated: YYYY-MM-DD
window: YYYY-MM-DD to YYYY-MM-DD
---
```

`window` is the tracking period Daiego asked for (e.g. "until Friday" → today's date to
the coming Friday). When `window` passes, ask Daiego whether to close the file out (move
any still-open items to `~/.ai/eve/brain.md` or drop them) or extend the window.

## Item format

Same convention as `brain.md`: `- [ ] (<status>; <metadata>) <what it is> — <who/channel> — <YYYY-MM-DD> — [label](url)`. Use `pending` or `in progress` as the first metadata value. Add the severity when known (`urgent`/`high`/`medium`/`low`, matching the `oncall-intake` skill's own severity rules: Linear priority on a linked issue, then a P0–P4/SEV0–SEV4 or "urgent"/"ASAP" marker in the thread) and the Linear ticket id when the item links one. Keep the Slack thread link and add every active GitLab MR link that tracks the work.

## Sections

1. `## Open`
2. `## Resolved` — closed items move here with one line of evidence, newest first. This
   file keeps its own short resolved-log instead of writing into the shared `eve/log.md`,
   since these are oncall-only and usually short-lived.

## Gather

Two ways items reach this file:

1. **Reactive.** Daiego pastes a Slack link (from #bug-report, #intake-comms,
   #intake-alerts, #case-comms-alerts, #prod-alerts, or any thread that mentions
   `@oncall-intake`) or says "track this" / "keep me on this". Read the thread with
   `slack_read_thread`.
2. **Proactive.** Every run, before answering, scan these four channels yourself for the
   `window` period (default: since the file's last `updated:` date, or the window start on
   the first run) — do not wait for Daiego to paste a link:
   - **#prod-alerts** (`C01NBFKGRCP`) — read recent messages with `slack_read_channel`.
     Most are not intake work (infra/ops noise from other teams). Keep only messages that
     are intake-related: they mention Eve intake, leads, call association, LeadDocket,
     voice/phone intake, Zoom/Five9/Dialpad call legs, or link an `INTAKE-` Linear issue.
     Drop everything else. This mirrors the judgment call the `oncall-intake` poller makes
     against its own `intake_scope`, but done by reading the messages yourself, not through
     that poller's pipeline.
   - **#case-comms-alerts** (`C0B0XQPDXPX`) — read recent messages with
     `slack_read_channel`. This channel is intake-scoped already (it is one of the
     `oncall-intake` skill's `source_channel_ids`), so keep anything that reads as a bug
     report or a real anomaly, not a routine status ping.
   - **#bug-report** (`C08SP7E2S90`) — read recent messages with `slack_read_channel`.
     This is where customer-reported intake bugs usually land first (repeat reports, Pylon
     issues, `@oncall-intake` pings like the file's first item). Keep anything that reads
     as a new or repeat bug report; drop routine bot chatter.
   - **#intake-alerts** (`C09AFN8BVDJ`) — read recent messages with `slack_read_channel`.
     This channel is intake-scoped already (it is one of the `oncall-intake` skill's
     `source_channel_ids`), so keep anything that reads as a bug report or a real anomaly,
     same bar as #case-comms-alerts.
   - For each candidate, read the surrounding thread before deciding it is worth tracking.
     Skip anything already in `## Open` or `## Resolved` (match by Slack permalink or Linear
     ticket id).

For every item, reactive or proactive, summarize in one line: what broke or was reported,
which firm(s) and any CARR/impact figure stated, priority if stated, the Linear ticket if
one is linked, and WALL-E's triage verdict if it posted one (root cause, suggested
fix/owner).

### Keep the live note current

Before answering any `brain-oncall` request, update `~/.ai/eve/oncall-intake-brain.md` with relevant new findings and confirmed status changes. This applies even when Daiego only asks for an explanation or a table. Update an existing item when evidence changes; do not add a duplicate. Move an item to `## Resolved` only when the tracked work is complete. If its ticket is shipped or closed but follow-up work remains, keep it under `## Open` and record the completed part and remaining action. Update `updated:` after every change. If no new evidence changes the note, leave it unchanged.

Classify each open item from live evidence:

- `pending`: no concrete execution has started. An assignee, triage status, suggested fix, or investigation request alone is still pending.
- `in progress`: concrete work has started. Examples include an active branch or MR, tests or implementation underway, submitted carrier or vendor setup, a partial data repair, deployment work, or an active investigation with recorded findings.

When evidence is unclear, use `pending`. Re-evaluate the status on every refresh. Keep the status as the first parenthetical value in the file.

### Suggested owner

Work out who should take each item, in this order, and record it:

1. The assignee on the linked Linear issue, if any.
2. A name WALL-E's triage or the thread itself names as suggested owner/next step.
3. A clear subject-matter fit from recent context (e.g. a LeadDocket write-back bug points
   to whoever owns that integration this week, per [[eve/brain]]).
4. Otherwise `@oncall-intake` (nobody more specific has claimed it yet).

Append it under `## Open` with today's date, the thread permalink, and the owner. Update
`updated:` in the frontmatter.

## Closing an item

When Daiego says it is done, or GitLab/Linear shows the ticket shipped or closed: move the
line to `## Resolved` with the evidence (a merged MR, a Linear status, Daiego's own "done"),
the same operation `brain-update` uses for `brain.md`, but within this file.

## Present

After gathering, render every open item as one table. Do not restate the bullet list.

Sort the rows in this exact order:

1. `Pending`, newest source activity first.
2. `In progress`, newest source activity first.
3. Do not show anything from `## Resolved`.

Use the source's latest activity time for sorting, not the date when the item first entered the file. Pick the format the same way [[brain]] does, using the `table-view` skill's rule:

- **Rendered client (default when unsure):** GFM pipe table, each link as a Markdown link.
- **Plain terminal:** ASCII box table, long text wrapped onto following rows, each URL printed on a continuation row below its item.

The first column must be `Status`, not a checkbox. Make sources explicit:

- Slack-originated item: set `Source` to `Slack` and show the exact channel in `Channel / MR`.
- Item with active GitLab work: set `Source` to `Slack + GitLab`, show the Slack channel and MR number in `Channel / MR`, and link both.
- If more than one MR matters, show every MR number and link.

Rendered client:

```markdown
| Status | Source | Channel / MR | Item | Severity | Owner | When | Link |
|---|---|---|---|---|---|---|---|
| Pending | Slack | #bug-report | INTAKE-269 duplicate leads | High | @oncall-intake | 2026-11-17 | [Slack thread](https://...) |
| In progress | Slack + GitLab | #case-comms-alerts · !12345 | INTAKE-270 transfer fix | Medium | Daiego | 2026-11-16 | [Slack](https://...) · [!12345](https://...) |
```

Plain terminal (wrap long text onto following rows):

```text
+-------------+----------------+-----------------------------+------------------------------+----------+---------------+------------+------------------+
| Status      | Source         | Channel / MR                | Item                         | Severity | Owner         | When       | Link             |
+-------------+----------------+-----------------------------+------------------------------+----------+---------------+------------+------------------+
| Pending     | Slack          | #bug-report                 | INTAKE-269 duplicate leads   | High     | @oncall-intake| 2026-11-17 | Slack thread     |
| In progress | Slack + GitLab | #case-comms-alerts · !12345 | INTAKE-270 transfer fix      | Medium   | Daiego        | 2026-11-16 | Slack · !12345   |
+-------------+----------------+-----------------------------+------------------------------+----------+---------------+------------+------------------+
```

Keep `Item` short (ticket id plus a few words); the full one-line summary stays in the file. If nothing is open, return one `Pending` row that says `No open oncall-intake items`.

## Rules

- Never store secrets, tokens, customer personal data, or full message bodies — a one-line
  summary and a link, same as [[brain]].
- Read-only toward every external service. The only write this skill makes is to
  `~/.ai/eve/oncall-intake-brain.md`. It never posts to Slack, assigns Linear work, or
  touches the `oncall-intake` dashboard's `pings.json` or launchd job. "Suggested owner" is
  exactly that — a suggestion recorded in the file, never an actual Linear assignment.
