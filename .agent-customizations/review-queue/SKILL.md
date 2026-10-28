---
name: review-queue
description: >-
  Use when Daiego wants an overview of every GitLab MR where Daiego is a reviewer, every MR Daiego authored ("my MRs"), or teammates' MRs nobody started reviewing: "review my queue", "what MRs are assigned to me", "which MRs can I approve", "which MRs need review", "/review-queue". Opens a local page that lists each MR with its read-mr summary, CI state, team review state, review urgency, only the critical findings nobody flagged yet, and an approve / don't-approve verdict. A button on each MR starts an unattended review that follows the review-mr skill. Works in Claude Code and Pi. Read-only on GitLab unless Daiego explicitly asks to approve or comment.
---

# Review queue

A local page that covers every open MR where Daiego is a reviewer, every open MR Daiego authored, and every open teammate MR. Daiego can decide where to spend review time before opening any MR, and can see how Daiego's own MRs hold up before a teammate reviews them. The same skill folder serves Claude Code (`~/.claude/skills/review-queue`) and Pi (`~/.pi/agent/skills/review-queue`). Both are symlinks to `~/.agent-customizations/review-queue`.

## Safety

- Never approve, comment on, or edit an MR unless Daiego asks for that exact action in this conversation. A "can approve" verdict on the page is not approval.
- When Daiego asks to approve, use `glab mr approve <iid> --sha <reviewed head sha>`. That fails when the head moved after the review. Report each MR that fails, with the error.
- Review runs are read-only on GitLab. `review_prompt.md` forbids writes. The Claude runner also denies common `glab` write commands. The Pi runner relies on the prompt alone.

## Rules for every review

- The MR description on the page always comes from the **read-mr** skill.
- A review always follows the **review-mr** skill. It writes `~/Code/.claude/code-reviews/MR-<iid>-review.md`.
- After review-mr, every review runs **two independent adversarial reviews** in parallel against the exact head sha and merge base. This is the same step 4 as in `/create-mr`. One reviewer covers correctness, edge cases, error handling, security, data integrity, concurrency and backward compatibility. The other covers requirement gaps, conventions, reuse, API and schema contracts, migration and rollout safety, and regression coverage. Claude runs them as Agent subagents, and Pi uses the `adversarial-reviewer` agent. The run then checks every finding against the code and marks it confirmed, plausible or rejected. Confirmed critical findings count as new critical issues. The full outputs go to `queue/adversarial/MR-<iid>-correctness.md` and `MR-<iid>-contracts.md`.
- Every review triages **every unresolved comment thread**: CodeRabbit, Wall-E and people. The run checks each thread against the head code, not against the thread's own claims. It gives each thread one verdict: `fix` (real and worth changing in this MR), `follow_up` (real, but pre-existing or out of scope), `already_fixed` (the head fixes it, so resolve it), `not_valid` (the code or a test disproves it, with a one-line reason to reply with), or `optional`. An unresolved critical `fix` blocks the verdict. The page shows only critical `fix` threads.
- Every review checks **feature gating** (step 3a of review-mr). A fix or change for a gated feature (a feature toggle, an experimental directory, or a record type that exists only behind a toggle, such as lead triggers behind `LeadAutoAgents`) must not change behavior for users or organizations outside the gate. Each leak is a critical finding and makes `can_approve` false.
- Every review runs the deterministic `walle-review-risk` skill against the exact MR head and target-branch policy. The result is private queue metadata. It does not change the approval verdict, the MR description, or anything on GitLab. When the classifier or target policy is unavailable, the page shows that result instead of guessing.
- The page shows only critical issues with status New. Already flagged and fixed items are listed separately.
- `scripts/review_one.py` enforces these rules through `review_prompt.md`. Do not review an MR another way for this page.

## Files

| Path | What it is |
| --- | --- |
| `scripts/fetch_queue.py` | Lists the open MRs where Daiego is a reviewer (`reviewer`), that Daiego authored (`mine`), or that a teammate authored (`team`), with CI, readiness, approvals and team review activity. Writes `queue.json`. Each MR lists its sources. |
| `scripts/review_one.py <iid>` | Runs one unattended review with `claude -p` (default) or `pi -p` (`--runner pi`), runs the private Wall-E risk classifier, writes `results/<iid>.json`, and re-renders the static page. |
| `scripts/serve.py` | Serves the page at `http://127.0.0.1:8787` with working review and refresh buttons. Runs at most 3 reviews at once (`--parallel`). Every 20 minutes (`--interval-minutes`, 0 turns it off) it refreshes the queue and reviews what is missing or stale. |
| `scripts/launchd.py install\|uninstall\|status` | Runs `serve.py` as the launchd agent `com.daiego.review-queue`. `KeepAlive` restarts it after a crash or a reboot. |
| `scripts/render.py` | Writes the static page. Its review buttons only copy the `review_one.py` command. |
| `scripts/queue_lib.py` | Shared paths and data loading. |
| `review_prompt.md` | The prompt each review run gets: read-mr, then review-mr, then the two adversarial reviews, then the result JSON. |
| `app.html` | The page template. |

Data lives in `~/Code/.claude/code-reviews/queue/` (`queue.json`, `results/`, `logs/`, `adversarial/`, `daemon.log`). The static page is `~/Code/.claude/code-reviews/mr-review-queue.html`.

## Schedule

The launchd agent keeps the server up and runs one cycle every 20 minutes:

1. Refresh the queue with `fetch_queue.py`.
2. Start a review for each MR that has no result, or a result for an older head, when the MR is one of these:
   - Daiego's own MR. Every new head gets a review.
   - An MR with Daiego as reviewer that Daiego has not approved.
   - A teammate's MR that nobody started reviewing: no teammate left a note or approved, and Daiego did not either. Once someone starts, the cycle stops reviewing its new heads. A teammate MR that is not assigned to Daiego is in the queue only when it was updated in the last 14 days (`fetch_queue.py --team-max-age-days`), because teammates keep many abandoned MRs open.

   The cycle skips drafts (`--review-drafts` includes them) and an MR whose last automatic review failed on the same head. Teammate MRs that someone already started stay on the page, but they get a review only from the button.

```bash
RQ=~/.agent-customizations/review-queue/scripts
/opt/homebrew/bin/python3 -I $RQ/launchd.py status      # agent loaded, last cycle, next cycle, running reviews
/opt/homebrew/bin/python3 -I $RQ/launchd.py install     # write the plist and start it; --interval-minutes to change
/opt/homebrew/bin/python3 -I $RQ/launchd.py uninstall   # stop the agent, keep the data
```

Each cycle writes one line to `daemon.log`. Each automatic review is a `claude -p` run of about 10 to 30 minutes, because the two adversarial reviewers run after review-mr. A run times out after 75 minutes. A busy queue uses Claude usage on every cycle that finds new heads, and each push to one of Daiego's MRs costs one full review.

## Workflow

1. Refresh the queue. Run the command from any directory:

   ```bash
   python3 -I ~/.agent-customizations/review-queue/scripts/fetch_queue.py
   ```

   It prints one line per MR. A teammate "started" a review when they left a note or approved and are not the author. The default team is `urvesh.patel1,acwang,shiva.eve`. Change it with `--team a,b,c`. `NEEDS REVIEW` means no teammate started and Daiego has not approved.

2. The launchd agent normally runs the server. If `launchd.py status` shows it is not loaded, run `launchd.py install`. To run the server by hand instead, start it in the background, unless `curl -s http://127.0.0.1:8787/api/jobs` already answers:

   ```bash
   python3 -I ~/.agent-customizations/review-queue/scripts/serve.py
   ```

   Then open `http://127.0.0.1:8787` for Daiego (`open http://127.0.0.1:8787` on macOS).

3. Review what is missing or stale. An MR needs a review run when it has no result, or when its result's `head_sha` does not match the live head (the page shows `Review stale`). Skip MRs Daiego approved, unless Daiego asks. Start runs from the page button, or through the API:

   ```bash
   TOKEN=$(curl -s http://127.0.0.1:8787/ | python3 -c "import sys,re,json; s=sys.stdin.read(); print(json.loads(re.search(r'const BOOT = (.*);\nlet DATA', s).group(1))['server']['token'])")
   curl -s -X POST -H "X-Token: $TOKEN" -H "Content-Type: application/json" -d '{"iid": 12345}' http://127.0.0.1:8787/api/review
   ```

   Without the server, run `python3 -I ~/.agent-customizations/review-queue/scripts/review_one.py <iid>`. A review takes 5 to 15 minutes. Wait for completion with a background loop on `/api/jobs`, not with repeated sleeps.

4. Check each new critical finding that is cheap to verify (for example a migration parent, or a claim about master) before you report it.

5. Report. Lead with the MRs that need review. For Daiego's own MRs, report the Wall-E risk result, confirmed critical adversarial findings, and critical threads with verdict `fix`. Mention `already_fixed` threads that can be resolved, and `not_valid` threads with their one-line reply. Then list the MRs Daiego can approve and the MRs Daiego cannot approve, each with a one-line reason. Give the page URL. Do not offer to post anything.

## The page

- Two tabs. **To review** holds MRs assigned to Daiego and teammates' MRs. A teammate MR that is not assigned to Daiego shows a "Team MR, not assigned to you" pill. **My MRs** holds Daiego's own MRs. There the verdict reads "Ready for approval" or "Fix first", and the team pill says whether a teammate started reviewing. The page remembers the tab.
- Stats cards (per tab): need review, can approve, don't approve yet, not reviewed, new critical findings. A click on a card filters by it. The counts follow the search, author, CI, and hide filters.
- Filters: text search, sort (review urgency, oldest, recently updated, author, MR number), author, state, CI, "hide MRs you approved", and "hide drafts". The page keeps the filters per browser.
- Each row shows team review state, CI state with a link to the pipeline, draft and conflict flags, the private Wall-E risk result, the new critical count, the verdict, whether the adversarial passes completed, the urgency score, and a Start review / Re-review button. The My MRs tab also has this button so Daiego can assess a new MR immediately. A review from before the adversarial step shows "No adversarial pass".
- The side panel shows the verdict, CI with the failed job names, merge state, approvals, the stack, the urgency breakdown, the private Wall-E risk result, the read-mr summary, and new critical findings with a copyable comment. It also shows that the adversarial passes completed, but not their non-critical observations. The audit files retain their full output. The panel shows only open critical comment threads, already-flagged critical items, the full review-mr file, and the run log.

Urgency score: +40 when no teammate started, +20 when the MR is not a draft and has green CI and no conflicts, +10 when it was never reviewed here, +10 when the review is stale, +10 when it has new critical findings, +1 per day open (at most 14), −30 for a draft, −10 when stacked on an open MR, −10 for failed CI. MRs Daiego approved sort last.

## Troubleshooting

- `Credit balance is too low` in a log: the child `claude` used an API key. `review_one.py` removes `ANTHROPIC_API_KEY` from the child environment so that `claude -p` uses the claude.ai login. If it still fails, run `claude -p "ok"` with the variable unset to check the login.
- Port 8787 in use: pass `--port` to `serve.py`. A server started by hand conflicts with the launchd agent. Stop one of them.
- The agent restarts in a loop: read `~/Code/.claude/code-reviews/queue/daemon.log`. A missing `glab` or `claude` means the plist `PATH` lacks its directory.
- `JSONDecodeError` when you read `/api/jobs` or `/api/data` with `curl`: the `rtk` hook rewrites `curl` output. Read JSON with `python3 -c "import json,urllib.request; print(json.load(urllib.request.urlopen('http://127.0.0.1:8787/api/jobs')))"`.
- A run fails with "no new result file": read `~/Code/.claude/code-reviews/queue/logs/<iid>.log`.
