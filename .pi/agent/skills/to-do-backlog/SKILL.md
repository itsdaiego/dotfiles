---
name: to-do-backlog
description: Maintain Daiego's durable personal to-do backlog from Slack, Notion, Linear, and GitLab. Use for scheduled backlog refreshes, historical backfills, or when the to-do skill needs unresolved requests older than 30 days.
---

# To-do backlog

Maintain a local index of unresolved work so the ordinary `to-do` skill can report requests older than its live 30-day search window. Source access is read-only. The only write is the local state file at `/Users/daiego/.local/state/to-do-backlog/backlog.json`.

Read [references/state-schema.md](references/state-schema.md) before changing the state file.

## What belongs in the backlog

Keep an item when another person requested a concrete reply, decision, investigation, change, or review and no later source evidence clearly resolves it. Include formal GitLab code-review requests even when the request came through the reviewer field instead of an explicit mention. Exclude FYIs, automated notices, status updates, self-authored requests, ordinary assignments without a concrete ask, and messages that merely contain Daiego's name.

Never infer resolution from age, a closed notification, or silence. A merged or closed merge request resolves its review request unless a later comment asks for another action.

## Refresh workflow

Resolve the authenticated identity separately for every available service on every run. Never reuse a guessed identity from the state file.

1. Read the state file. If it does not exist, initialize the schema from the reference.
2. Scan recent activity with a 48-hour overlap from the last successful run. On the first run, scan the last 30 days.
3. Continue the historical backfill for each source using one 90-day window per run, moving backward from the oldest completed boundary. Continue until the source reports that no earlier searchable history exists.
4. Read the surrounding thread, comments, page, issue, or merge request for every candidate. Apply the same inclusion rules as the `to-do` skill.
5. Recheck cached open items touched by the recent scan. Also recheck up to 50 open items whose `last_checked_at` is oldest, so old requests eventually get revalidated.
6. Deduplicate by the source's stable thread, page/comment, issue/comment, or merge-request/note identity. Update an existing record instead of appending a duplicate.
7. Mark an item `resolved` only when later source evidence proves it. Preserve resolved records for audit and set `resolved_at` and `resolution_evidence`.
8. Write the full state atomically. Update a source cursor only after that source's window completes successfully. Record source failures without advancing its cursor.

Use the available service-specific tools and paginate enough to cover each window. If a service is not connected, record `unavailable` and the reason in `sources`; continue with the other services.

The hourly run should be quiet. Return only a compact summary with counts for new, updated, resolved, still open, source failures, and each source's oldest scanned date.

## Scheduled task configuration

Use a local scheduled task because the state file must persist on this computer.

- Title: `Refresh long-term to-do backlog`
- Schedule: `RRULE:FREQ=HOURLY;INTERVAL=1`
- Time zone: `America/Sao_Paulo`
- Timing: exact schedule
- Local project: `/Users/daiego`
- Prompt: `Run $to-do-backlog. Refresh the durable backlog from every connected source. Continue the historical backfill, recheck stale open items, update the local state atomically, and report only the compact refresh summary.`

The computer and ChatGPT desktop app must be running for local scheduled tasks. Do not create a second task when one with this title already exists; update the existing task instead.
