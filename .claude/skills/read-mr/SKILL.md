---
name: read-mr
description: Use when someone wants to understand a GitLab MR or GitHub PR quickly — "what does this MR do", "summarize !21182", "explain this PR", "TL;DR this MR", or pastes an MR link and asks for the key points. Reads the description and the diff, then produces a short digest optimized for human understanding: a TL;DR, the 3–6 ideas that matter, what changes in behavior, the risks, where to look in the diff, and gaps or mismatches between the description and the code. Read-only; never comments on or edits the MR.
---

# Reading an MR

Long MR descriptions often contain every fact but no priorities. The reader has to decide what matters. This skill does that work: it ranks, groups, and translates the MR into the few ideas a person needs to hold in their head.

Optimize for **understanding**, not coverage. The original MR is one click away for anyone who wants every detail. The digest is a map, not a copy.

Companion skill: `write-mr` writes descriptions. This skill reads them.

## Workflow

1. **Fetch the MR.** Accept a URL, `!<iid>`, an iid plus project, or a branch name.
   - GitLab MCP: `get_merge_request` for metadata and description, then `include: ["diffs"]` (stats first; `detail: full_patch` for the files that matter), and `include: ["commits"]` when the description is thin.
   - Or `glab mr view <iid> -R <project>` and `glab mr diff <iid> -R <project>`.
   - Default project for Eve work: `butlerinc/butler`.
2. **Read the diff, not only the description.** The description is a claim. The diff is the truth. Note what the diff changes that the description does not mention, and what the description claims that the diff does not show.
3. **Find the few ideas that matter.** Ask, in order:
   - What behavior changes, and for whom?
   - Why does it change?
   - What can break, and what must happen in a specific order?
   - What should a reviewer look at hardest?
4. **Write the digest** using the template below.
5. **Stop.** Offer more detail on any section. Do not post anything to the MR.

## Digest template

```markdown
**!<iid> — <title>** · <state> · <author>

**TL;DR:** <1–2 plain sentences. What changes and why. No identifiers unless
they are the point.>

**Key points**
1. <The most important idea, in plain words. Then, if useful, the code name.>
2. ...
(3–6 points, ranked by importance, one idea each.)

**Before → after**
- <Behavior>: <before> → <after>
(Only behavior a user, caller, or operator notices. Skip if nothing observable changes, and say so.)

**Risk and rollout**
- <Deploy order, rollback trap, who loses access, data deletion, shared behavior change.
  "Low risk: <reason>" when there is nothing.>

**Where to look in the diff**
- `<path>` — <why this file deserves attention>
(2–4 files. Skip generated files, snapshots, and mechanical renames.)

**Gaps and mismatches**
- <Stale sections, claims the diff does not back up, missing deploy/rollback
  info, untested paths, open questions the author left unanswered.
  "None found" when there are none.>
```

Add a **Terms** line under the TL;DR when the MR depends on 2+ project terms the reader may not know (for example, "watermark: the timestamp up to which calls are already discovered").

## Rules

- **Rank, don't list.** Key point 1 is the thing the reader would regret missing. Cut anything that does not change what the reader thinks or does.
- **Plain words first, identifiers second.** "Orgs with intake on now see the Telephony settings" before `IntegrationsTab` / `LeadsPage`.
- **Compress noise, keep signal.** Ten test commands become "Tests: backend, frontend, and a manual app check pass". Keep any test result that failed, was skipped, or ran before the final changes.
- **Numbers that matter stay exact.** Counts of affected orgs, traffic numbers, timeouts, and versions stay as written. Rounding is fine only when the original rounds.
- **Never invent.** If the MR does not say something (deploy order, rollback), list it under Gaps. Do not fill it in as fact.
- **Surface hidden blast radius.** A change to a shared module (retry policy, auth, base client, feature flags, migrations) goes in Key points or Risk even if the description buries it.
- **Fit one screen.** Aim for 150–300 words. Go longer only for very large MRs, and then keep the TL;DR and Key points just as short.
- **Write in full, clear sentences.** No telegraphic or caveman style, even if the chat uses it. The digest is for a human who wants to understand fast.
- **Read-only.** Never comment, approve, or edit. If the user wants the description fixed, suggest `/write-mr`.

## Self-check

- [ ] Someone who reads only the TL;DR knows what the MR does and why.
- [ ] Key points are ranked, one idea each, 3–6 of them.
- [ ] Cross-cutting or shared-module changes are visible, not buried.
- [ ] Risk and rollout says something concrete, or says why the risk is low.
- [ ] Every claim is backed by the description or the diff. Anything missing is under Gaps.
- [ ] The digest fits on one screen.
