---
name: create-mr
description: Prepare, review, and publish a GitLab merge request. Use when the user asks to create an MR or runs /create-mr.
---

# Create a merge request

Create an MR only after the branch is complete, verified, checked against the final diff, and the user has approved publication.

1. Read every applicable `AGENTS.md`. Inspect the worktree, branch, remote default branch, target-to-HEAD diff, branch commits, and existing MRs for the source branch. Stop if the branch is the target, HEAD is detached, or unrelated changes make the scope unsafe. Do not create a duplicate MR.
2. Finish only the requested work. Inspect the unstaged diff before staging. Run the required checks. Make small, atomic Conventional Commit commits only when the user requested MR creation. Before each commit, inspect the staged diff and state its single outcome and verification. Do not bypass hooks or weaken tests.
   Check feature gating before the reviews. When the change touches a gated feature (a feature toggle, an experimental directory, or a record type that exists only behind a toggle, such as lead triggers behind `LeadAutoAgents`), every behavior change must stay inside the gate. Scope it to the gated path or check the toggle. Users and organizations outside the gate must see the same behavior as on the target branch. Follow step 3a of the `review-mr` skill. Fix each leak before you continue.
3. Capture observable evidence when possible. Use actual test output, sanitized request/response examples, or a UI screenshot. Keep generated evidence outside the repository unless repository rules require it. Never fabricate evidence or expose secrets or customer data.
4. Inspect the final target-to-HEAD diff once as the publication review. Do not start an adversarial review loop or delegate extra reviewers as part of `create-mr`; post-publication review bots provide that independent pass. Check only for critical publication risks: incorrect supported behavior, security or privacy exposure, data loss, concurrency errors, feature-gate leaks, unsafe migrations or rollout, missing regression coverage for the changed behavior, secrets, unrelated files, and a materially false description. Fix every confirmed issue, rerun the required checks, and commit the fix. Stop if a confirmed critical issue remains.
5. Load the `write-mr` skill. Draft a Conventional Commit title and a complete description from the final diff and commits. State who is affected and which feature gate, if any, limits the change. Include `## Evidence` when evidence exists. Embed sanitized text examples. Mark screenshot upload placeholders clearly. If evidence cannot be produced, say why.
6. Before publication, give a concise status for each MR: title, source and target branches, checks, and final-diff review outcome. Ask for confirmation. Do not print the full description or detailed evidence unless the user asks. Do not push, upload, create, or update an MR before explicit confirmation.
7. After confirmation, resolve the current authenticated GitLab username with `glab api user`. Push without force. Upload approved screenshots if needed, replace placeholders with the returned GitLab Markdown, then create the MR with `glab` and assign it to that GitLab user. If the source branch already has an MR, update it and assign it to that user. Verify the published title, description, target, source, assignee, and URL.
8. Keep the success response simple. Return only the GitLab MR URL for each created or updated MR, one URL per line. Do not repeat descriptions, commits, checks, reviews, or evidence. Add only mandatory repository or harness footers after the links.

Never force-push, use `--no-verify`, hide failed checks, post adversarial reviews, or claim unobserved evidence.
