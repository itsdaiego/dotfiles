---
name: review-mr
description: Use when reviewing a GitLab merge request — fetches MR diff via glab, inspects for correctness/bugs/quality, checks codebase standards, and writes review to ~/Code/.claude/code-reviews/. NEVER posts comments to the MR without explicit user approval.
---

# Review MR

Review a GitLab merge request for correctness, bugs, code quality, and adherence to codebase standards.

## Safety Rule

**NEVER post comments, approvals, or reviews directly to the MR on GitLab without explicit user approval.** All review output goes to files in `~/Code/.claude/code-reviews/`.

## Inputs

The user provides one of:
- An MR number (e.g. `!12345` or `12345`)
- An MR URL (e.g. `https://gitlab.com/group/repo/-/merge_requests/12345`)
- A branch name to look up

If no MR is specified, ask for one.

## Workflow

### 1. Fetch MR metadata and diff

```bash
# Get MR details
glab mr view <MR_NUMBER>

# Get the full diff
glab mr diff <MR_NUMBER>

# Get diff refs (needed for draft comments later)
glab api projects/:id/merge_requests/<MR_NUMBER> | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('diff_refs')))"
```

Extract: title, description, source branch, target branch, author, changed files list, and **diff_refs** (base_sha, head_sha, start_sha).

Also fetch every existing discussion, human and bot (CodeRabbit, Wall-E), with its position, resolved state and date:

```bash
glab api "projects/:id/merge_requests/<MR_NUMBER>/discussions?per_page=100" | python3 -c "
import sys,json
for d in json.load(sys.stdin):
  for n in d['notes']:
    if n.get('system'): continue
    p=n.get('position') or {}
    print('---', d['id'], n['author']['username'], p.get('new_path',''), p.get('new_line',''), 'resolved='+str(n.get('resolved')), n['created_at'][:16])
    print(n['body'][:3000])
"
```

Paginate if there are more than 100. Save the output to the scratchpad, and pass it to any review subagent.

### 1a. Classify the private Wall-E risk

For every MR, invoke the `walle-review-risk` skill after you fetch its metadata and refs. Follow its MR workflow so it classifies the exact source head against the policy from the target branch.

This result is private review metadata for Daiego. Do not add it to the MR description, post it to GitLab, or let it change the approval verdict. Record the low, medium, high, or unavailable result, matched rules and paths, content signals, policy ref, and any classifier uncertainty in the local review file. If the skill cannot classify the MR, report it as unavailable. Do not guess or substitute an LLM judgment.

Also add a user-facing review-attention label: `Needs review`, `Should review`, or `Don't need review`, with one short reason. Follow `walle-review-risk`'s mapping. This is a review queue aid and does not change the approval verdict.

### 2. Understand the change

- Read the MR description and any linked issues for context.
- Identify the category: feature, bugfix, refactor, migration, config change, etc.
- If the intent is unclear from the description and diff, **ask clarifying questions** before proceeding with the review.
- **Check the description against the final diff.** Flag it as a Critical Issue (must fix before merge) when it describes an abandoned plan, lists commits, routes, DTOs, files or behavior the diff does not contain, or omits a significant change the diff does contain. Also compare it to the commit messages, which usually reflect the latest approach. The description often doubles as the rollout doc, so a stale one misleads reviewers and deployers. Name the specific stale claims and state what the code actually does.

### 3. Review the diff — file by file

For each changed file, read the full current version (not just the diff) to understand context:

**Correctness & Bugs:**
- Logic errors, off-by-one, race conditions, null/None handling
- Missing error handling at system boundaries (external APIs, user input)
- Incorrect assumptions about data shape or state
- Edge cases not covered
- Database query correctness (N+1, missing indexes for new queries, transaction safety)
- Security issues (injection, auth bypass, data exposure)

**Code Quality:**
- Code duplication — is similar logic already implemented elsewhere?
- Naming clarity — do variables/functions/classes communicate intent?
- Function size — should anything be extracted?
- Unnecessary complexity — simpler way to achieve the same result?
- Dead code or unused imports introduced

**Standards & Practices (check AGENTS.md / CLAUDE.md in the repo):**
- Type safety — no `Any`, no `# type: ignore`, proper type hints
- Import style — top-level imports, `dict` not `typing.Dict`
- API conventions — snake_case URLs, proper DB session scoping, RLS usage
- Pydantic models — correct base class (`BaseAPIModel` vs `BaseBackendModel`)
- Test coverage — are new code paths tested? Are snapshot tests updated?
- Codegen — if DTOs changed, was codegen run?

**Reuse Opportunities:**
- Search the codebase for existing utilities, helpers, or patterns that could replace new code.
- Check if the change duplicates logic from another module.
- Suggest augmenting existing abstractions rather than creating parallel ones.

### 3a. Check feature gating

A change to a gated feature must not reach users who do not have the feature. Do this check on every MR, also on small bug fixes.

1. Find the gates the MR touches. Look for feature toggle checks (for example `resolved_feature_toggles_all_enabled`, `useFeatureToggle`), experimental directories (their `AGENTS.md` says so), and record types that exist only behind a toggle (for example, lead triggers exist only when `LeadAutoAgents` is on).
2. For each changed hunk in shared code, ask: does this change behavior, output, wording, API responses, status codes, logs, metrics, or UI for a user or organization that does not have the toggle? A shared code path is one that also serves ungated features, such as matter triggers next to lead triggers.
3. A fix for a gated feature must stay inside the gate. It must either run only on the gated path (for example, only for lead triggers) or check the toggle. Matter behavior, and behavior for organizations with the toggle off, must stay the same as on the target branch.
4. Also flag a change that loosens a gate: a removed or weakened toggle check, a check that moves from organization scope to user scope or back, a new entry point (route, webhook, task, UI element) without a toggle check, or a gated UI element that becomes visible.

Report each leak as a Critical Issue. Name the file and line, the gate, and who outside the gate sees the change. When the MR description says "Who is affected: every firm" or similar for a gated feature's fix, treat that as a leak until the diff proves otherwise.

### 3b. Check each finding against existing comments and the current head

Give every finding exactly one status:

- **New:** no existing comment raises it.
- **Already flagged:** an existing comment raises the same problem. Name the author, link the thread (`<MR URL>#note_<id>`), and say whether it is open or resolved. When the comment covers only part of the problem, mark it **Partly flagged** and say what is new.
- **Fixed:** the problem was real at an earlier commit, but the current head no longer has it. Name the fixing commit.

Also check each existing open thread that asks for a code change against the current head. Report the ones that still need a fix, and the ones the head already fixes but nobody resolved. Do not re-argue a thread. Just say whether the code still has the problem.

Re-fetch the MR head right before writing the review. If it moved since you read the code, re-check findings on the files that changed.

### 4. Write the review

Create a review file at:
```
~/Code/.claude/code-reviews/MR-<number>-review.md
```

Use this structure:

```markdown
# MR !<number>: <title>

**Author:** <author>
**Branch:** <source> -> <target>
**Reviewed:** <date>

## Summary

<1-2 sentence summary of what the MR does and your overall assessment>

## Wall-E risk (private)

<Low / medium / high / unavailable, with the policy ref, matched rules and paths, content signals, and uncertainty. This does not affect the verdict.>

## Review attention

<Needs review / Should review / Don't need review, with one short reason.>

## Verdict

<ONE OF: Approve / Approve with nits / Request changes>

## Critical Issues

<Issues that must be fixed before merge. Empty section = none found.>

### <filename>:<line range> — <short title>
**Status:** New | Partly flagged (<author>, <thread link>, open/resolved) | Already flagged (<author>, <thread link>, open/resolved) | Fixed in <sha>
<description of the issue, why it matters, and suggested fix>

## Suggestions

<Non-blocking improvements — better patterns, readability, reuse opportunities.>

### <filename>:<line range> — <short title>
**Status:** <same values as above>
<description and suggestion>

## Nits

<Minor style/naming/formatting observations. Optional.>

## Questions

<Anything unclear about intent or design decisions that should be answered before merge.>

## Existing threads

<One line per open thread that asks for a code change: author, thread link, one-line problem, and "still needs a fix" or "fixed in <sha>, not resolved". Skip summary and walkthrough comments.>
```

### 5. Present findings

After writing the file, give a concise summary to the user:
- Overall verdict
- Review attention and its reason
- Count of critical issues / suggestions / nits, and how many of them are new
- The top 1-3 most important findings, each with its status
- How many existing open threads still need a fix
- Path to the full review file

**Do NOT offer to post the review to GitLab.** Only do so if the user explicitly asks.

## Comment Style

When writing review comments (both in the review file and as draft notes on the MR), be **simple and direct**. State what's wrong and what to do instead. No labels, no preamble.

Good:
- `Use datetime.now(timezone.utc) for a timezone-aware datetime instead of naive datetime.now().`
- `` `region` isn't passed here so it defaults to US. Non-US tenants will hit the wrong SOAP endpoint. Wire the region from `Five9TelephonyConfig` through to the constructor. ``
- `This swallows the exception and returns 200 for a single-event POST. If processing fails, the event is lost with no retry. Re-raise so the caller sees a 500 and can retry.`

Bad:
- `**Suggestion: datetime.now() produces naive datetime** \n\n datetime.now() without a timezone produces a naive datetime, which can cause issues downstream when compared with timezone-aware datetimes. Use datetime.now(timezone.utc) for consistency (timezone is already imported in this file).`
- `**Critical Issue: Webhook has NO authentication** \n\n Every other webhook in the codebase has authentication: ...`

## Posting Draft Comments to GitLab

When the user asks to post comments to the MR, create **unpublished draft notes** via the GitLab API. These are only visible to the reviewer until explicitly published.

### Critical: Creating Draft Notes Correctly

Draft notes **MUST** be created with full position data in a single POST. **Never update a draft note's text via PUT** — this wipes the position fields and breaks GitLab's diff viewer (files become unclickable/uncollapsible).

Use this Python script pattern to create draft notes:

```python
import json, subprocess, tempfile, os, hashlib

DIFF_REFS = {
    "base_sha": "<from glab api>",
    "start_sha": "<from glab api>",
    "head_sha": "<from glab api>",
}

def line_code(path, old_line, new_line):
    """Compute GitLab's line_code identifier for a diff position."""
    path_sha = hashlib.sha1(path.encode()).hexdigest()
    return f"{path_sha}_{old_line}_{new_line}"

def make_position(path, new_line, old_line=None):
    """Build a complete position object with line_range (required for rendering)."""
    old_l = old_line or 0
    lc = line_code(path, old_l, new_line)
    return {
        **DIFF_REFS,
        "position_type": "text",
        "new_path": path,
        "old_path": path,
        "old_line": old_line,
        "new_line": new_line,
        "line_range": {
            "start": {"line_code": lc, "type": "new", "old_line": old_line, "new_line": new_line},
            "end":   {"line_code": lc, "type": "new", "old_line": old_line, "new_line": new_line},
        }
    }

def create_draft_note(note_text, file_path, new_line, old_line=None):
    """Create a single draft note with correct position data."""
    payload = {
        "note": note_text,
        "position": make_position(file_path, new_line, old_line),
    }
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(payload, f)
        tmpfile = f.name

    result = subprocess.run(
        ["glab", "api", "projects/:id/merge_requests/<MR_IID>/draft_notes",
         "--method", "POST", "--input", tmpfile, "-H", "Content-Type: application/json"],
        capture_output=True, text=True, cwd="<repo_root>"
    )
    os.unlink(tmpfile)
    return result
```

### Key Rules

1. **Always use `--input <file> -H "Content-Type: application/json"`** with `glab api`. Other approaches (`--raw-field`, `-F`) do not properly serialize nested `position` objects.
2. **Always include `line_range`** in the position. Without it, GitLab's diff viewer can break.
3. **Compute `line_code`** as `sha1(file_path)_{old_line}_{new_line}`. For new files, `old_line` is 0.
4. **Never PUT to update draft note text.** If you need to change a note, DELETE it and POST a new one.
5. **`new_line`** refers to the line number in the new version of the file (right side of the diff). For new files, this is the line number in the file. For modified files, use the line number from the `@@` hunk header's `+<start>,<count>` side.
6. **Get diff_refs** from the MR metadata (`glab api projects/:id/merge_requests/<MR_IID>` → `.diff_refs`), not hardcoded.

## Parallel Agent Strategy

When the MR touches multiple independent areas (e.g. backend + frontend, or multiple services), dispatch parallel Explore agents to examine codebase standards and find reuse opportunities in each area. Use worktree isolation for any agents that need to check out different branches.

## Red Flags to Always Call Out

- `# type: ignore` or `Any` usage (per CLAUDE.md rules)
- Force pushes or `--no-verify` in scripts
- Missing DB migrations for model changes
- API endpoints mixing global and non-global roles
- Unscoped DB sessions (should use RLS)
- Secrets or credentials in code
- Missing codegen after DTO changes
- Stale MR description that no longer matches the final diff
- A fix or change for a gated feature that also changes behavior for users outside the gate (see step 3a)
