---
name: walle-review-risk
description: Classify a Butler branch or working tree with the deterministic risk policy intended for Wall-E GitLab MR labels. Use for /walle-review-risk or local MR-risk assessment.
---

# Wall-E review risk

Use this skill to preview the risk tier that Wall-E would assign to a Butler merge request. It runs locally only. It does not call Slack or GitLab APIs, change labels, create a sandbox, or publish anything.

The classifier is the source of truth. Do not replace its result with an LLM judgment. An LLM can explain the result or identify an additional concern, but it cannot lower the policy-derived tier.

## Run the classifier

From the Butler repository root, classify a committed head with the classifier from the target branch. Set `SKILL_DIR` to the directory containing this skill.

```bash
SKILL_DIR=/path/to/walle-review-risk
python3 "$SKILL_DIR/scripts/report.py" --target origin/master
```

Use `--head <ref>` to classify a fetched MR source ref. Use `--json` when a later command needs structured output. The authoritative Wall-E CLI classifies committed refs only; do not present an uncommitted working-tree preview as a Wall-E result.

When the request names a GitLab MR URL or IID, use read-only `glab mr view` to get its source and target branches. Fetch the source branch to `refs/walle-review-risk/mr-<iid>`, then classify that ref with `--head`. Do not create a worktree, edit the MR, add labels, or call a Slack endpoint.

Wall-E runs `python -m tools.risk_tier report` from a detached checkout of the target branch, so an MR cannot change the implementation or rules that classify itself. The wrapper follows the same trust boundary. If the target lacks `src/document_extractor/tools/risk_tier.py`, report that Wall-E would leave the MR unlabelled. Do not silently classify against the feature branch or substitute an LLM judgment.

## Report

State:

- The low, medium, or high result. Do not use Tier A, B, or C in user-facing reports.
- Every matched rule and changed path.
- Every content signal that raised the tier.
- The target implementation ref and that the report covers committed refs only.
- Any uncertainty that means Wall-E would not set a label.

Risk is the maximum of all matched paths and content signals. Treat an unknown or incomplete result as requiring human review. Do not recommend skipping review from a low tier alone.
