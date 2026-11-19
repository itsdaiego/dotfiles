---
name: review-risk
description: Assess or find Butler merge requests and working trees with the agent-owned review policy, then state whether each needs, should get, or does not need more review. Use for every Butler MR review, risk search, or review-triage request.
---

# Review risk

Use this skill for every Butler merge-request review, risk search, audit, or triage, including when another review skill is used. It assesses the exact change that Wall-E would review. It may use read-only GitLab and Git calls to discover and inspect MRs. It does not change labels, create a sandbox, publish comments, approve MRs, or mutate remote state.

## Policy boundary

This policy belongs to Wall-E. It must not be read from, copied into, or shipped with a Butler repository. Do not look for `.gitlab/risk-tiers.toml`, `tools.risk_tier`, GitLab labels, or another repository file to decide the risk.

Use the policy below with the MR context. State the specific evidence that caused the result. If the context is incomplete, report the uncertainty instead of inventing a deterministic result.

## Gather MR context

For a GitLab MR, read the exact source and target revisions, changed paths, diff, test changes, current pipeline state, and existing review discussion. Use read-only GitLab or Git commands. For a working tree, inspect the committed diff and clearly say whether unstaged or untracked work is included.

Pass that context to the assessment. Do not rely on a path-only classifier: paths identify likely impact, while the diff determines whether the change actually creates the risk.

## Find matching MRs

When the user asks for a number of MRs at a risk level or within a scope, treat the request as discovery followed by one complete assessment per selected MR. A title, changed path, existing risk comment, or prior assessment is only shortlist evidence. It never fills a result slot by itself.

1. Enumerate the complete current open-MR pool with pagination. Apply any explicit author, reviewer, draft, target, team, or product filter. Prefer ready MRs when the user does not mention drafts. Include a draft only when the ready pool cannot satisfy the request, and label it as a draft.
2. Shortlist candidates from titles and changed-path summaries. Then inspect each candidate's exact head and target, complete diff, tests, pipeline, discussions, conflicts, and blast radius before classifying it.
3. Apply every policy adjustment, including always-human paths, semantic size, feature flags, and graph reach. Existing Wall-E or human risk comments are evidence to check against the current policy and head. They do not override this assessment.
4. Reject a candidate that misses the requested risk or scope, record the concrete reason, and continue searching. Never lower a result, ignore an always-human path, omit generated-source behavior, or substitute review attention for risk to meet the requested count.
5. Never force the quota. If fewer verified matches exist, report the verified count and the closest rejected candidates with their actual classifications.

Interpret scope qualifiers from authored changes, not repository language or filenames alone:

- **Backend** without another qualifier means production runtime backend code under `src/document_extractor`, excluding changes that are only tests, fixtures, snapshots, generated clients, prompts, documentation, `analysis/`, or `evals/`. An MR may include those files, but it needs at least one authored runtime backend change to fill a backend slot.
- **Internal backend**, **backend tooling**, or an explicit request that allows evals includes `analysis/`, `evals/`, and offline scripts. Label each selected MR as production runtime, eval, analysis, or test-only so the user can see what satisfied the scope.
- **Docs do not count** means a docs-only MR cannot fill a slot. Documentation that accompanies qualifying code remains part of the diff and risk assessment.
- Prompt and Jinja template changes are prompt changes, not documentation changes. Apply the prompt policy even when the file extension is Markdown.
- Generated output does not establish frontend or backend scope. Use the authored source that produced it.

For a discovery response, add a short search audit after the result table: how many open MRs were scanned, how many candidates received complete assessments, and the specific near-misses rejected for risk or scope. This audit must make it possible to tell that every selected MR was classified at its reported current head.

## Wall-E policy

The change sets the risk, not the author. Assess risk from the highest applicable impact. Each level says how many people should approve the MR:

- **High (two people):** platform authentication or authorization boundaries; secret storage, transmission, redaction, or access; payments; destructive data operations; database migrations; tenant isolation; public API compatibility breaks; production deployment controls; any always-human path below; or an unbounded change with no credible verification.
- **Medium (one person):** product behavior with meaningful shared reach, shared business behavior, shared account or integration configuration behavior, background jobs or alert delivery, integration/provider handling, data selection or persistence, infrastructure changes, generated client or DTO contracts that change compatibility behavior, or a change whose tests do not cover its main failure mode. In Butler, these sensitive areas are also medium: LLM prompts and system prompts, caching, Celery tasks and schedules, and integration sync.
- **Low (no person once CI and the automated review are green):** localized product bug fixes and behavior changes with isolated code and user reach plus focused verification; localized self-service account or integration configuration; isolated tests; documentation; copy; local tooling; internal-only features; narrowly scoped presentation-only code; mechanical refactors that preserve behavior and have adequate verification; compatibility-preserving internal contract additions; or additive changes behind a feature flag that is off by default.

Then adjust the result:

- **Always-human paths.** The script lists changed files that match the always-human paths: the CI pipeline (`.gitlab-ci.yml`, `.gitlab/`, `CODEOWNERS`), infrastructure (`devops/`, `Dockerfile`), database migrations (`alembic/`), the auth packages, and the billing packages. The exact patterns are `SENSITIVE_PATHS` in `scripts/blast_radius.py`. Any match makes the result high. This is the one case where a path alone decides the result.
- **Feature flag.** When every logic change runs only behind a feature flag that defaults to off, and the diff does not change the flag's default, the result may drop to low. Name the flag in the report.
- **Size.** When the semantic diff changes more than 1,000 lines, raise the result by one step, because most changes that large have findings. Count authored source, configuration, migrations, and tests. Do not count deterministic generated output or lockfile churn when a small reviewed source change produces it, the generator recreates the exact output, and the relevant checks pass. Report both the raw and semantic line counts when they differ. A large authored change does not become small because it also updates generated output.
- **Blast radius.** Apply the code-graph result as described below.

### Impact and reach assessment

Start with the consequence if the change is wrong. A sensitive consequence makes the change high even when the edited function is isolated. Otherwise, use actual code reach and user reach to distinguish low from medium.

A production logic edit does not become medium only because it changes behavior. A localized conditional, bug fix, or UI interaction stays low when it affects one narrow path or audience, has few production dependents, does not cross a sensitive boundary, and has a focused regression test. Raise it to medium when it affects several workflows, modules, organizations, or user groups, or when it changes shared behavior without adequate verification.

Use the graph when it covers the code. When the graph does not cover a changed area, inspect callers, consumers, and the product surface directly. Unknown graph reach does not automatically make a change medium when the diff and direct usage evidence prove that it is isolated. Report the missing graph coverage as uncertainty.

Classify secret-related changes by the boundary they alter. Storage, transmission, logging, redaction, and who may access a secret are high. A standard reveal control that shows an authorized administrator only the value they just entered is presentation behavior, unless the diff also returns, persists, logs, or exposes a saved secret.

### User-managed configuration

An authorized user who changes settings for their own account or organization is not changing the platform's authorization boundary. Classify configuration from its code reach and failure consequences, even when the setting controls which integration tools the product may use. Examples include changing an email address, selecting integration tools, editing firm instructions, or enabling an account feature.

A configuration change can be low when it is isolated to one account or integration, preserves the existing role and tenant checks, affects only the user's chosen settings, and has focused verification. It is medium when it changes shared runtime behavior, persisted configuration semantics, provider calls, automatic external writes, or several configuration consumers. It is high only when it changes who may manage the configuration, bypasses role or tenant checks, applies one tenant's choice to another tenant, exposes protected data, or independently creates another high consequence.

A surprising result within one organization's authorized configuration, such as interpreting a stale selection as every tool, is usually a product or integration bug. Classify it by reach and side effects instead of treating it as platform authorization. Raise it to high only when it crosses a platform security boundary or creates another high consequence.

Risk measures the impact and reach of the code change. Pipeline failures, unresolved findings, and merge-state concerns determine review attention separately, unless they also prove that the change lacks credible verification.

### Contract and behavior assessment

Treat dependency count as reach evidence, not a risk multiplier. Propagating one contract through types, serializers, generated clients, fixtures, and call sites is one change. Review every boundary, but do not raise risk once for each mechanical edit.

Classify the contract before using graph reach:

- **Compatibility-preserving additions** let existing producers and consumers continue to work. Examples include a field with a safe default, an optional wire field that readers tolerate when absent, a `TypedDict` `NotRequired` key, and a new enum value when every consumer has a safe fallback. These stay additive unless the diff also wires the new value into shared behavior.
- **Compatibility breaks** include a required or non-null field without a deployment-compatible default, a removed or renamed field, a narrowed type, changed serialized value, changed signature, or an enum consumer that rejects an unknown value. Treat them as logic. Trace the producer and consumer boundaries and require focused compatibility evidence.
- **Derived contracts** such as generated DTOs do not create extra risk by their file count. Assess the reviewed source contract, whether it is public or cross-service, and whether code generation, type checking, and serialization checks prove the generated output matches it.
- **Iteration changes** are logic only when they change the set, order, count, pagination, retry behavior, or side effects of work. A type-only or behavior-preserving iterator rewrite is mechanical; verify it with the relevant compiler, type checker, or focused test.

A database migration remains high because its risk is operational as well as contractual. Check existing rows, writes from old application versions, backfill and deployment order, lock behavior, and rollback. The absence of an index does not make a new required column compatible or safe.

Raise the result when the diff combines several medium-impact areas or leaves a realistic regression path untested. Lower it only when the complete diff and verification show that the higher-risk concern does not apply. Outside the always-human paths, never treat a file path alone as proof of risk.

## Blast radius from the code graph

A graphify code graph shows how much other code depends on the code a diff changes. Use it to measure the "broad fan-out point" rule above instead of guessing. A change to a leaf, which nothing else calls, stays local. A change to a hub, which many modules call or import through short chains, can break code the diff never touches.

Terms used in this section:

- **Changed node:** a function, method, class, or module in the graph whose lines the diff edits.
- **Production dependents:** non-test code that calls, imports, references, inherits from, or implements the changed node, directly or through up to three hops.
- **Test dependents:** tests that reach the changed node. They show coverage, not reach.
- **Reach tier:** how much depends on the node. `hub` when its production dependents are in the top 5% of the graph and number at least 3, `shared` when they are in the top 20% and number at least 2, and `leaf` otherwise. These names appear only in `--format json`. Reports use the reach below.
- **Change kind:** what the diff did to the node. The script compares the old and new Python code of the innermost function, class, or module that holds each change:
  - `text`: only docstrings, comments, formatting, `description=`, `title=`, `help=`, `message=`, and similar keyword text, or a string constant whose name ends in `DESC`, `HELP`, `MESSAGE`, `TITLE`, `LABEL`, `SUMMARY`, `DOC`, or `EXAMPLE`. Prompts do not count as text.
  - `imports`: only `import` statements changed.
  - `additive`: only new names, such as a new enum member, constant, function, method, or class, a new class field with a default, a `TypedDict` `NotRequired` key, or new entries in a dict, set, list, or tuple whose existing entries stay the same.
  - `logic`: anything else. This includes changed or removed enum values, a new required field, a changed signature, decorator, or base class, a removed definition, and any file that does not parse.
- **Tier:** the reach tier when the change kind is `logic`, and `leaf` otherwise. Code that depends on a node cannot break when the node only gains text, imports, or new names, so only a logic change to a widely used node is a hub.
- **Reach:** the blast radius in plain terms, from the highest tier in the diff. `high` is a logic change in a hub, `medium` is a logic change in shared code, and `low` is everything else. `unknown` means no changed file is in the graph. The script prints the reach with a one-sentence reason, for example: `Blast radius: high. Changes logic in begin_integration_job_no_commit(), which 137 functions depend on. 132 tests cover it.`

### Known graphs

This table is the list of code graphs that every harness uses, for review risk and for code questions. Keep it current when a graph is added or rebuilt.

| Graph | Path prefix | Covers (under the prefix) |
| --- | --- | --- |
| `~/Documents/code-stuff/eve/graphify-intake-full/graphify-out/graph.json` | `src/document_extractor` | `services/llm_service`, `integrations`, `common`, `db/llm`, `workers/tasks`, `live_intake_assist`, `llm/intake`, `llm/voice_agent_config` |

The graph covers Butler intake work, which includes leads, lead chase, voice AI, phone systems, and MCP plugins, together with the shared types, database models, and worker tasks that intake code uses. Graph paths are relative to the prefix, so `cp_lead/service.py` in the graph is `src/document_extractor/services/llm_service/cp_lead/service.py` in the repository. The graph has no JavaScript, Markdown, or `db/alembic` migrations.

The file `BUILT_FROM`, next to `graphify-out/`, records the Butler commit the graph was built from. The script reads it to count target-branch commits in scope since the build.

### Run the estimate

Run the estimate from a checkout that has both revisions. Use the MR's target branch as `--base` and the exact source head as `--head`. The script is `scripts/blast_radius.py` next to this file:

```sh
python3 -I ~/.pi/agent/skills/walle-review-risk/scripts/blast_radius.py \
  --graph ~/Documents/code-stuff/eve/graphify-intake-full/graphify-out/graph.json \
  --repo <butler checkout> --base origin/master --head <source sha> \
  --prefix src/document_extractor
```

The first lines of the output give the reach and its reason, the exact head SHA and merge base, the number of changed lines, and any always-human paths. Add `--format json` to get every changed node with its change kind, reach tier, and tier. The script matches the diff's target-side line numbers to graph nodes, so the graph must be built from the target branch. The always-human paths and the line count cover the whole diff, including files outside the graph.

### Apply the result

- A `high` reach raises the policy result by one step: low becomes medium, and medium becomes high.
- A `medium` reach raises a low logic change to medium when the changed behavior is shared. It does not raise medium to high.
- A `low` reach preserves a low result for localized behavior. It never lowers a sensitive result. A one-line change to an isolated authorization check is still high.
- A `low` reach that says the diff only adds names, text, or imports to widely used code does not raise the result. For an additive contract, confirm that old producers may omit it, old consumers tolerate it, and code generation and type checks cover every affected boundary. Mention broad reach only when the new name is wired into shared behavior elsewhere in the same diff, because that wiring shows up as its own logic change.
- A high-reach change with few tests covering it is a coverage gap. Name it in the report.
- When the reason says "Partial", the estimate covers only the files in the graph. Say so. When the reach is `unknown`, say the blast radius was not measured and leave the policy result unchanged.
- When the report shows target commits in scope since the graph was built, the line numbers may have drifted. Say the graph is stale. Ask the user to rebuild it with graphify when the drift touches the changed files.
- When no graph covers the changed code, skip this step and say the blast radius was not measured. Do not build a graph during a review.

### Rebuild the graph

Rebuild when the report shows the graph is stale for the changed files. Python files go through graphify's AST extractor, which uses no LLM tokens. Do not use the `/graphify` skill flow for this, because it sends documents to LLM subagents and builds an HTML view that the estimate does not need.

```sh
B=~/Documents/code-stuff/eve/butler
S=~/Documents/code-stuff/eve/graphify-intake-full
D=src/document_extractor
git -C "$B" fetch -q origin master
SHA=$(git -C "$B" rev-parse origin/master)
# Move the old copy aside first; never delete it without asking the user.
mkdir -p "$S"
git -C "$B" archive "$SHA" -- $D/services/llm_service $D/integrations $D/common $D/db/llm \
  $D/workers/tasks $D/live_intake_assist $D/llm/intake $D/llm/voice_agent_config \
  | tar -x -C "$S" --strip-components=2 --exclude='*.md'
echo "$SHA" > "$S/BUILT_FROM"
(cd "$S" && graphify update . --no-cluster && graphify cluster-only . --no-viz --no-label)
```

`git archive` copies only tracked files at that exact commit, so untracked output such as a stray `graphify-out/` folder in the checkout stays out of the graph.

## TypeSafe Jev classification

Apply the deterministic policy before calling Jev. Gather the complete exact-head evidence, apply explicit high consequences, semantic-size adjustments, feature flags, compatibility rules, and blast radius, then decide whether the unresolved judgment is mainly low versus medium.

Skip Jev when an always-human path already makes the result high. You may also skip it when another explicit high consequence makes the final result unavoidable. Record `TypeSafe Jev: skipped (<deterministic reason>)` so the report shows that the classifier was intentionally unnecessary.

For the remaining assessments, build one JSON object with:

- MR URL, title, exact source and target SHAs, target branch, and merge base, or the exact working-tree scope;
- change summary, complete changed paths, and the authored semantic diff; include the complete raw diff when it fits the classifier's 64,000-token context;
- tests changed and checks run, current pipeline and merge state, conflicts, and existing review discussion;
- always-human paths, raw and semantic changed-line counts, feature flag and default, compatibility evidence, and blast-radius output;
- any omitted generated output or lockfile churn, with the reason it is deterministic.

Write the object to a temporary JSON file, then run:

```sh
python3 -I ~/.pi/agent/skills/review-risk/scripts/typesafe_risk.py \
  /path/to/evidence.json --pretty
```

The helper reads `TYPESAFE_API_KEY` from the process. Background review runners that did not inherit the variable load it through a fresh `zsh` process from `~/.zshrc`. Never print, copy, log, or place the key in a command argument, repository file, review artifact, or prompt.

Use Jev as an uncertainty detector and independent second opinion. Its probabilities help distinguish an obvious low result from a borderline low-versus-medium call. If Jev returns high after the deterministic pass did not, inspect the evidence for a missed high consequence. Jev never overrides direct diff evidence or a deterministic rule, and it cannot fill missing MR context, tests, pipeline state, discussions, or graph evidence. Explain any disagreement.

If TypeSafe is unavailable, reports an authentication error, or returns an invalid answer, record `TypeSafe Jev: unavailable (<reason>)` and finish from the exact evidence. Classifier failure alone does not make a complete policy assessment unknown, but it is uncertainty that must appear in the report.

## Review attention

After the risk assessment, give the user a review-attention label and one short reason. This label is a review queue aid, not a GitLab label or an approval verdict.

The attention label and the risk tier never block approval on their own. Only a confirmed high-severity issue does, as the review-mr Approval rule says.

- **Needs review (two people):** Wall-E finds high risk, cannot inspect the exact head, a required check failed, or the review found a confirmed critical issue.
- **Should review (one person):** Wall-E finds medium risk, or the review found a credible non-critical concern, shared behavior change, or meaningful coverage gap.
- **Don't need review (no person once CI and the automated review are green):** Wall-E reports low risk, CI and merge state are not concerning, and the review found no confirmed issue. Do not assign this label from a low policy tier alone.

The reviewer may raise attention based on evidence from the review. An unknown or incomplete result is always **Needs review**. An agent's approval never fills a slot that needs a person.

A result covers only the head SHA it names. When new commits land after the assessment, the result is stale. Run the assessment again before relying on it.

## Report

Open with one line per MR: `Risk: <low|medium|high>. <one plain sentence that says why>`. Write the reason for a person, not as a list of codes: name what the change does and why that matters, for example "Changes how lead push jobs start, and 137 functions depend on that code."

When the report covers more than one MR, put them in a table with these columns, in this order: MR, Title, Risk, Why, Link. The MR column holds the number, such as `!24253`. Title is the MR title. Link is the full MR URL and is always the last column.

For a discovery request, report only MRs that completed the full assessment. Follow the table with the search audit from **Find matching MRs**. Do not present a shortlist as a verified result.

Then state:

- The policy version: `Wall-E agent policy v6`.
- The changed areas and the diff evidence that raised or lowered the result: always-human paths, raw and semantic size when they differ, feature flag, blast radius, and compatibility evidence for a contract or iteration change.
- The blast radius: the reach and its reason, any other high- or medium-reach nodes, and whether the graph was partial, stale, or missing. Do not use the words hub, shared, or leaf in the report.
- The exact head SHA that was assessed, the target branch, and the merge base, or the working-tree scope.
- The TypeSafe Jev classification, confidence when present, or its availability error. When it disagrees with the final risk, state the policy evidence that decided the result.
- Any uncertainty that affects the result.
- The review-attention label, how many people should approve, and a short, concrete reason.

Do not use Tier A, B, or C in user-facing reports.

Treat an unknown or incomplete assessment as requiring human review. Do not recommend skipping review from a low result alone.
