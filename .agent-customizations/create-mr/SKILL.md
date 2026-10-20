---
name: create-mr
description: Prepare, review, and publish a GitLab merge request. Use when the user asks to create an MR or runs /create-mr.
---

# Create a merge request

Create an MR only after the branch is complete, verified, independently reviewed, and the user has approved publication.

1. Read every applicable `AGENTS.md`. Inspect the worktree, branch, remote default branch, target-to-HEAD diff, branch commits, and existing MRs for the source branch. Stop if the branch is the target, HEAD is detached, or unrelated changes make the scope unsafe. Do not create a duplicate MR.
2. Finish only the requested work. Inspect the unstaged diff before staging. Run the required checks. Make small, atomic Conventional Commit commits only when the user requested MR creation. Before each commit, inspect the staged diff and state its single outcome and verification. Do not bypass hooks or weaken tests.
3. Capture observable evidence when possible. Use actual test output, sanitized request/response examples, or a UI screenshot. Keep generated evidence outside the repository unless repository rules require it. Never fabricate evidence or expose secrets or customer data.
4. Run two independent adversarial reviews in parallel against the exact committed SHA and target branch. Give both reviewers the repository path, target branch, and SHA. Ask reviewer one to focus on correctness, edge cases, error handling, security, integrity, concurrency, and compatibility. Ask reviewer two to focus on requirement gaps, conventions, reuse, API/schema contracts, migration and rollout safety, and regression coverage. Save each complete review in a temporary file named for the source branch. Do not publish review comments.
5. Validate every finding. Fix confirmed blocking or high-confidence findings, rerun the required checks, and commit the fix. If HEAD changes, repeat both reviews against the new SHA. Stop if a blocking finding remains.
6. Load the `write-mr` skill. Draft a Conventional Commit title and a complete description from the final diff and commits. Include `## Evidence` when evidence exists. Embed sanitized text examples. Mark screenshot upload placeholders clearly. If evidence cannot be produced, say why.
7. Before publication, show the source and target branches, commits, checks, review outcomes, title, full description, and evidence. Ask for confirmation. Do not push, upload, create, or update an MR before explicit confirmation.
8. After confirmation, push without force. Upload approved screenshots if needed, replace placeholders with the returned GitLab Markdown, then create the MR with `glab`. If the source branch already has an MR, update it instead. Verify the published title, description, target, source, and URL.
9. Report the MR URL, final SHA, checks, reviews, and evidence. Follow the repository rules for change-location reporting and branch cleanup.

Never force-push, use `--no-verify`, hide failed checks, post adversarial reviews, or claim unobserved evidence.
