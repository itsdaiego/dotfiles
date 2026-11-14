---
name: brain-alerts
description: Warn Daiego about brain items that are overdue, due today, or due tomorrow, and about meetings in the next working day that need prep. Reads `~/.ai/eve/brain.md` and rechecks each alert against its source so done work is not reported. Use when the user runs /brain-alerts, asks "what's overdue", "what's due tomorrow", "what am I late on", "anything I forgot", or at the start of a working day.
---

# Brain alerts

Give a short warning list from the shared brain. The list answers two questions: what is late, and what needs work before it comes due.

## Inputs

- `~/.ai/eve/brain.md`: the live list. If it is missing, tell the user to run `/brain` first.
- The current week file `~/.ai/eve/weekly/YYYY-Www.md`, when it exists.
- The user's calendar or Granola upcoming meetings for the next working day, when those tools are available.

Resolve today's date from the system. "Tomorrow" means the next working day: Friday's tomorrow is Monday.

## Classify

1. **Overdue.** A `📅` date before today, or an item in `🔴 Overdue or due now`.
2. **Due today.** A `📅` date that is today.
3. **Due tomorrow.** A `📅` date on the next working day, or a meeting on that day whose prep is in the brain or the week plan.
4. **Going stale.** A `(promise)` with no deadline that is older than 7 days, or a `re-requested` review older than 2 working days.

Skip items without a date unless they fall in group 4.

## Recheck before alerting

For each candidate, check the source with read-only tools. An MR that merged or closed, a thread with a later reply from the user, or a Linear issue in Done is not an alert. Move such items to the log with `brain-update` rules and say so in one line. If a source cannot be checked, keep the alert and mark it `unverified`.

## Output

Lead with the count in one sentence, such as "3 overdue, 1 due today, 2 due tomorrow." Then one table.

Pick the table format from the interface that renders this reply:

- **Rendered client (the default when unsure):** the Claude desktop app, claude.ai, an IDE panel, Pi Pocket, or any host that renders Markdown. Signals include a system note that names the app, an `Artifact` tool, or `mcp__ccd_*` tools. Use a GFM pipe table, with each link as a Markdown link.
- **Plain terminal:** a bare CLI session with none of those signals. Use the ASCII box table, and print each URL on a continuation row below its item.

The `table-view` skill holds the same rule when another skill needs it.

Rendered client:

```markdown
| Status | What to do | Due | Link |
|---|---|---|---|
| Overdue | Send the vendor test output | 2026-11-05 | [Gmail thread](https://...) |
```

Plain terminal:

```text
+----------+------------------------------+------------+--------------+
| Status   | What to do                   | Due        | Link         |
+----------+------------------------------+------------+--------------+
| Overdue  | Send the vendor test output  | 2026-11-05 | Gmail thread |
+----------+------------------------------+------------+--------------+
```

Order rows Overdue, Due today, Due tomorrow, Going stale. Inside a group, put the oldest date first. End with the one item to do first and why, in one sentence.

## Rules

- Read-only toward every external service. Never send a message, reply, or notification on the user's behalf.
- Write only under `~/.ai`, and only to log items you verified as done.
- If nothing qualifies, say "No alerts" and name the next dated item.
