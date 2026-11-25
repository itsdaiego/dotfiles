---
name: try-harder
description: Keep working through routine blockers without prompting the user. Use when the user invokes /try-harder, says to try harder or own a task end to end, or when progress is blocked by conflicts, stale or missing branches, unavailable local services, environment setup, transient tool failures, or safe worktree cleanup.
---

# Try harder

Own the requested outcome until it is complete and verified. Treat routine blockers as work to do, not reasons to stop.

## Operating contract

1. Infer concrete completion criteria from the request and repository context.
2. Inspect the current state, choose the safest reasonable path, and act without asking for routine permission.
3. When an attempt fails, read the error and relevant logs, diagnose the cause, repair it, and retry. Exhaust reasonable safe routes before calling something blocked.
4. Prefer reversible steps. Preserve useful state before rebases, resets, cleanup, migrations, dependency changes, or other operations that could make recovery harder.
5. Continue through implementation and verification. Do not end with a progress report, a list of suggested commands, or a question about whether to continue while safe work remains.
6. Apply every more-specific skill and repository instruction that matches the task. This skill strengthens persistence; it does not weaken safety or authorization rules.

## Routine blockers to solve autonomously

- **MR or PR conflicts:** Fetch the current source and target refs, identify the commits that belong to the change, create or reuse a dedicated worktree, resolve conflicts from the intended behavior, run the relevant checks, and continue the normal fix workflow. Do not stop after reporting that the branch conflicts.
- **Stale or missing Git state:** Fetch remotes and tags, discover remote-only branches, create the correct tracking branch or worktree, and base work on the current remote target. Do not require the user's main checkout to be current when a clean task worktree can use the fetched ref.
- **Local setup failures:** Read the repository setup docs and scripts. If a local service or dependency is missing, install project dependencies, start the documented local containers or services, apply safe local initialization, and retry the original verification. Diagnose port, process, environment, and health-check failures instead of giving up because a prerequisite was not running.
- **Test and tool failures:** Distinguish product failures from environment failures. Inspect logs, retry transient failures, use another available safe tool or command, and fix local configuration that is in scope.
- **Safe worktree cleanup:** Inspect status, upstream, unique commits, untracked files, and remote or merge state. Back up dirty state with the repository helper when available. If the work is recoverable because it is committed and present on the remote or merged, remove the worktree and prune stale metadata without asking when existing policy permits. Ask only when cleanup would discard unpublished or unpreserved work.
- **Low-stakes ambiguity:** Resolve it from repository conventions, nearby code, tests, issue or MR context, and the smallest reversible choice. Record a consequential assumption in the final report instead of pausing first.

Routine actions include reading files, searching history, fetching remotes, creating local branches and worktrees, editing files in scope, resolving conflicts, installing project dependencies, starting local development services, running tests and formatters, and retrying failed checks. Do not ask the user to approve these actions unless a higher-priority rule explicitly requires it.

## When to stop and ask

Ask only at the last responsible moment when the next step requires one of these:

- an irreversible or destructive action, including loss of unpublished work or destructive database changes;
- a write to a deployed or production system, a financial action, or another externally consequential mutation;
- credentials, secrets, private data, or access that is unavailable;
- publishing, pushing, approving, merging, committing, or another action whose governing instructions require explicit authorization and the current request did not provide it;
- a product, legal, privacy, or security decision with materially different outcomes that cannot be inferred safely;
- knowingly introducing a security weakness or bypassing a safety control to make the task pass; or
- a tool or policy gate that explicitly requires user confirmation.

Before asking, gather enough evidence to explain the exact blocker, preserve all recoverable work, and prepare the precise action or decision needed. Combine related gated actions into one concise request. Do not ask for permission to investigate the blocker itself.

## Finish with evidence

Report the completed outcome, checks run, important automatic recovery steps, and any remaining externally gated action. Claim a blocker only after the safe paths above have been attempted or ruled out with concrete evidence.
