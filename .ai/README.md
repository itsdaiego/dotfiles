---
title: Shared agent brain
tags: [index]
---

# Shared agent brain

This folder is the shared memory for every agent harness on this Mac: Claude Code, Codex, and Pi. Each harness reads and writes the same Markdown files here. The files use Obsidian conventions, so you can open `~/.ai` as an Obsidian vault.

## Layout

| Path | What it holds |
| --- | --- |
| `README.md` | This file. The rules for the brain. |
| `eve/` | Work at Eve (Butler, Intake team). |
| `eve/brain.md` | The live to-do list: promises Daiego made, requests from other people, and MR reviews. |
| `eve/weekly/YYYY-Www.md` | The plan for one week, such as `eve/weekly/2026-W47.md`. |
| `eve/log.md` | A short dated log of what was done and what was closed. |

Add a new top-level folder for a new area of life or work, such as `personal/`. Do not mix Eve work into it.

## Rules for agents

1. Read `eve/brain.md` before you plan Eve work, answer "what should I do", or run a `brain` skill.
2. When Daiego promises something in the session, or someone asks Daiego for something, add it to `eve/brain.md` under the correct section.
3. When an item is done, move it to `eve/log.md` with the date and the evidence (a link, a commit, or an MR). Do not delete it silently.
4. Keep one line per item: `- [ ] <action> — <who/where> — <date> — [link](url)`. Add `📅 YYYY-MM-DD` for a deadline.
5. Each item links to its source (Slack, Gmail, Granola, Linear, GitLab, or Notion). An item without a source is marked `(no source)`.
6. Link related notes with `[[wikilinks]]`, such as `[[eve/weekly/2026-W47]]`.
7. Never store secrets, tokens, customer data, or message bodies here. Store a one-line summary and a link.
8. Write in plain, short sentences. Keep the files small enough to read in one pass.

## Relation to other memory

- This README is tracked in the dotfiles repo, which is public. The work notes under `eve/` and any other folder stay on this machine. Git ignores them. Never move work notes into the repo.

- Harness memory (for example `~/.claude/projects/*/memory/`) holds preferences and lessons for one harness. This folder holds shared work state that every harness needs.
- The `to-do-backlog` skill's machine backlog lives at `~/.local/state/to-do-backlog/backlog.json`. This folder is the human-readable source of truth.
