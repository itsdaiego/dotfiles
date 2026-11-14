---
name: walle-review
description: Use Wall-E as a proxy for Butler MR reviews so the local session spends few tokens. Use when Daiego runs /walle-review, asks Wall-E to review MRs, asks to "use Wall-E as a proxy", or wants a review loop that Wall-E does the heavy lifting for. Wall-E reviews the MRs and posts one Markdown findings file in #walle-dyego. The local agent then writes the comments with write-mr-comment, posts them, lists the clean heads Daiego can approve (it never approves on its own), and shows a table of every MR with its link.
---

# Wall-E review proxy

Wall-E does the expensive work: it fetches every MR head, reads the diffs, checks conflicts and Alembic chains, and reads CI traces. The local agent only sends the request, reads Wall-E's file, publishes comments, and reports which MRs are ready for Daiego to approve.

Daiego has authorized this skill to post comments without asking. Do not wait for confirmation on the comment and reply writes that this skill describes.

**Never approve an MR on your own.** Every approval needs Daiego's explicit sign-off. An APPROVE verdict from Wall-E is a recommendation, not permission. Approve an MR only when Daiego asks, in this conversation, to approve that specific MR. A request to start or loop this skill does not authorize approvals.

## Fixed values

| What | Value |
|---|---|
| Slack channel | `#walle-dyego`, ID `C0C0YFLFUR4` (private) |
| Wall-E Slack user | `<@U0AF0Q79FA7>` |
| Daiego Slack user | `<@U0C0Q7F8CFL>` |
| GitLab project | `butlerinc/butler` (`butlerinc%2Fbutler` in API paths) |
| MR link format | `https://gitlab.com/butlerinc/butler/-/merge_requests/<iid>` |

Always mention people in Slack as `<@USER_ID>`. A literal `@name` does not notify anyone.

## Scope

Review only MRs authored by the intake team: `shiva.eve`, `urvesh.patel1`, `acwang`, `kenny.williams`, in `butlerinc/butler`. Never review an MR from another author or another project, even when Wall-E's reply includes one — drop it from the table and do not act on it. When building the watch list (re-pulling `reviewer_username=dyego.rodrigo`, open state), filter to these authors before using the list anywhere.

Drop an MR whose title does not show intake work. The title must name an `INTAKE-<number>` ticket scope (for example `fix(INTAKE-452): ...`) or say "intake". An intake author can open an MR for another team's area, and a title with no intake signal means the MR is not Daiego's to review.

Keep an MR only when someone other than Daiego explicitly requested his review. Check the author's review-request event, not just the current reviewer list. Neither this skill nor Wall-E may add Daiego as a reviewer on any MR.

Build this filtered watch list in this skill, before anything goes to Wall-E. Never ask Wall-E to judge intake membership, title scope, or who requested the review. When a rule drops an MR, do not review or comment on it. Name it, its author, and the rule it failed in the round's Slack reply and below the MR table.

Drop draft MRs (title starts with `Draft:`, or GitLab's own draft flag) from the watch list and from every request to Wall-E. A draft that comes off draft status joins the watch list as new on the next round.

Drop an MR Daiego has already approved at its current head from the watch list and from every request to Wall-E. Check the MR's approvals (`glab api projects/butlerinc%2Fbutler/merge_requests/<iid>/approvals`), not just the reviewer list — an approved MR still lists Daiego as a reviewer. A new push after the approval, or a revoked approval, puts the MR back on the watch list as new.

Drop an MR where Daiego's only reviewer entry is a self-request: GitLab adds the approver as a reviewer the instant they approve, and logs it as a `requested review from` system note authored by `dyego.rodrigo` naming himself. A note like that, timestamped at or right after his own approval, is not a real request from someone else — check the MR's notes (`.../merge_requests/<iid>/notes`) for this before treating Daiego as a genuine reviewer on it. This should never happen: when you find one, remove Daiego from that MR's `reviewer_ids` (`glab api -X PUT projects/butlerinc%2Fbutler/merge_requests/<iid> -F 'reviewer_ids=[<other reviewer ids>]'`, keeping every other reviewer), leaving the approval itself untouched. Do this the moment you spot it, in any round, without asking.

Only keep an MR on the watch list when Daiego is the one who owes an action on it: he has not reviewed it yet, or someone has explicitly asked him to look again. Drop an MR when his last word on it was posting a comment or a blocking finding and nothing has moved since: check the MR's discussions (`.../merge_requests/<iid>/discussions`), and if the last note in every thread he opened or posted in is his own, with no reply from the author or anyone else, and no one has explicitly asked him for a re-review (a reply, a new comment addressed to him, an author ping), there is nothing new for him to look at — the ball is in the author's court. Bring it back onto the watch list the moment the author (or anyone) replies in that thread, or someone explicitly asks him to re-review. This rule is about the recurring watch list only; an explicit one-off ask that names specific MRs (an author or teammate asking directly) always goes forward regardless of this rule.

## Verdict rule

The verdict is a recommendation to Daiego. Only a confirmed high-severity issue makes it BLOCK: a bug that breaks behavior or data, a security or tenant-isolation hole, a feature-gate leak, an unsafe migration or rollout, CI that fails because of the MR, or merge conflicts. A title or description fix, a medium or low finding, or CI that fails on tests the MR does not touch never blocks.

## State

Keep one state file per day in the session scratchpad, `walle-review-state.md`. It holds:

- the watch list: one row per open MR with its iid, the last reviewed head SHA, and the last verdict;
- each request thread `ts` that Wall-E has not answered yet;
- what the agent posted, and which MRs it listed as ready to approve, in each round.

Drop an MR from the watch list when it merges or closes.

## One round

1. **Read open threads first.** For each pending request thread, read it with `slack_read_thread` (concise). When Wall-E has posted a file, read it with `slack_read_file`. A large file is saved to disk; read it from there in full. Save it to the scratchpad. If no file is there yet, skip to step 6.
2. **Re-check each MR before you act.** Fetch the MR from the GitLab API. Skip it, and drop it from the watch list, if it no longer qualifies per Scope above (Daiego has since approved it, its only reviewer entry is a self-request, it went back to draft, the author changed, or he's just waiting on an unanswered comment with no re-review request). Act only when the current `sha` starts with the head SHA in Wall-E's section. If the head moved, skip the MR and put it back on the watch list for the next round.
3. **List each APPROVE verdict for Daiego** with its link and exact head SHA, as `Ready to approve`. Do not call the approve endpoint. When Daiego explicitly asks to approve named MRs, approve only those, at the reviewed head: `glab api -X POST projects/butlerinc%2Fbutler/merge_requests/<iid>/approve -f sha=<full sha>`. If the head moved, do not approve, and say so.
4. **Post each BLOCK finding.** Load the `write-mr-comment` skill and write one comment per finding. Post it inline at the file and line when that line is in the diff. Otherwise post a general discussion. Skip a finding when an open thread already raises it.
5. **Downgrade stale blockers.** When Wall-E rates one of Daiego's open blocking threads as medium or low and recommends approval, reply in that thread. Label the reply `suggestion (no longer blocking)` or `follow-up (no longer blocking)`, give the one-line reason and the fix, and name the head Wall-E reviewed.
6. **List the watch list for Daiego before sending.** Before posting the next request (and before the very first request of a run), re-pull the open MRs (`reviewer_username=dyego.rodrigo`, open state) and filter per Scope above (intake authors only, drafts dropped, MRs Daiego already approved dropped, self-request-only entries dropped, MRs where he's only waiting on an unanswered comment dropped). Show Daiego, in the chat reply, a table — always, even when the list is short or unchanged — with one row per MR about to go out this round. Columns: MR (linked, `[!<iid>](<MR link>)`), Author, Round action (`Full review`, `Head check`, or `Dropped — merged/closed`). Only send the request once this table is shown.
7. **Send the next request**, unless a request is still pending. Post a new top-level message in `#walle-dyego` that mentions Wall-E and asks for:
   - a full review of every MR that is new to the watch list;
   - a head check on every watched MR, with a new review only when the head changed, when conflicts or CI caused by the MR changed, or when an author replied to an open blocking thread;
   - one Markdown file posted as a reply in the thread, with a mention of Daiego when it is done;
   - no GitLab writes;
   - a "Done" line for MRs that merged or closed, and one line that lists the MRs with no change.

   Each MR section in the file must hold: the link, the author, the head SHA, the CI status, conflicts yes or no, a verdict of APPROVE, BLOCK or HOLD, and, for each new high-severity finding, the file and line, the trigger, the effect, the evidence and a proposed fix. Include the approval rule and the Scope restriction in the request.
8. **Reply in Wall-E's thread** with a short summary: what is ready for Daiego to approve, what was posted, what was downgraded, and what is still on hold.
9. **Show the table** (below) to Daiego.

## The MR table

After every round, and whenever Daiego asks for the status, show one table with every MR checked so far, including MRs that merged. Every row links to its MR.

| MR | Author | Status | Head | Note |
|---|---|---|---|---|
| [!24151](https://gitlab.com/butlerinc/butler/-/merge_requests/24151) | urvesh.patel1 | Blocked | `6ab43a75` | Blocker posted: 16 comms snapshot files not regenerated |

- Status is one of: Merged, Approved (by a person), Ready to approve, Blocked, Hold, Pending, Obsolete.
- Note gives the one reason that matters now, in plain words: the blocker, the conflict, the thread it waits on, or why CI is red.
- Sort by status, in this order: Blocked, Ready to approve, Hold, Pending, Approved, Merged, Obsolete.
- Name any MR that no one has acted on yet below the table.

## Looping

When Daiego asks for a recurring run ("every hour until midnight"), schedule the round with the harness's scheduler, such as `CronCreate` in Claude Code. Check for Wall-E's reply every 20 minutes. Send a new request at most once an hour, and only after the previous request has an answer. Stop at the time Daiego gave and say so.

Wall-E usually needs 20 to 30 minutes for a round of about 30 MRs.
