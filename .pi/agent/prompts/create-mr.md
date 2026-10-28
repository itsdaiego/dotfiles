---
description: Verify completed work with two adversarial reviews, prepare evidence, and create a merge request
argument-hint: "[target branch or extra context]"
---

Create a merge request for the completed work in the current repository.

Requested target or context: ${@:-none; infer the remote default branch}

Follow this workflow in order.

1. Read all repository instructions that apply to the changed files. Inspect the branch, worktree status, remote default branch, commits, target-to-HEAD diff, and any existing merge request for this branch. Do not create a duplicate merge request. Stop if the current branch is the target branch, the repository is in detached HEAD state, or unrelated changes make the merge request scope unsafe.
2. Finish the branch before review. Include only the intended work. Run the repository's required checks. Create the smallest logical commit or commits needed for this merge request. This `/create-mr` request authorizes those commits, but it does not authorize unrelated changes. Follow every repository rule for staging, verification, atomic-commit assessment, and commit messages.
3. Gather concrete evidence when the change allows it. Prefer observable before-and-after behavior, exact test results, sanitized request and response examples, or a representative input and output JSON example. For user-interface changes, capture a screenshot with the available browser tooling when the application can run. Store generated evidence outside the repository unless the repository explicitly requires fixtures or documentation. Never include secrets, credentials, private customer data, or fabricated evidence.
4. Run two independent adversarial reviews in parallel with the `subagent` tool. Use the user-level `adversarial-reviewer` agent for both tasks and give each reviewer the target branch, repository path, and exact committed HEAD SHA.
   - Reviewer one must focus on correctness, edge cases, error handling, security, data integrity, concurrency, and backward compatibility.
   - Reviewer two must focus on requirement gaps, repository conventions, reuse, API or schema contracts, migration and rollout safety, and whether the tests would catch plausible regressions.
   Tell both reviewers to inspect the exact merge diff and return findings with file and line evidence. Keep their full outputs in temporary files named for the branch, and summarize them for the user. Do not post these reviews to GitLab.
5. Validate each finding against the code. Fix confirmed blocking or high-confidence findings, rerun the required checks, and commit the fixes. If the reviewed commit changed, run both adversarial reviews once more against the new HEAD. Stop before publication when a confirmed blocking finding remains. Do not dismiss a finding only to keep the workflow moving.
6. After the implementation, checks, evidence, and final reviews are complete, load and apply the `write-mr` skill. Draft a Conventional Commit title and a complete merge request description from the final diff and commits. Add an `## Evidence` section when evidence exists. Embed sanitized text examples directly. Mark where each useful screenshot will appear after GitLab provides its upload Markdown. If useful evidence cannot be produced, say why in the draft instead of inventing it.
7. Show the user the source branch, target branch, commits, check results, both review verdicts, proposed title, full description, and evidence. Ask for confirmation before pushing or creating the merge request. This pause gives the user an opportunity to review the publication. Do not push, upload evidence, or create or update the merge request until the user confirms.
8. After confirmation, push the branch without force. Upload approved screenshots to the GitLab project, replace the draft placeholders with the returned Markdown, and create the merge request with `glab`. Verify the published title, description, target branch, source branch, and URL. If a merge request already exists for the branch, update that merge request after confirmation instead of creating another one. Never publish the adversarial review comments unless the user separately asks.
9. Report the merge request URL, final HEAD SHA, checks, review outcomes, and included evidence. Follow the repository's change-location and local-branch-audit rules before the final response.

Do not weaken tests, bypass hooks, use `--no-verify`, force-push, hide failed checks, or claim evidence that you did not observe.
