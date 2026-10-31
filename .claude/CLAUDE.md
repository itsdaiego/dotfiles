@RTK.md

# Humanizer
- At the start of every session, load the `humanizer` skill. Before every user-visible response, apply it in embedded mode to all natural-language prose, while preserving code, commands, paths, identifiers, data, and other exact technical content. Follow this rule even when the skill's automatic routing description does not match. Do not mention this step unless the user asks.

# Automatic skill routing
- Treat every installed skill's `Use when` or trigger wording as an automatic routing rule. Load and use the matching skill before starting the task, without requiring a slash command or an exact skill name from the user.
- When more than one skill applies, use the smallest useful set in order, beginning with the most specific skill. Do not use a skill when its documented exclusions apply.
- Use `read-issue` for a concise explanation of a work discussion, ticket, incident, or support thread. Use `read-mr` when the user wants to understand an MR, PR, branch, or related change.
- Use `review-mr` to review an MR or PR. Use `write-mr-comment` to draft or improve a review comment, and `write-mr` to draft, rewrite, or review an MR or PR description.
- Use `create-mr` to prepare and publish an MR, `review-queue` for the user's MR-review queue, and `start-reviewer` to operate the autonomous reviewer.
- Use `oncall-intake` for intake on-call pings or the intake dashboard. Use `walle-review-risk` when the user asks how critical or risky a Butler MR, branch, or working tree is.
- Use `butler-sentry-session-metrics` for Eve session-length or engagement metrics, `to-do` for unresolved requests and pending reviews, and `local-branch-cleanup` to clean up local branches or worktrees.

# Atomic commits
- Make and stage one logical change at a time. Do not mix a feature or bug fix with cleanup, refactors, formatting, dependency updates, generated output for unrelated work, or another task.
- Before staging, inspect the working diff. Stage only the files or hunks that implement the current logical change.
- Each commit must stand alone: its message states the outcome, its diff contains everything required for that outcome, and it leaves the repository in a valid, testable state.
- Run the relevant checks before each commit. Do not include unrelated pre-existing changes just because they are present.
- Prefer small, reviewable commits. Split independent behavior changes into separate commits. Keep required generated files with the source change that generated them.
- Before every git commit, inspect the staged diff and explain its one outcome and verification. In Pi, call `assess_atomic_commit` immediately before the commit.
- A staged change over 25 files or 1,200 changed lines needs explicit user approval before the agent commits it. Explain why it cannot be split first.
- Follow the repository's commit and authorization rules. Never create a commit unless the user has authorized it.

# Intake worktrees
- For Butler Intake work, create a dedicated worktree whose branch and directory name start with the actual Linear ticket ID, such as `intake-452-leaddocket-catalog`. Do not use an MR number or a generic task name in place of the ticket ID.
- Resolve the ticket from the user's request, linked Linear issue, merge request, or source branch before creating the worktree. Do not invent a ticket ID. If no Intake ticket can be resolved safely, ask before creating the worktree.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Test-driven development
- For every behavior change or bug fix, use red → green → refactor: write or update a focused automated test first, run it and confirm it fails for the expected reason, implement the smallest production change that makes it pass, then refactor only while the test suite remains green.
- Do not write production code for a behavior change before its failing test exists. When a test is not practical, explain why and use the strongest relevant verification instead.
- Documentation, configuration-only, and non-behavioral changes do not require a test; run any applicable validation instead.

# MR review attention
- For every Butler MR, PR, branch, working-tree, or diff review, audit, or review-priority request, load and run `walle-review-risk`. Do this even when the review does not use `review-mr` or the change is not hosted by GitLab.
- Tell the user a `Needs review`, `Should review`, or `Don't need review` label and one short, concrete reason based on the change and available evidence. Missing or incomplete evidence cannot justify `Don't need review`.
- A Wall-E policy preview is optional supplementary evidence. Its absence must not block the review-attention assessment.

# Herdr session names
- In a Herdr-managed root session, the shared auto-name integration labels the current tab `pi`, `claude`, or `codex`. Herdr combines that with the workspace/project name on the bold top line, such as `chessan · codex`.
- On the first user prompt, infer a short task description, convert it to a lowercase kebab-case slug with at most 32 characters, and run `herdr agent rename "$HERDR_PANE_ID" "<slug>"` before substantive work. That inferred task name belongs on the lower description line. Preserve an existing task name and never rename a subagent.

# Shared harness maintenance
- When updating the shared Pi, Claude Code, or Codex setup, work in `~/Documents/code-stuff/dotfiles` and follow `docs/agent-config-maintenance.md`.
- Keep authentication, OAuth state, sessions, caches, databases, downloaded plugins, generated system skills, and per-machine trust state out of Git.

# Tool-specific instructions
- Before changing or diagnosing a configured desktop tool, read its `AGENTS.md` under `~/Documents/code-stuff/dotfiles/<tool>/`. Yabai work must follow `~/Documents/code-stuff/dotfiles/yabai/AGENTS.md`.

# Safety rules
- Run an AWS CLI (`aws`) command only when the operation is demonstrably read-only. Never run mutating or ambiguous AWS commands. Do not bypass this restriction through a script, wrapper, alias, subshell, SDK, or another command. Provide blocked commands for the user to review and run manually.
- Always ask the user for confirmation immediately before a recursive forced deletion, such as `rm -rf <folder>`. Execute only the exact command that the user confirms. Block the command when confirmation is unavailable or denied.

# Writing docs and MR descriptions
Applies to written artifacts only: docs, design docs, Notion and Linear pages, PR/MR descriptions, and commit bodies. It does not change how you write chat replies.
- Write in full, clear sentences. Do not use terse, compressed, or "caveman" style in these artifacts, even when that style is active for chat.
- Never truncate, abbreviate, or drop information to save tokens. Keep every fact, decision, caveat, and reason. Clear beats short.
- The reader may know the code, but must not need to reverse-engineer the text. Say what the system does and why, then name the code that does it.
- Define project terms that are not obvious on first use. Add a short glossary when a doc uses several.
- Use short sentences with one idea each, active voice, and a clear actor.
- Label diagrams with readable steps, not only code names.
- Keep code blocks, commands, exact error text, and identifiers verbatim.
