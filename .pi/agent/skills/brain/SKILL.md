---
name: brain
description: Rebuild Daiego's shared Eve brain (`~/.ai/eve/brain.md`) from Slack, Gmail, Notion, Linear, GitLab, and Granola. Find unresolved requests from other people, the user's own outstanding commitments, and Intake MR reviews still owed. Use when the user runs /brain or /todo, asks "what should I do", "what do I owe", "what did I promise", or wants a full to-do sweep. Use `brain-update` for small edits and `brain-alerts` for overdue and due-soon warnings.
---

# Brain

Build one actionable list across the requested services, then write it to the shared brain at `~/.ai/eve/brain.md`. Include unresolved requests from other people, the user's own unresolved commitments, and MR reviews owed to the Intake team. Read `~/.ai/README.md` first for the brain's rules.

The sweep is read-only toward every external service. Do not reply, react, send or draft mail, change notification state, assign work, approve, or mark anything complete. The only writes are to `~/.ai/eve/brain.md`, `~/.ai/eve/log.md`, and `~/.ai/eve/weekly/`, made with the `brain-update` rules.

## Input and scope

- `/brain` searches Slack, Gmail, Notion, Linear, GitLab, and Granola. `/todo` is an alias.
- `/brain slack, linear` searches only the named sources. Accept `all` as all six sources. `commitments` narrows results to the user's own promises; `requests` narrows results to requests from other people.
- Treat a direct request to run this skill as consent to search the user's accessible Slack channels, private channels, and DMs when looking for the user's own commitments. For ordinary incoming-request searches, exclude DMs unless the user asks for them.
- Search live sources for items created or updated in the last 30 days by default. Also read open items from `/Users/daiego/.local/state/to-do-backlog/backlog.json` when it exists; this durable backlog may contain older requests discovered by the `to-do-backlog` refresh. Honor a shorter user-supplied date range for the live search, but keep older cached items unless the user explicitly asks to exclude them. State the live time range and whether the retained backlog was included before the table.
- Resolve the authenticated identity for every service at the beginning. Never guess an ID, username, or display name from an earlier run.

An incoming request belongs in the list only when all of these are true:

1. Someone other than the authenticated user explicitly mentioned or tagged them, or formally requested their review on a GitLab merge request.
2. The message, comment, or page asks for a reply, decision, investigation, change, review of content, or another concrete next action.
3. The item is not clearly resolved in a later reply, comment, or page update.

Exclude FYIs, automated notices, status updates, ordinary assignments without a mention, reactions, and messages that merely include the user's name. A formal GitLab review request is the only assignment-style exception. When the request is unclear, include it with `Check context` as the action instead of inventing work.

A self-authored commitment belongs in the list only when all of these are true:

1. The authenticated user clearly took ownership of a concrete future action, such as "I’ll investigate", "I can send the draft tomorrow", or "I’m going to fix this".
2. The action is specific enough to act on, or surrounding context makes it specific.
3. No later evidence in the same thread, issue, page, or meeting clearly shows the commitment was completed, cancelled, delegated, superseded, or no longer needed.

Do not turn brainstorming, estimates, conditional possibilities, acknowledgements, vague intent, or completed-work statements into tasks. A phrase such as "I could look into it" is a commitment only when the surrounding conversation shows the user accepted that work. Preserve the promised deadline when present. When attribution, scope, or resolution is unclear, include `Check context` instead of guessing.

## Gather items

Run independent source searches in parallel where the MCP tools allow it. Resolve the authenticated identity for every source, then search both incoming requests and self-authored commitments. Read the surrounding thread, comment, page, issue, or meeting before deciding whether an item needs action. Keep the original link for every result.

For a commitment search, exhaust pagination for every search query and report when a source cannot enumerate all author-owned content. Use several narrowly targeted commitment queries rather than assuming one phrase catches every promise. Search natural variations of future ownership: `I'll`, `I will`, `I'll take`, `I can`, `I can own`, `I'll handle`, `I'll send`, `I'll check`, `I'll look`, `I'll follow up`, `I'm going to`, `I plan to`, `I'll get back`, and the authenticated user's name where a source needs it. Inspect candidates in context. An explicit user request for all history overrides the default live window; otherwise the durable backlog provides the historical pass.

Before live searches, read the durable backlog when available. Keep only records with `status: "open"`. Treat cached content as a candidate, not proof: recheck its source when tools are available, especially when `last_checked_at` is older than 7 days. If a source is unavailable, retain its cached open items and state the last verification time instead of silently dropping them. Deduplicate cached and live results by `id` or `source_key`, preferring freshly verified source data.

### Slack

1. Identify the signed-in user from the Slack tool response or `slack_search_users`.
2. Search with `slack_search_public_and_private` for the literal Slack mention token, such as `<@U123456>`, in the requested period. Use a date filter and exclude DMs unless requested.
3. Exclude messages authored by the signed-in user. Read each matching thread with `slack_read_thread`.
4. Keep only direct, unresolved requests from another person. Use the thread permalink as the link.

For commitments, search messages authored by the signed-in user across accessible public and private channels and DMs, using the service's author filter or equivalent search syntax. Paginate each query within the period, read the full thread, and retain only unresolved commitments. If the Slack API cannot enumerate all author-owned messages, state that limitation rather than claiming complete coverage.

A message that says "FYI <@U123456>" is not a task. A message that says "<@U123456>, can you check the deploy?" is one.

### Linear

1. Use `linear_get_notifications` to inspect the signed-in user's inbox. Fetch enough pages to cover the requested period.
2. Keep only issue notifications generated by another person explicitly mentioning the user in a comment, description, or linked discussion. Do not include assignments, status changes, subscriptions, or reviewer-style requests unless their text also contains an explicit mention and a concrete ask.
3. Fetch the issue with `linear_get_issue` and its discussion with `linear_list_comments` when the notification does not contain enough context. Use the newest relevant comment to decide whether the request remains open.
4. Link to the Linear issue or the specific comment when the MCP response provides it.

Do not use `linear_list_issues` with `assignee: "me"` as a substitute for mentions.

For commitments, search comments and issue descriptions authored by the signed-in user. Read the issue and newest discussion before retaining a promise. Do not treat an assignee field as a promise.

### GitLab

1. Identify the signed-in user with `gitlab_get_user` using `me: true`.
2. Search GitLab notes with `gitlab_search`, `scope: "notes"`, and the exact mention form `@<username>`. Search the user's display name only when the workspace uses it for real mentions, then verify the note contains an explicit tag.
3. Exclude notes authored by the signed-in user. Read the parent merge request or work item when the note lacks enough context.
4. Keep direct, unresolved action requests and formal review requests. Do not add an item merely because the user is an assignee. A merged or closed merge request resolves its review request unless a later note asks for another action.

For commitments, search notes authored by the signed-in user in merge requests and work items, then read the parent and later notes. A later commit, merge, closure, or explicit follow-up can resolve the promise when it addresses the promised work.

### Gmail

1. Search sent mail in the period (`in:sent after:YYYY/MM/DD`) and read each thread. Keep concrete promises the user made with no later evidence of completion.
2. Search the inbox for threads from real people that ask the user for a reply, decision, document, or action, and that the user has not answered. Exclude newsletters, calendar invites, and notification mail from GitLab, Linear, Slack, or Notion.
3. Keep personal-admin and security items that need the user's action, such as an expense-tool activation or an unknown-device login alert.
4. Never send, draft, label, archive, or trash mail. Link each item as `https://mail.google.com/mail/u/0/#all/<threadId>`.

### Notion

1. Discover the available Notion search and page-retrieval tools. If Notion is not authenticated, say so in the table and give the one authentication action needed. Do not silently omit it.
2. Resolve the signed-in user's Notion identity, then search page content and comments for that user's actual Notion mention object. Fall back to their display name only to find candidates, and inspect each candidate to verify the structured user mention.
3. Read the page or comment around each mention. Keep direct, unresolved requests made by someone else. Link to the page or comment.

For commitments, search pages, databases, and comments created or edited by the signed-in user for concrete future ownership. Search both the user's display name and commitment terms to find candidates, then verify authorship and read later page activity or comments for resolution. Never count a task merely assigned to the user as a self-authored promise.

### Granola

1. Use `get_account_info` to identify the connected Granola account and its searchable scopes. State any scope limitation.
2. Search accessible meeting notes for the user's commitments, follow-ups, and action items with `query_granola_meetings`; use several queries that ask specifically what the user committed to do. Also use `search_meetings` for commitment terms within the requested period and paginate every result set.
3. Read each candidate with `get_meetings`. When the result turns on what the user said, who owns an action, a deadline, or whether it was completed, verify it with `search_transcripts` and read surrounding transcript context when available.
4. Keep only commitments clearly attributable to the authenticated user or explicitly assigned to them in a note that records their acceptance. Do not infer ownership from the note creator, attendee list, or first-person wording alone.
5. Use the meeting note URL as the link. If transcript or ownership evidence is unavailable, retain only a `Check context` item when the notes make an unresolved commitment plausible.

### GitLab reviews for the Intake team

List open MRs where the user is a requested reviewer. For each, classify the review state: `not-started` (no note or approval by the user), `in-progress` (the user started threads that are not finished), or `re-requested` (the author pushed or re-requested after the user's last review). A merged or closed MR is done. Mark Intake MRs by an `INTAKE-` scope or an Intake team author.

## Verify before you keep an item

Before you keep an item that is due or older than 3 days, check whether it is already done: the MR merged or closed, the mail thread has a later reply from the user, the Slack thread has a later answer, or the Linear issue moved to Done. Move verified items to `~/.ai/eve/log.md` with the evidence. When verification needs production access, keep the item and mark it `needs prod check`.

## Write the brain

Rewrite `~/.ai/eve/brain.md` with the `brain-update` format and sections. Keep items that the sweep could not recheck, and mark them `?`. Then write or refresh `~/.ai/eve/weekly/YYYY-Www.md` when the user asks what to do next week.

## Combine and present

Deduplicate results that refer to the same Slack thread, Linear issue or comment, GitLab note, Notion page/comment, or Granola meeting. Prefer the newest unresolved request or commitment when a thread has several. Sort by urgency when stated, then by newest activity. In the `Source` cell, append ` (promise)` for a self-authored commitment and set `From` to `You`.

Open with one sentence that says the services searched, time range, and any unavailable service. Then present every result in this exact ASCII-table shape. Keep cell text short, wrap long text onto following table rows, and use a short stable link label when a full URL would make the table unreadable.

```text
+--------+----------------------+------------------+------------------+------------------+
| Source | What needs attention | From             | When             | Link             |
+--------+----------------------+------------------+------------------+------------------+
| Slack  | Check the deploy log | Alex Kim         | 2026-10-21 09:14 | Slack thread     |
+--------+----------------------+------------------+------------------+------------------+
```

Make `What needs attention` an imperative or a clear `Check context` prompt. Do not repeat long message text. Put the actual link behind the link label when the client supports Markdown links; otherwise print the URL on a continuation row below its item.

If no items qualify, still return the table with one row that says `No unresolved explicit requests found`. If a service cannot be searched, include one row for it with the cause and the next safe step. End with one short line that names excluded categories or any source-coverage limitation only when that matters to the result.
