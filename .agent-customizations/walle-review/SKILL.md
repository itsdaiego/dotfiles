---
name: walle-review
description: Use Wall-E as a proxy for Butler MR reviews so the local session spends few tokens. Use when Daiego runs /walle-review, asks Wall-E to review MRs, asks to "use Wall-E as a proxy", or wants a review loop that Wall-E does the heavy lifting for. Wall-E reviews the MRs and posts one Markdown findings file in #walle-dyego. The local agent then writes the comments with write-mr-comment, posts them, approves clean heads without asking, and shows a table of every MR with its link.
---

# Wall-E review proxy

Wall-E does the expensive work: it fetches every MR head, reads the diffs, checks conflicts and Alembic chains, and reads CI traces. The local agent only sends the request, reads Wall-E's file, publishes comments and approvals, and reports.

Daiego has authorized this skill to post comments and approve without asking. Do not wait for confirmation on any GitLab write that this skill describes.

## Fixed values

| What | Value |
|---|---|
| Slack channel | `#walle-dyego`, ID `C0C0YFLFUR4` (private) |
| Wall-E Slack user | `<@U0AF0Q79FA7>` |
| Daiego Slack user | `<@U0C0Q7F8CFL>` |
| GitLab project | `butlerinc/butler` (`butlerinc%2Fbutler` in API paths) |
| MR link format | `https://gitlab.com/butlerinc/butler/-/merge_requests/<iid>` |

Always mention people in Slack as `<@USER_ID>`. A literal `@name` does not notify anyone.

## Approval rule

Only a confirmed high-severity issue blocks approval: a bug that breaks behavior or data, a security or tenant-isolation hole, a feature-gate leak, an unsafe migration or rollout, CI that fails because of the MR, or merge conflicts. A title or description fix, a medium or low finding, or CI that fails on tests the MR does not touch never blocks.

## State

Keep one state file per day in the session scratchpad, `walle-review-state.md`. It holds:

- the watch list: one row per open MR with its iid, the last reviewed head SHA, and the last verdict;
- each request thread `ts` that Wall-E has not answered yet;
- what the agent posted and approved in each round.

Drop an MR from the watch list when it merges or closes.

## One round

1. **Read open threads first.** For each pending request thread, read it with `slack_read_thread` (concise). When Wall-E has posted a file, read it with `slack_read_file`. A large file is saved to disk; read it from there in full. Save it to the scratchpad. If no file is there yet, skip to step 6.
2. **Re-check each MR before you act.** Fetch the MR from the GitLab API. Act only when the current `sha` starts with the head SHA in Wall-E's section. If the head moved, skip the MR and put it back on the watch list for the next round.
3. **Approve** each APPROVE verdict at its exact head: `glab api -X POST projects/butlerinc%2Fbutler/merge_requests/<iid>/approve -f sha=<full sha>`. Skip MRs that Daiego already approved at that head.
4. **Post each BLOCK finding.** Load the `write-mr-comment` skill and write one comment per finding. Post it inline at the file and line when that line is in the diff. Otherwise post a general discussion. Skip a finding when an open thread already raises it.
5. **Downgrade stale blockers.** When Wall-E rates one of Daiego's open blocking threads as medium or low and approves the MR, reply in that thread. Label the reply `suggestion (no longer blocking)` or `follow-up (no longer blocking)`, give the one-line reason and the fix, and name the head you approved.
6. **Send the next request**, unless a request is still pending. Post a new top-level message in `#walle-dyego` that mentions Wall-E and asks for:
   - a full review of every MR that is new to the watch list;
   - a head check on every watched MR, with a new review only when the head changed, when conflicts or CI caused by the MR changed, or when an author replied to an open blocking thread;
   - one Markdown file posted as a reply in the thread, with a mention of Daiego when it is done;
   - no GitLab writes;
   - a "Done" line for MRs that merged or closed, and one line that lists the MRs with no change.

   Each MR section in the file must hold: the link, the author, the head SHA, the CI status, conflicts yes or no, a verdict of APPROVE, BLOCK or HOLD, and, for each new high-severity finding, the file and line, the trigger, the effect, the evidence and a proposed fix. Include the approval rule in the request.
7. **Reply in Wall-E's thread** with a short summary: what was approved, what was posted, what was downgraded, and what is still on hold.
8. **Show the table** (below) to Daiego.

## The MR table

After every round, and whenever Daiego asks for the status, show one table with every MR checked so far, including MRs that merged. Every row links to its MR.

| MR | Author | Status | Head | Note |
|---|---|---|---|---|
| [!24151](https://gitlab.com/butlerinc/butler/-/merge_requests/24151) | urvesh.patel1 | Blocked | `6ab43a75` | Blocker posted: 16 comms snapshot files not regenerated |

- Status is one of: Merged, Approved, Blocked, Hold, Pending, Obsolete.
- Note gives the one reason that matters now, in plain words: the blocker, the conflict, the thread it waits on, or why CI is red.
- Sort by status, in this order: Blocked, Hold, Pending, Approved, Merged, Obsolete.
- Name any MR that no one has acted on yet below the table.

## Looping

When Daiego asks for a recurring run ("every hour until midnight"), schedule the round with the harness's scheduler, such as `CronCreate` in Claude Code. Check for Wall-E's reply every 20 minutes. Send a new request at most once an hour, and only after the previous request has an answer. Stop at the time Daiego gave and say so.

Wall-E usually needs 20 to 30 minutes for a round of about 30 MRs.
