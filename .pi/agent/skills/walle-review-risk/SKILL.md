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

The change sets the risk, not the author. Assess risk from the highest applicable impact. Each level says how many people should approve the MR:

- **High (two people):** authentication, authorization, secrets, payments, destructive data operations, database migrations, tenant isolation, public API compatibility, production deployment controls, any always-human path below, or an unbounded change with no credible verification.
- **Medium (one person):** ordinary product changes, shared business behavior, background jobs or alert delivery, integration/provider handling, data selection or persistence, infrastructure changes, generated client or DTO contracts, or a change whose tests do not cover its main failure mode. In Butler, these sensitive areas are also medium: LLM prompts and system prompts, caching, Celery tasks and schedules, and integration sync.
- **Low (no person once CI and the automated review are green):** isolated tests, documentation, copy, local tooling, internal-only features, narrowly scoped presentation-only code, mechanical refactors that preserve behavior and have adequate verification, or additive changes behind a feature flag that is off by default.

Then adjust the result:

- **Always-human paths.** The script lists changed files that match the always-human paths: the CI pipeline (`.gitlab-ci.yml`, `.gitlab/`, `CODEOWNERS`), infrastructure (`devops/`, `Dockerfile`), database migrations (`alembic/`), the auth packages, and the billing packages. The exact patterns are `SENSITIVE_PATHS` in `scripts/blast_radius.py`. Any match makes the result high. This is the one case where a path alone decides the result.
- **Feature flag.** When every logic change runs only behind a feature flag that defaults to off, and the diff does not change the flag's default, the result may drop to low. Name the flag in the report.
- **Size.** When the diff changes more than 1,000 lines, raise the result by one step, because most changes that large have findings. Generated files, lock files, and tests count toward the size; say so when they make up most of it.
- **Blast radius.** Apply the code-graph result as described below.

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
  - `additive`: only new names, such as a new enum member, constant, function, method, or class, a new class field with a default, or new entries in a dict, set, list, or tuple whose existing entries stay the same.
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
python3 -I ~/Documents/code-stuff/dotfiles/.pi/agent/skills/walle-review-risk/scripts/blast_radius.py \
  --graph ~/Documents/code-stuff/eve/graphify-intake-full/graphify-out/graph.json \
  --repo <butler checkout> --base origin/master --head <source sha> \
  --prefix src/document_extractor
```

The first lines of the output give the reach and its reason, the exact head SHA and merge base, the number of changed lines, and any always-human paths. Add `--format json` to get every changed node with its change kind, reach tier, and tier. The script matches the diff's target-side line numbers to graph nodes, so the graph must be built from the target branch. The always-human paths and the line count cover the whole diff, including files outside the graph.

### Apply the result

- A `high` reach raises the policy result by one step: low becomes medium, and medium becomes high.
- A `medium` reach supports a medium result for shared behavior, but does not raise the result by itself.
- A `low` reach never lowers the result. A one-line change to a leaf authorization check is still high.
- A `low` reach that says the diff only adds names, text, or imports to widely used code does not raise the result. Mention it only when the new name is wired into shared behavior elsewhere in the same diff, because that wiring shows up as its own logic change.
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

Then state:

- The policy version: `Wall-E agent policy v3`.
- The changed areas and the diff evidence that raised or lowered the result: always-human paths, size, feature flag, and blast radius.
- The blast radius: the reach and its reason, any other high- or medium-reach nodes, and whether the graph was partial, stale, or missing. Do not use the words hub, shared, or leaf in the report.
- The exact head SHA that was assessed, the target branch, and the merge base, or the working-tree scope.
- Any uncertainty that affects the result.
- The review-attention label, how many people should approve, and a short, concrete reason.

Do not use Tier A, B, or C in user-facing reports.

Treat an unknown or incomplete assessment as requiring human review. Do not recommend skipping review from a low result alone.
