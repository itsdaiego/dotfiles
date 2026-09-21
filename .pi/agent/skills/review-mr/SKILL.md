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

### 2. Understand the change

- Read the MR description and any linked issues for context.
- Identify the category: feature, bugfix, refactor, migration, config change, etc.
- If the intent is unclear from the description and diff, **ask clarifying questions** before proceeding with the review.

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

## Verdict

<ONE OF: Approve / Approve with nits / Request changes>

## Critical Issues

<Issues that must be fixed before merge. Empty section = none found.>

### <filename>:<line range> — <short title>
<description of the issue, why it matters, and suggested fix>

## Suggestions

<Non-blocking improvements — better patterns, readability, reuse opportunities.>

### <filename>:<line range> — <short title>
<description and suggestion>

## Nits

<Minor style/naming/formatting observations. Optional.>

## Questions

<Anything unclear about intent or design decisions that should be answered before merge.>
```

### 5. Present findings

After writing the file, give a concise summary to the user:
- Overall verdict
- Count of critical issues / suggestions / nits
- The top 1-3 most important findings
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
