---
name: fix-mr
description: >-
  Fix an existing GitLab MR or GitHub PR end to end. Use when the user asks to
  fix an MR, address review feedback, make an MR merge-ready, resolve its
  conflicts or CI, rebase it, push the fixes, or get an approved MR merged.
---

# Fix an MR end to end

Own the specified MR until it is merge-ready. Work proactively. Do not stop after finding a problem when you can safely fix it.

Invoking this skill for a specific MR authorizes the ordinary publication steps for that MR: create focused commits, push them, update the MR, safely force-push after a required rebase, resolve addressed discussions, rerun CI, request re-review, and enable auto-merge when the current head is approved. It does not authorize approving the MR yourself, publishing optional review suggestions, modifying deployed systems, using production customer data, or bypassing a required safety confirmation.

## 1. Establish the exact state

1. Read every applicable `AGENTS.md` and load the skills required by those rules.
2. Resolve the MR, repository, source branch, target branch, author, current head SHA, approvals, requested changes, unresolved discussions, conflicts, pipeline, dependencies, and auto-merge state.
3. Read the complete human and bot feedback. Inspect the diff and relevant code. Treat human-requested correctness fixes and confirmed important bot findings as required. Do not spend time on style-only or speculative bot comments.
4. For Butler changes, run `review-risk`, including its deterministic policy, TypeSafe Jev signal, and blast-radius check.
5. Use one dedicated writable worktree per MR. For Butler Intake work, use the actual Linear ticket ID in the branch and worktree name. Never edit the primary checkout.
6. Inspect existing dirty work before changing it. Preserve useful work. Back up tracked and untracked state before any rebase, reset, worktree move, or other operation that can make recovery difficult.

## 2. Rebase and resolve conflicts proactively

Fetch the target branch early. Rebase when the MR is behind, conflicted, stacked on a merged parent, or when the target changed materially.

Before rebasing, identify which commits belong to this MR. Do not blindly replay an inherited stack. If a parent MR was squash-merged, transplant only this MR's own commits onto the current target with `git rebase --onto`, then confirm equivalence with `git range-diff` and the final target-to-head diff.

Resolve conflicts from the intended behavior, current target code, tests, and review feedback. Do not choose `ours` or `theirs` without inspecting both sides. Preserve unrelated target-branch changes.

Use `--force-with-lease` only when a rebase changed published history. Read the remote source SHA immediately before pushing and lease against that exact SHA. Never use an unleased force-push.

## 3. Fix the behavior

Use red → green → refactor for every behavior fix:

1. Add or update a focused automated test.
2. Run it and confirm the expected failure.
3. Make the smallest production change that passes.
4. Refactor only while tests stay green.

Cover the actual review concern, its ordinary edge cases, and regressions introduced by conflict resolution. Keep feature-gated behavior inside its gate. Preserve API, generated DTO, database, and rollout contracts unless the requested fix intentionally changes them.

Use synthetic or local data. Never use production customer data, credentials, or endpoints for verification.

## 4. Verify and review the exact result

Run focused tests first, then the repository's required verification. Run code generation only when a source contract changed. Do not hide or bypass failures. Follow repository-specific blocked-command rules.

Inspect:

- the final target-to-head diff;
- the working and staged diffs;
- commit scope and messages;
- `git diff --check`;
- feature gates and compatibility;
- security, tenant isolation, data integrity, concurrency, retry safety, and error handling where relevant.

Fix every confirmed critical or important issue. Use at most 2 adversarial review rounds. Follow `adversarial-review-stop` when repeated review is requested.

Before the first publication, give a short checkpoint with the outcome, changed behavior, tests, risk, and any known limitation. Continue without asking another routine confirmation because the user invoked this skill for end-to-end publication. Stop only for a product decision, unsafe ambiguity, missing access, a required external approval, or a destructive/deployed-system action.

## 5. Commit and publish

Make small atomic commits. Before each commit, inspect the staged diff, state its one outcome and verification, and run `assess_atomic_commit` when the harness provides it. Never include unrelated changes.

Push the tested head. After every push, verify that GitLab or GitHub reports the expected SHA. Re-check approvals because a push or rebase can reset them.

Update the MR description when the final behavior, scope, evidence, rollout, or testing differs from the published description. Preserve correct existing facts. Add sanitized visual or manual evidence when available.

Reply to or resolve only discussions that the new head actually addresses. Do not mark an unresolved concern resolved. When review was requested, wait for the current-head pipeline to start, then ask the reviewer for re-review with a concise summary of the fixes and verification.

## 6. Drive CI and merge state

Watch the current-head pipeline through completion. A stale pipeline does not count.

- If a job fails because of this MR, inspect its logs, reproduce it locally where practical, fix it with a test, verify, and publish again.
- If the failure is clearly flaky or unrelated, retry the minimum affected job or pipeline and record the evidence.
- If the source conflicts again, rebase and repeat the required verification.
- Do not claim merge-ready while CI, conflicts, required approvals, or blocking discussions remain unknown.

If the current head is approved, enable auto-merge. This applies even while its current pipeline is running. Verify that auto-merge remains enabled after the final push. Never approve the MR yourself unless the user explicitly asks to approve that exact MR in the current conversation.

If approval is missing or requested changes remain, keep auto-merge off unless the user explicitly asked for it, request re-review after current CI is available, and report the exact remaining gate.

## 7. Finish with facts

Report:

- MR link, title, and author;
- final head SHA and target branch;
- fixes made;
- tests and CI result;
- conflict, discussion, approval, and auto-merge state;
- review-risk result and reason;
- exact worktree and branch;
- anything still blocking merge.

Do not say the MR is ready when the published head, current CI, or approval state is stale or unknown.
