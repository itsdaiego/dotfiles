---
name: adversarial-review-stop
description: Control repeated adversarial review loops. Use when a task asks for multiple adversarial reviews, review-after-fix cycles, or continued review until no new issues remain.
---

# Adversarial review stop rule

Use this rule whenever adversarial review finds an issue.

1. Keep a short ledger of each finding: severity, root cause, affected path, and whether it is new or a duplicate.
2. Run at most two adversarial review rounds for one MR, including any rerun after a fix. A round can include independent reviewers in parallel. Count the round, not the reviewers.
3. After round two, fix every accepted finding and run focused verification. Do not start a third adversarial review, even when that fix changes HEAD.
4. Report the number of unique findings, the rounds used, and the verification after the final fix. Separate any known pre-existing issue from issues introduced by the change.

Do not keep expanding scope into a new architecture project unless the user explicitly asks. A durable outbox, schema redesign, or broad refactor is a separate follow-up when a bounded fix has already addressed the requested change.
