---
name: start-reviewer
description: Start, run, stop, or inspect Daiego's autonomous GitLab reviewer. Every 30 minutes it reviews assigned MRs nobody else started, approves clean exact heads, and publishes only confirmed critical findings.
---

# Start reviewer

Run a narrow autonomous review loop for Butler GitLab merge requests.

## Policy

Act only when all of these are true at action time:

- Daiego is an assigned reviewer.
- The MR is open and not a draft.
- Daiego has not approved the current head.
- No teammate has commented on or approved the MR.
- The review result matches the live head SHA.

Use the `review-queue` workflow to refresh candidates and the `review-mr` workflow to review each exact head. That workflow includes unresolved-thread triage, feature-gate checks, two adversarial passes, and the private Wall-E risk classifier.

After review:

- Approve with `glab mr approve <iid> --sha <reviewed-head-sha>` only when `can_approve` is true.
- When changes are required, publish only findings in `new_critical`. Do not publish suggestions, nits, questions, non-critical threads, or findings already raised on the MR.
- Create each inline comment as a draft with complete position data, then publish that draft individually. Never bulk-publish, because that could publish unrelated user drafts.
- Re-check the live head and reviewer activity immediately before every approval or published comment. If either changed, take no action and let a later cycle review the new state.
- If review output is missing, stale, uncertain, or malformed, take no GitLab action.

The runner records each approval and critical comment by MR head and finding fingerprint. Do not repeat a recorded action. It also checks existing GitLab notes before publishing so loss of local state does not create duplicate comments.

## Commands

Use the shared management script:

```bash
python3 -I ~/.agent-customizations/start-reviewer/scripts/manage.py install
python3 -I ~/.agent-customizations/start-reviewer/scripts/manage.py status
python3 -I ~/.agent-customizations/start-reviewer/scripts/manage.py run
python3 -I ~/.agent-customizations/start-reviewer/scripts/manage.py uninstall
```

`install` creates and loads `com.daiego.start-reviewer` with a 30-minute interval and runs one cycle immediately. `uninstall` removes the schedule but keeps logs and action state.

Logs and state live in `~/Code/.claude/code-reviews/start-reviewer/`. Full review files remain in `~/Code/.claude/code-reviews/`.

Installing, uninstalling, approving, or publishing comments changes external or local state. Perform those operations only when Daiego explicitly asks. A request to start the autonomous reviewer authorizes its future scheduled approvals and critical-only comments until the schedule is stopped.
