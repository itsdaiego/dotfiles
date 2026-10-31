---
name: walle-review-risk
description: Assess a Butler merge request or working tree with Wall-E's agent-owned review policy, then state whether it needs, should get, or does not need more review. Use for every Butler MR review or review-triage request.
---

# Wall-E review risk

Use this skill for every Butler merge-request review, audit, or triage, including when another review skill is used. It assesses the exact change that Wall-E would review. It does not call Slack or GitLab APIs, change labels, create a sandbox, or publish anything.

## Policy boundary

This policy belongs to Wall-E. It must not be read from, copied into, or shipped with a Butler repository. Do not look for `.gitlab/risk-tiers.toml`, `tools.risk_tier`, GitLab labels, or another repository file to decide the risk.

Use the policy below with the MR context. State the specific evidence that caused the result. If the context is incomplete, report the uncertainty instead of inventing a deterministic result.

## Gather MR context

For a GitLab MR, read the exact source and target revisions, changed paths, diff, test changes, current pipeline state, and existing review discussion. Use read-only GitLab or Git commands. For a working tree, inspect the committed diff and clearly say whether unstaged or untracked work is included.

Pass that context to the assessment. Do not rely on a path-only classifier: paths identify likely impact, while the diff determines whether the change actually creates the risk.

## Wall-E policy

Assess risk from the highest applicable impact:

- **High:** authentication, authorization, secrets, payments, destructive data operations, database migrations, tenant isolation, public API compatibility, production deployment controls, or an unbounded change with no credible verification.
- **Medium:** shared business behavior, background jobs or alert delivery, integration/provider handling, data selection or persistence, infrastructure changes, generated client or DTO contracts, or a change whose tests do not cover its main failure mode.
- **Low:** isolated tests, documentation, local tooling, narrowly scoped presentation-only code, or mechanical refactors that preserve behavior and have adequate verification.

Raise the result when the diff combines several medium-impact areas, touches a broad fan-out point, or leaves a realistic regression path untested. Lower it only when the complete diff and verification show that the higher-risk concern does not apply. Never treat a file path alone as proof of risk.

## Review attention

After the risk assessment, give the user a review-attention label and one short reason. This label is a review queue aid, not a GitLab label or an approval verdict.

- **Needs review:** Wall-E finds high risk, cannot inspect the exact head, a required check failed, or the review found a confirmed critical issue.
- **Should review:** Wall-E finds medium risk, or the review found a credible non-critical concern, shared behavior change, or meaningful coverage gap.
- **Don't need review:** Wall-E reports low risk, CI and merge state are not concerning, and the review found no confirmed issue. Do not assign this label from a low policy tier alone.

The reviewer may raise attention based on evidence from the review. An unknown or incomplete result is always **Needs review**.

## Report

State:

- The low, medium, or high result. Do not use Tier A, B, or C in user-facing reports.
- The policy version: `Wall-E agent policy v1`.
- The changed areas and the diff evidence that raised the result.
- The MR revisions or working-tree scope that were reviewed.
- Any uncertainty that affects the result.
- The review-attention label and a short, concrete reason.

Treat an unknown or incomplete assessment as requiring human review. Do not recommend skipping review from a low result alone.
