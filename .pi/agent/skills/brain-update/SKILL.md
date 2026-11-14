---
name: brain-update
description: Change Daiego's shared Eve brain at `~/.ai/eve/brain.md`. Add a promise or request, mark an item done and log it, move or reword an item, or recheck items against their sources. Use when the user runs /brain-update, says "add this to my brain", "remember I promised", "I did X", "mark X done", "update the brain", or when a session produces a new commitment or finishes one. Use `brain` for a full sweep across every source.
---

# Brain update

Make small, exact changes to the shared brain. Every harness (Claude Code, Codex, Pi) reads the same files, so keep the format stable.

## Files

- `~/.ai/README.md`: rules for the brain. Read it before the first change in a session.
- `~/.ai/eve/brain.md`: the live list.
- `~/.ai/eve/log.md`: closed items, newest first, grouped under `## YYYY-MM-DD` headings.
- `~/.ai/eve/weekly/YYYY-Www.md`: the plan for one ISO week.

If `brain.md` does not exist, create it with the frontmatter and sections below.

## Item format

One line per item:

```text
- [ ] <imperative action> — <who or where> — <YYYY-MM-DD> — [<label>](<url>)
```

- Prefix `(promise)` when the user said they would do it.
- Prefix `(awaiting reply)` when the user sent an ask that nobody answered. Put it under `🟢 Customer and team promises` or `Admin and personal`.
- Add `📅 YYYY-MM-DD` for a deadline. Use the real date. Convert "tomorrow" or "Friday" to a date.
- Prefix `?` when the item may already be done or ownership is unclear.
- Add `needs prod check` when only production data can confirm it.
- Write `(no source)` when there is no link. Never invent a link.

## Sections in brain.md

Keep these headings, in this order. Put each item in exactly one section.

1. `## 🔴 Overdue or due now`
2. `## 🟠 Reviews owed (Intake team)`
3. `## 🟡 My own MRs`
4. `## 🟢 Customer and team promises` (with `###` sub-headings per customer or topic)
5. `## ⚪ Assigned Linear issues`
6. `## Admin and personal`
7. `## Probably stale (confirm, then move to the log)`
8. `## Coverage notes`

Update `updated:` in the frontmatter on every change.

## Operations

- **Add.** Check for a duplicate by link or by action first. Update the existing line instead of adding a second one.
- **Done.** Remove the line from `brain.md`. Add a line to `log.md` under today's heading: `- <what closed> — <evidence link or short evidence>`. Never delete an item without logging it.
- **Verify.** For each item the user names, or for every item when asked, check the source with read-only tools. An MR that merged or closed is done. A thread with a later reply from the user is done. A Linear issue in Done or Canceled is done. Log what you verify. Leave anything unverifiable in place and say why.
- **Move.** When a deadline passes, move the item to `🔴 Overdue or due now`.
- **Weekly.** When the user asks for a week plan, write `weekly/YYYY-Www.md` from `brain.md`. Link it from `brain.md` with `[[eve/weekly/YYYY-Www]]`.

## Rules

- Never write secrets, tokens, customer personal data, or message bodies. Write a one-line summary and a link.
- Never contact anyone or change an external service. This skill writes only under `~/.ai`.
- After a change, tell the user in one or two lines what was added, closed, or moved.
