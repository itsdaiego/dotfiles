---
name: read-issue
description: >-
  Use when someone wants a simple explanation of a Slack thread, Linear issue,
  GitHub issue, incident, support conversation, or other work discussion. Read
  the supplied context and produce a concise, read-only digest that clarifies
  the decision, current state, ownership, and next step.
---

# Reading an issue or discussion

Threads and issue trackers collect context over time. Important details get mixed with old proposals, side discussions, and implementation notes. This skill explains the current situation in plain language so a reader can quickly understand what happened, what was decided, and what needs to happen next.

Optimize for understanding, not coverage. The source is available to anyone who needs every message. The digest should make the source easier to follow.

Companion skill: `read-mr` explains a code change and its diff. Use this skill for the discussion, request, or operational context around the work.

## Workflow

1. **Accept the complete request.** Do not require a particular URL format.
   - A Slack permalink, Linear issue URL or identifier, GitHub issue, incident URL, pasted thread, or plain-language request is enough.
   - If the request contains a link, open the linked item and its replies, comments, and directly referenced context.
   - If it links to several related items, read enough of each to explain the current state. Do not make the reader choose an item when the links clearly describe one topic.
   - If the reference is genuinely ambiguous, name the likely candidates and ask which one to read.
2. **Read the source in order.** Separate the original request, later evidence, decisions, and unresolved questions. Treat the most recent confirmed information as current. Do not treat a proposal as a decision unless the thread confirms it.
3. **Follow only useful references.** Open linked MRs, issues, documents, incidents, or dashboards when they change the explanation. Read an MR through `read-mr` when the code diff matters. Do not turn the digest into a link-by-link summary.
4. **Find the few ideas that matter.** Ask:
   - What is the actual problem, request, or decision?
   - What is true now, and what changed from the original report?
   - Who owns the next action, and what blocks it?
   - Which disagreement, risk, or missing fact could change the outcome?
5. **Write the digest** using the template below.
6. **Stop.** Do not post, react, edit, assign, change status, or create follow-up work unless the user explicitly asks.

## Digest template

```markdown
**<source type>: <title or short topic>**

**TL;DR:** <One or two plain sentences that explain the situation and the current direction.>

**What happened**
1. <The most important context or change, in plain words.>
2. <The next most important fact.>
3. <Only include more points when they affect the decision or next step.>

**Decision and current state**
- <What the group decided, or say that no decision is recorded.>
- <What is happening now.>

**Next step**
- <Owner and action. Say when the owner, action, or deadline is not clear.>

**Open questions and risks**
- <Unresolved question, disagreement, dependency, or risk that matters.>
- <"None recorded" when the source settles the topic.>

**Useful context**
- <Only the links, terms, or prior events that help the reader act.>
```

Add a **Terms** line under the TL;DR when the discussion depends on two or more project terms that the reader may not know.

## Rules

- **State the current answer first.** Lead with the decision or status. Give history only when it explains that answer.
- **Rank, do not list.** Include the information that changes what the reader thinks or does. Cut acknowledgements, repeated agreement, and implementation detail that does not affect the outcome.
- **Use plain words first.** Translate internal names and abbreviations. Include an identifier only when it helps the reader find or act on the work.
- **Keep the timeline honest.** Clearly distinguish a suggestion, an investigation result, a confirmed decision, and planned work. Say when a later message supersedes an earlier one.
- **Never invent.** If the source does not identify an owner, deadline, decision, or resolution, say so. Do not infer agreement from silence.
- **Keep links purposeful.** Mention a linked MR, issue, dashboard, or document only when it supplies evidence, tracks the next action, or gives required context.
- **Fit one screen.** Aim for 150 to 300 words. Go longer only when the source contains several decisions that need separate treatment.
- **Write in full, clear sentences.** The digest is for a person who wants to understand quickly.
- **Read-only.** Never send a Slack message, react, comment, edit an issue, change an assignee or status, or create a ticket. If the user asks to change the source, confirm the intended change separately.

## Self-check

- [ ] Someone who reads only the TL;DR understands the situation and current direction.
- [ ] The digest separates confirmed decisions from proposals and open questions.
- [ ] The next step names an owner when the source provides one.
- [ ] The digest calls out any important disagreement, blocker, or uncertainty.
- [ ] Every claim is supported by the source or is clearly marked as missing.
- [ ] The digest fits on one screen.
