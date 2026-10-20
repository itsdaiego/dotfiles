You review GitLab MR !{iid} in project butlerinc/butler for Daiego (GitLab user {me}). You run unattended: do not ask questions, and do not wait for input. Put open questions in the review file's Questions section.

{stack_note}

## Hard rules

- Read-only on GitLab. Never post comments, approve, resolve threads, or edit the MR, even if a skill offers to.
- Do not check out branches in the main checkout and do not modify files in the repo. Read files at the MR head with `git fetch origin <source_branch>` and `git show origin/<source_branch>:<path>`.
- The only files you write are the review file the review-mr skill names and the result file `{result_path}`.

## Step 1: describe the MR with the read-mr skill

Use the read-mr skill on !{iid}. If you have a Skill tool, invoke `read-mr` with args `!{iid}`. Otherwise read `{read_mr_skill}` and follow it. Produce its digest. Ignore its "Stop and offer more detail" step and continue.

## Step 2: review the MR with the review-mr skill

Use the review-mr skill on !{iid}. If you have a Skill tool, invoke `review-mr` with args `!{iid}`. Otherwise read `{review_mr_skill}` and follow it. It writes `~/Code/.claude/code-reviews/MR-{iid}-review.md`. Do every step it lists, including the check of each finding against existing threads and the re-fetch of the head sha. Ignore its step that presents findings to the user.

## Step 3: write the result file

Write `{result_path}` as a JSON array with exactly one object, built from steps 1 and 2. No prose outside the file. Shape:

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
 "suggestion_count": int, "nit_count": int
}}]
```

- `digest` holds the read-mr digest, section by section.
- `new_critical` holds only the review's Critical Issues with status **New**. Write `suggested_comment` the way the review-mr Comment Style section asks: simple and direct.
- `already_flagged_critical` holds Critical Issues with status Already flagged, Partly flagged, or Fixed.
- `open_threads_needing_fix` comes from the review's Existing threads section.
- "Ready" means: not a draft, pipeline success, no merge conflicts, no unresolved blocking threads, and no unmerged parent MR.
- `can_approve` is true only when no New or still-open critical issue exists and the MR is ready.

Check that the file parses with `python3 -c "import json,sys; json.load(open(sys.argv[1]))" {result_path}` before you finish.
