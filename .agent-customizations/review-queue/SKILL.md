---
name: review-queue
description: >-
  Use when Daiego wants an overview of every GitLab MR where Daiego is a reviewer: "review my queue", "what MRs are assigned to me", "which MRs can I approve", "which MRs need review", "/review-queue". Opens a local page that lists each MR with its read-mr summary, CI state, team review state, review urgency, only the critical findings nobody flagged yet, and an approve / don't-approve verdict. A button on each MR starts an unattended review that follows the review-mr skill. Works in Claude Code and Pi. Read-only on GitLab unless Daiego explicitly asks to approve or comment.
---

# Review queue

A local page that covers every open MR where Daiego is a reviewer, so Daiego can decide where to spend review time before opening any MR. The same skill folder serves Claude Code (`~/.claude/skills/review-queue`) and Pi (`~/.pi/agent/skills/review-queue`). Both are symlinks to `~/.agent-customizations/review-queue`.

## Safety

- Never approve, comment on, or edit an MR unless Daiego asks for that exact action in this conversation. A "can approve" verdict on the page is not approval.
- When Daiego asks to approve, use `glab mr approve <iid> --sha <reviewed head sha>`. That fails when the head moved after the review. Report each MR that fails, with the error.
- Review runs are read-only on GitLab. `review_prompt.md` forbids writes. The Claude runner also denies common `glab` write commands. The Pi runner relies on the prompt alone.

## Rules for every review

- The MR description on the page always comes from the **read-mr** skill.
- A review always follows the **review-mr** skill. It writes `~/Code/.claude/code-reviews/MR-<iid>-review.md`.
- The page shows only critical issues with status New. Already flagged and fixed items are listed separately.
- `scripts/review_one.py` enforces both rules through `review_prompt.md`. Do not review an MR another way for this page.

## Files

| Path | What it is |
| --- | --- |
| `scripts/fetch_queue.py` | Lists the MRs where Daiego is a reviewer, with CI, readiness, approvals and team review activity. Writes `queue.json`. |
| `scripts/review_one.py <iid>` | Runs one unattended review with `claude -p` (default) or `pi -p` (`--runner pi`), writes `results/<iid>.json`, re-renders the static page. |
| `scripts/serve.py` | Serves the page at `http://127.0.0.1:8787` with working review and refresh buttons. Runs at most 3 reviews at once (`--parallel`). Every 20 minutes (`--interval-minutes`, 0 turns it off) it refreshes the queue and reviews what is missing or stale. |
| `scripts/launchd.py install\|uninstall\|status` | Runs `serve.py` as the launchd agent `com.daiego.review-queue`. `KeepAlive` restarts it after a crash or a reboot. |
| `scripts/render.py` | Writes the static page. Its review buttons only copy the `review_one.py` command. |
| `scripts/queue_lib.py` | Shared paths and data loading. |
| `review_prompt.md` | The prompt each review run gets: read-mr, then review-mr, then the result JSON. |
| `app.html` | The page template. |

Data lives in `~/Code/.claude/code-reviews/queue/` (`queue.json`, `results/`, `logs/`, `daemon.log`). The static page is `~/Code/.claude/code-reviews/mr-review-queue.html`.

## Schedule

The launchd agent keeps the server up and runs one cycle every 20 minutes:

1. Refresh the queue with `fetch_queue.py`.
2. Start a review for each MR that has no result, or a result for an older head. The cycle skips MRs Daiego approved, drafts (`--review-drafts` includes them), and an MR whose last automatic review failed on the same head.

```bash
RQ=~/.agent-customizations/review-queue/scripts
/opt/homebrew/bin/python3 -I $RQ/launchd.py status      # agent loaded, last cycle, next cycle, running reviews
/opt/homebrew/bin/python3 -I $RQ/launchd.py install     # write the plist and start it; --interval-minutes to change
/opt/homebrew/bin/python3 -I $RQ/launchd.py uninstall   # stop the agent, keep the data
```

Each cycle writes one line to `daemon.log`. Each automatic review is a `claude -p` run of 5 to 15 minutes, so a busy queue uses Claude usage on every cycle that finds new heads.

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

5. Report. Lead with the MRs that need review. Then list the MRs Daiego can approve and the MRs Daiego cannot approve, each with a one-line reason. Give the page URL. Do not offer to post anything.

## The page

- Stats cards: need review, can approve, don't approve yet, not reviewed, new critical findings. A click on a card filters by it.
- Filters: text search, sort (review urgency, oldest, recently updated, author, MR number), author, state, CI, and "hide MRs you approved". The page keeps the filters per browser.
- Each row shows team review state, CI state with a link to the pipeline, draft and conflict flags, the new critical count, the verdict, the urgency score, and a Start review / Re-review button.
- The side panel shows the verdict, CI with the failed job names, merge state, approvals, the stack, the urgency breakdown, the read-mr summary, the new critical findings with a copyable comment, the already-flagged items, the open threads, the full review-mr file, and the run log.

Urgency score: +40 when no teammate started, +20 when the MR is not a draft and has green CI and no conflicts, +10 when it was never reviewed here, +10 when the review is stale, +10 when it has new critical findings, +1 per day open (at most 14), −30 for a draft, −10 when stacked on an open MR, −10 for failed CI. MRs Daiego approved sort last.

## Troubleshooting

- `Credit balance is too low` in a log: the child `claude` used an API key. `review_one.py` removes `ANTHROPIC_API_KEY` from the child environment so that `claude -p` uses the claude.ai login. If it still fails, run `claude -p "ok"` with the variable unset to check the login.
- Port 8787 in use: pass `--port` to `serve.py`. A server started by hand conflicts with the launchd agent. Stop one of them.
- The agent restarts in a loop: read `~/Code/.claude/code-reviews/queue/daemon.log`. A missing `glab` or `claude` means the plist `PATH` lacks its directory.
- `JSONDecodeError` when you read `/api/jobs` or `/api/data` with `curl`: the `rtk` hook rewrites `curl` output. Read JSON with `python3 -c "import json,urllib.request; print(json.load(urllib.request.urlopen('http://127.0.0.1:8787/api/jobs')))"`.
- A run fails with "no new result file": read `~/Code/.claude/code-reviews/queue/logs/<iid>.log`.
