---
name: table-view
description: Render tabular results back to the user in the format that fits the current surface — a plain ASCII box table in a terminal, a friendly native-feeling table in a desktop or GUI app. Use whenever another skill or a reply needs to present rows of data (a to-do list, a review queue, search results, a comparison) instead of hand-formatting a table.
---

# Table view

One shared way to show tabular data, so every skill stops hand-rolling its own ASCII table and instead gets a rendering that matches where the person is actually reading it: a raw terminal versus Claude Code, Pi, or Codex's own desktop/GUI surface.

This skill does not fetch or shape data. The caller (another skill, or the main task) already has the rows; this skill only decides how to draw them and draws them, inline, in the same reply.

## When to use this

Use it any time a reply is about to present more than a couple of rows of structured data: columns and rows, a priority/urgency dimension, links out to sources. Typical callers: `to-do`, `review-queue`, `oncall-intake`, or any one-off comparison table. Skip it for a single fact or a short prose answer — this is for genuine tables.

## Input contract

The caller hands this skill, in its own prompt or inline:

- **Columns**: ordered header labels.
- **Rows**: one array/object per row, values aligned to the columns.
- **Optional per-row tag**: a severity/urgency/category label (e.g. `urgent`, `warn`, `info`, `neutral`, or a custom set the caller defines) used for grouping and emphasis in the friendly render, and folded into a plain text badge in the ASCII render.
- **Optional links**: a label + URL per row or per cell, instead of a bare URL.

Keep cell text short at the source. This skill does not rewrite the caller's content, only its presentation — wrap long text onto continuation rows/lines rather than truncating meaning.

## Step 1 — decide the surface: terminal or desktop/GUI

Decide once per reply, not per table. Use the first signal that applies, in this order:

1. **Explicit environment statement.** Claude Code's own system context says outright when the session "is running within the Claude desktop app" (or similarly names a desktop app) versus a bare CLI/terminal invocation. Pi and Codex give an equivalent environment banner or tool-availability signal at session start. Trust an explicit statement over any heuristic below.
2. **Desktop-only tool availability.** A strong, harness-agnostic signal: desktop/GUI sessions typically expose tools a terminal session does not — for Claude Code, the `Artifact` family of tools (`Artifact`, `ArtifactComments`, `ArtifactData`) and the `mcp__ccd_*` session/view tools; for Pi or Codex, their own equivalent desktop-panel or preview tools. If any such tool is available this turn, treat the surface as desktop/GUI. Their absence, with only plain file/shell/edit tools available, points to a terminal.
3. **Environment variables, as a last resort.** A classic terminal exposes `$TERM` (e.g. `xterm-256color`) with no desktop-app markers; a GUI chat surface usually either doesn't expose a raw terminal `$TERM` to the agent at all or states its app context directly (per #1). Don't poll for these proactively — only fall back to them when #1 and #2 are both silent.
4. **Still unknown:** default to the friendly render (see below). A clean Markdown table degrades acceptably almost everywhere; a box-drawing ASCII table forced onto a surface that renders Markdown just looks like noise.

Never ask the user which surface they're on — decide from context and render. If the user explicitly asks for the other format ("give me plain ASCII", "just the raw text"), honor that request over the detected default for that reply.

## Step 2a — render for a terminal

Plain monospace ASCII, box-drawing characters, fixed-width columns sized to content:

```text
+--------+----------------------+------------------+------------------+------------------+
| Source | What needs attention | From             | When             | Link             |
+--------+----------------------+------------------+------------------+------------------+
| Slack  | Check the deploy log | Alex Kim         | 2026-10-21 09:14 | Slack thread     |
+--------+----------------------+------------------+------------------+------------------+
```

Rules:

- Keep cell text short; wrap long text onto a following row inside the same cell's column rather than widening the table past a readable line length.
- Fold any urgency/category tag into plain text in its own cell or as a short prefix (`[due tmrw]`), never color or emoji — a terminal can't reliably render either.
- Use a short stable link label instead of a bare URL in the cell; if the client can't turn it into a clickable link, print the raw URL once on a continuation line below the row.
- One blank line before and after the table; no other decoration.

## Step 2b — render for a desktop/GUI app

Default to a clean Markdown table (GitHub-flavored pipe table) — virtually every desktop/GUI chat surface (Claude desktop, Pi's desktop app, an IDE webview) renders these natively:

- Short, scannable headers; no header wider than its typical cell.
- Turn an urgency/category tag into a short leading badge in its own cell or prefixed to the first cell — a word or a small set of consistent emoji (🔴 urgent, 🟡 open, 🔵 informational, ⚪ background) read fastest; keep the same mapping across a whole reply.
- Real Markdown links (`[label](url)`), never a bare URL sitting in a cell.
- Group rows under a short bold subheading per urgency/category when the caller gave more than ~2 groups, instead of one flat table with a repeated tag column — it reads faster and matches how the information will actually be scanned.

Escalate past a plain table only when it earns its weight, and only on a harness that has the capability:

- **Many rows, several groups, or data likely to be reopened/shared** (a dashboard-like digest, not a one-off answer) + the `Artifact` tool is available this turn (Claude Code desktop) → build a small HTML page instead: grouped cards or a styled table, one badge per urgency tier, real links. Follow this session's own artifact-design guidance for tokens, theming, and the publish contract; don't reinvent it here.
- **A handful of rows, a quick one-off question** → just the Markdown table. Don't reach for an artifact to answer something that fits in six lines of chat.
- On Pi or Codex's desktop/GUI surface without an equivalent rich-page tool, stop at the Markdown table — there's nothing richer to escalate to, and a plain table there is already the friendly render.

## What this skill never does

- Never silently drops data to fit a prettier shape — if a column doesn't fit the chosen format, wrap it, don't cut it.
- Never asks the user to confirm which surface they're on before rendering.
- Never persists state or writes files outside an artifact the caller explicitly asked for; this is a presentation step for the current reply, not a report-generation pipeline.
