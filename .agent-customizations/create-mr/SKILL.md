---
name: create-mr
description: Prepare, review, and publish a GitLab merge request. Use when the user asks to create an MR or runs /create-mr.
---

# Create a merge request

Create an MR only after the branch is complete, verified, independently reviewed, and the user has approved publication.

1. Read every applicable `AGENTS.md`. Inspect the worktree, branch, remote default branch, target-to-HEAD diff, branch commits, and existing MRs for the source branch. Stop if the branch is the target, HEAD is detached, or unrelated changes make the scope unsafe. Do not create a duplicate MR.
2. Finish only the requested work. Inspect the unstaged diff before staging. Run the required checks. Make small, atomic Conventional Commit commits only when the user requested MR creation. Before each commit, inspect the staged diff and state its single outcome and verification. Do not bypass hooks or weaken tests.
   Check feature gating before the reviews. When the change touches a gated feature (a feature toggle, an experimental directory, or a record type that exists only behind a toggle, such as lead triggers behind `LeadAutoAgents`), every behavior change must stay inside the gate. Scope it to the gated path or check the toggle. Users and organizations outside the gate must see the same behavior as on the target branch. Follow step 3a of the `review-mr` skill. Fix each leak before you continue.
3. Capture observable evidence when possible. Use actual test output, sanitized request/response examples, or a UI screenshot. Keep generated evidence outside the repository unless repository rules require it. Never fabricate evidence or expose secrets or customer data.
4. Load the `review-mr` skill and use its review criteria. Run two independent adversarial reviews in parallel against the exact committed SHA and target branch. Give both reviewers the repository path, target branch, and SHA. Ask reviewer one to focus on correctness, error handling, security, data integrity, concurrency, and compatibility. Ask reviewer two to focus on requirement gaps, API and schema contracts, migration and rollout safety, feature-gate leaks (`review-mr` step 3a), and regression coverage. Save each complete review in a temporary file named for the source branch. Do not publish review comments.

   The adversarial reviews must report only critical or important findings:
   - A **critical** finding can cause a security or privacy breach, data loss, an outage, incorrect behavior on a supported path, a blocked deployment or rollback, a change that reaches users outside a feature gate, or a materially false MR description.
   - An **important** finding is a high-confidence defect that is likely on an ordinary supported path, a material contract or rollout flaw, or missing regression coverage that leaves critical behavior unprotected.
   - Do not report nits, style preferences, naming suggestions, optional refactors, theoretical edge cases, minor hardening, or other small asks. If a reviewer finds no critical or important issue, it must return `No critical or important findings.`
5. Validate every critical or important finding. Fix each confirmed finding, rerun the required checks, and commit the fix. Ignore findings that do not meet the threshold above. Use at most two adversarial review rounds per MR, including any review after a fix. If the first round changes HEAD, use the second and final round against the new SHA. After the second round, fix confirmed findings and verify the fix without starting a third round. Do not repeat reviews when HEAD changes only through a rebase or a merge commit that adds no new change of your own. Stop if a confirmed critical or important finding remains.
6. Load the `write-mr` skill. Draft a Conventional Commit title and a complete description from the final diff and commits. State who is affected and which feature gate, if any, limits the change. Include `## Evidence` when evidence exists. Embed sanitized text examples. Mark screenshot upload placeholders clearly. If evidence cannot be produced, say why.
7. Before publication, give a concise status for each MR: title, source and target branches, checks, and review outcome. Ask for confirmation. Do not print the full description or detailed evidence unless the user asks. Do not push, upload, create, or update an MR before explicit confirmation.
8. After confirmation, resolve the current authenticated GitLab username with `glab api user`. Push without force. Upload approved screenshots if needed, replace placeholders with the returned GitLab Markdown, then create the MR with `glab` and assign it to that GitLab user. If the source branch already has an MR, update it and assign it to that user. Verify the published title, description, target, source, assignee, and URL.
9. Keep the success response simple. Return only the GitLab MR URL for each created or updated MR, one URL per line. Do not repeat descriptions, commits, checks, reviews, or evidence. Add only mandatory repository or harness footers after the links.

Never force-push, use `--no-verify`, hide failed checks, post adversarial reviews, or claim unobserved evidence.
