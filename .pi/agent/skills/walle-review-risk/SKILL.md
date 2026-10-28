---
name: walle-review-risk
description: Classify a Butler branch or working tree with the deterministic risk policy intended for Wall-E GitLab MR labels. Use for /walle-review-risk or local MR-risk assessment.
---

# Wall-E review risk

Use this skill to preview the risk tier that Wall-E would assign to a Butler merge request. It runs locally only. It does not call Slack or GitLab APIs, change labels, create a sandbox, or publish anything.

The classifier is the source of truth. Do not replace its result with an LLM judgment. An LLM can explain the result or identify an additional concern, but it cannot lower the policy-derived tier.

## Run the classifier

From the Butler repository root, classify committed branch changes against the target branch policy:

```bash
PYTHONPATH=src/document_extractor python3 .claude/skills/walle-review-risk/scripts/report.py --target origin/master
```

Add `--working-tree` to include unstaged and untracked files. Use `--head <ref>` to classify a fetched MR source ref. Use `--policy-ref <ref>` only to preview an unmerged policy while keeping the real target branch for the diff. Use `--json` when a later command needs structured output.

When the request names a GitLab MR URL or IID, use read-only `glab mr view` to get its source and target branches. Fetch the source branch to `refs/walle-review-risk/mr-<iid>`, then classify that ref with `--head`. Do not create a worktree, edit the MR, add labels, or call a Slack endpoint.

Wall-E reads the policy from the target branch so an MR cannot change the rules that classify itself. The local command follows the same rule. If the chosen target lacks `.gitlab/risk-tiers.toml`, report that Wall-E would leave the MR unlabelled. Do not silently classify against the feature branch. A local-only preview can use `--policy-ref HEAD`, but clearly state that it does not have Wall-E's target-branch trust boundary.

## Report

State:

- The low, medium, or high result. Do not use Tier A, B, or C in user-facing reports.
- Every matched rule and changed path.
- Every content signal that raised the tier.
- The policy ref and whether the report includes the working tree.
- Any uncertainty that means Wall-E would not set a label.

Risk is the maximum of all matched paths and content signals. Treat an unknown or incomplete result as requiring human review. Do not recommend skipping review from a low tier alone.
