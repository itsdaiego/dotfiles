---
name: create-notion-doc
description: Create a useful private Notion one-pager from supplied context. Use when a user asks to save a concise project brief, bug-bash guide, or personal reference page in Notion.
---

# Create Notion Doc

Create a one-page document that helps its reader understand the subject and act on it. Use this for a durable personal brief, not for a long specification, a database, or an ordinary chat answer.

Before writing, load the `humanizer` skill and use it in embedded mode. Keep claims tied to the supplied sources. If the request cites a Slack thread, project page, issue, or repository, read the relevant material before drafting. Distinguish confirmed behavior from proposed work and open questions.

Use the Notion connector when it is available:

1. Check its tool access and read the Notion-flavored Markdown specification before writing.
2. If the user names a destination, inspect it first and preserve its existing structure. If they do not name one, create the page as a private draft.
3. Set the title in the page properties. Do not repeat it as the first line of the body.
4. Give the reader the shortest useful orientation, then include the workflows, decisions, risks, checks, or prompts that let them use the page. Prefer concrete expectations over generic advice.
5. Link sources that a reader may need to revisit. Do not add unsupported facts, invented owners, or speculative dates.
6. Read back the created or updated page and return its link.

Choose a structure that fits the subject instead of forcing a template. For a project brief, a useful default is: what it does, how it works, current state, what to try, and what to capture. For a bug-bash guide, include safety constraints, a short setup path, expected outcomes, high-signal cases, and a compact findings table.

Never change sharing, move a page, or overwrite an existing page without the user's direction. If Notion is unavailable, produce the humanized Markdown and explain that it was not saved.
