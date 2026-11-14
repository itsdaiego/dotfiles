---
name: create-doc
description: Create or revise a shared written doc (Notion page, design doc, discovery notes, or similar) so it reads like a person wrote it, not an agent. Use when the user runs /create-doc, asks to write, draft, update, or "fix up" a Notion doc or design doc, or says a doc sounds robotic, confusing, or AI-written. Always pairs with the humanizer skill for the prose pass; does not replace project-specific doc-formatting rules (e.g. matching another doc's existing structure).
---

# Create a doc

Write or revise the doc, then run every paragraph of prose through `humanizer` in embedded mode before publishing. This is not optional — the default agent writing style (hedging, bold-label lists, "not X, but Y" contrasts, staged openers, forced triads) is exactly what makes a doc read as robotic instead of human, and that is the complaint this skill exists to fix.

## Rules

1. Load `humanizer` and apply it to every block of natural-language prose in the doc — paragraphs, section intros, open questions, diagram callouts. Never apply it to code blocks, file paths, identifiers, commands, MR/ticket links, or table data cells that are just facts (a table's prose explanation column still gets humanized).
2. Follow the user's global "Writing docs and MR descriptions" rule: full clear sentences, no caveman/compressed style, nothing truncated or abbreviated to save tokens, every fact/decision/caveat/reason kept. Humanizing a doc means making it sound human — it never means shortening it or dropping content.
3. Match whatever structure the user actually asked for (length, sections, formatting conventions borrowed from another doc). This skill governs *how the sentences sound*, not the doc's shape — don't re-architect a doc the user didn't ask you to re-architect.
4. Before publishing an update to an existing doc, fetch its current content first. Make the smallest edit that fixes the prose; don't silently rewrite facts, links, or structure while doing a language pass.
5. If the user's doc instructions conflict with a specific, explicit request (e.g. "no names," "no fabricated motivation," "keep it short") those explicit requests win — humanizer and the docs-writing rule operate inside those constraints, not over them.

## Why this exists

Agents default to a writing style that reads as obviously AI-generated: inflated claims, sales language, bolded label-sentences, every list structured as a triad, dashes standing in for real connective sentences. A design doc or Notion page that other humans will read and review should read like a colleague wrote it. This skill makes that pass automatic instead of something the user has to ask for every time.
