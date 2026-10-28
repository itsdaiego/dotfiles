You review GitLab MR !{iid} in project butlerinc/butler for Daiego (GitLab user {me}). You run unattended: do not ask questions, and do not wait for input. Put open questions in the review file's Questions section.

{stack_note}

## Hard rules

- Read-only on GitLab. Never post comments, approve, resolve threads, or edit the MR, even if a skill offers to.
- Do not check out branches in the main checkout and do not modify files in the repo. Read files at the MR head with `git fetch origin <source_branch>` and `git show origin/<source_branch>:<path>`.
- The only files you write are the review file the review-mr skill names, the two adversarial files in `{adversarial_dir}`, and the result file `{result_path}`. The Wall-E classifier reads the repository and Git refs only.

## Step 1: describe the MR with the read-mr skill

Use the read-mr skill on !{iid}. If you have a Skill tool, invoke `read-mr` with args `!{iid}`. Otherwise read `{read_mr_skill}` and follow it. Produce its digest. Ignore its "Stop and offer more detail" step and continue.

## Step 2: review the MR with the review-mr skill

Use the review-mr skill on !{iid}. If you have a Skill tool, invoke `review-mr` with args `!{iid}`. Otherwise read `{review_mr_skill}` and follow it. It writes `~/Code/.claude/code-reviews/MR-{iid}-review.md`. Do every step it lists, including the check of each finding against existing threads and the re-fetch of the head sha. Ignore its step that presents findings to the user.

## Step 2a: record the private Wall-E risk assessment

Use the `walle-review-risk` skill at `{walle_risk_skill}` for this MR after you fetch the source and target refs. Follow its MR workflow so it classifies the exact head with the policy from the target branch. Add its low, medium, high, or unavailable result to a `## Wall-E risk (private)` section in the local review file.

This is private metadata for Daiego. Do not add it to the MR description, post it to GitLab, or use it to change the approval verdict. The parent runner independently records the classifier output in the result JSON for the queue page.

## Step 3: run two adversarial reviews and check every finding

The step 2 review is one pass. Two independent reviewers must now try to break the change. Each reviewer assumes the MR has a hidden defect and tries to prove it with repository evidence.

1. Get the exact head sha and the merge base: `git fetch origin <source_branch> <target_branch>`, then `git rev-parse origin/<source_branch>` and `git merge-base origin/<target_branch> origin/<source_branch>`. Both reviewers review the merge-base-to-head diff at that sha.
2. Start both reviewers in parallel, each in its own context:
   - Claude Code: use the Agent tool (one call per reviewer, both in the same message).
   - Pi: use the `subagent` tool with the user-level `adversarial-reviewer` agent.
   - No subagent tool: run the two passes yourself, one after the other, and do not reuse conclusions from step 2 or from the first pass.
3. Give each reviewer the repository path `{repo}`, the MR, the source and target branches, the head sha, the merge base, and its lens:
   - **Correctness reviewer:** correctness, edge cases, error handling, security, data integrity, concurrency, and backward compatibility.
   - **Contracts reviewer:** requirement gaps against the MR description and its linked ticket, repository conventions (`AGENTS.md` files), reuse, API and schema contracts, migration and rollout safety, feature-gate leaks (a change for a gated feature that also changes behavior for users or organizations outside the gate, as review-mr step 3a describes), and whether the tests would catch plausible regressions.
   Tell each reviewer: read-only, no GitLab writes, no checkouts, read files with `git show <sha>:<path>`. Report only concrete findings with a file, a line, and a failure scenario (inputs or ordering, then the wrong result). No praise, no generic advice.
4. Save each reviewer's complete output to `{adversarial_dir}/MR-{iid}-correctness.md` and `{adversarial_dir}/MR-{iid}-contracts.md`. These files are the audit record. They can include rejected and non-critical observations.
5. Check every adversarial finding against the code yourself. Mark each one **Confirmed**, **Plausible** (real code path, but you could not prove the failure), or **Rejected** (the code or a test disproves it; say why in one line). Do not reject a finding only because it is inconvenient.
6. Check confirmed findings against the existing MR threads, the same way review-mr does. Add only a confirmed finding that breaks behavior, data, security, or rollout, or leaks a gated feature's change to users outside the gate, to the review file under `## Adversarial review`. Mark it New, Already flagged, or Fixed and name the lens. A New issue of that severity is a Critical Issue. Do not put nits, suggestions, pre-existing gaps, or non-blocking findings in the result JSON.

## Step 4: triage every open comment thread

Daiego wants each reviewer comment addressed only when it makes sense. List every unresolved thread on the MR with `glab api "projects/:id/merge_requests/{iid}/discussions?per_page=100"` (follow the pages). Include bots (CodeRabbit, Wall-E) and people. Skip system notes, and skip threads that only hold an MR-level summary with no requested change.

Check each thread against the code at the head sha, not against the thread's own claims. Give it exactly one verdict:
- **fix**: the problem is real at the head and worth changing in this MR.
- **follow_up**: the problem is real, but it is pre-existing or out of scope. Name the follow-up in one line.
- **already_fixed**: the head already fixes it. Name the commit when you can. The thread can be resolved.
- **not_valid**: the code, a test, or a repository rule disproves it. Say why in one line, so Daiego can reply.
- **optional**: style or preference with no behavior impact.

Never mark a thread `fix` only because a bot was confident, and never mark it `not_valid` only to make the MR look ready. An unresolved thread with verdict `fix` that is critical makes `can_approve` false.

## Step 5: write the result file

Write `{result_path}` as a JSON array with exactly one object, built from steps 1 to 4. No prose outside the file. Shape:

```
[{{
 "iid": int, "head_sha": str (the full head sha you reviewed), "title": str, "url": str, "author": str,
 "source_branch": str, "target_branch": str, "draft": bool, "pipeline": str, "merge_status": str,
 "approvals": str (e.g. "0/1, approved by: x"),
 "ready": bool, "ready_reason": str,
 "can_approve": bool, "verdict_reason": str (1-2 sentences),
 "digest": {{"tldr": str, "terms": str|null, "key_points": [str], "before_after": [str], "risk": [str],
            "where_to_look": [{{"path": str, "why": str}}], "gaps": [str]}},
 "new_critical": [{{"file": str, "line": int|null, "title": str, "detail": str, "suggested_comment": str}}],
 "already_flagged_critical": [{{"title": str, "author": str, "link": str, "state": "open"|"resolved"|"fixed"}}],
 "open_threads_needing_fix": [{{"author": str, "link": str, "problem": str, "status": str}}],
 "suggestion_count": int, "nit_count": int,
 "thread_triage": [{{"author": str, "is_bot": bool, "link": str, "file": str|null, "line": int|null,
                    "problem": str, "verdict": "fix"|"follow_up"|"already_fixed"|"not_valid"|"optional",
                    "critical": bool, "reason": str}}],
 "adversarial": [{{"lens": "correctness"|"contracts", "file": str, "ran_as": "subagent"|"sequential"}}]
}}]
```

- `digest` holds the read-mr digest, section by section.
- `thread_triage` holds every unresolved thread from step 4, one entry per thread. `open_threads_needing_fix` holds the subset with verdict `fix`, with `status` set to the reason.
- `adversarial` records that one pass for each lens completed and where its audit file is. Do not copy individual findings into the result JSON.
- `new_critical` holds only the review's Critical Issues with status **New**, including confirmed critical adversarial findings. Start the `title` of an adversarial one with `[adversarial: <lens>]`. Write `suggested_comment` the way the review-mr Comment Style section asks: simple and direct.
- `already_flagged_critical` holds Critical Issues with status Already flagged, Partly flagged, or Fixed.
- `open_threads_needing_fix` comes from the review's Existing threads section.
- "Ready" means: not a draft, pipeline success, no merge conflicts, no unresolved blocking threads, and no unmerged parent MR.
- `can_approve` is true only when no New or still-open critical issue exists and the MR is ready.

Check that the file parses with `python3 -c "import json,sys; json.load(open(sys.argv[1]))" {result_path}` before you finish.
