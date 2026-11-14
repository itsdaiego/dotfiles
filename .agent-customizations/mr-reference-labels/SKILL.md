---
name: mr-reference-labels
description: Use whenever a reply names a merge request or pull request by number, such as "!23127", "MR 23127", "PR #512", or "the first MR". Adds the MR's title and author in parentheses after the number so Daiego can tell the MRs apart without opening them. Applies to chat replies, status reports, summaries, and sub-agent reports that you relay. Does not apply to files you write, such as MR descriptions, commit messages, review files, or source code.
---

# MR reference labels

Daiego works on many MRs at once, and a bare number is hard to identify. Whenever a reply names an MR or PR by number, add its title and author in parentheses.

## Format

```
!23127 (fix(INTAKE-318): spell-back names, fuzzy name match, free-form continuation consent, by dyego.rodrigo)
```

- Number first, then parentheses with the title, a comma, and `by <username>`.
- Use the GitLab username for GitLab MRs and the GitHub login for GitHub PRs.
- Keep the title as it appears on the MR. Cut a title longer than 80 characters at a word boundary and add `…`.
- Link the number when the full URL is known: `[!23127](https://gitlab.com/butlerinc/butler/-/merge_requests/23127) (title, by author)`.

## When it applies

- Add the label at every mention in prose and in bullet lists, not only the first one. A short reply needs it as much as a long one.
- Add it to a number that comes from a tool result, a sub-agent report, or a message you relay. Look the number up first.
- Add it when the user refers to an MR by position, such as "the first MR". Name the number and the label in your answer.

## When it does not apply

- In a table that already has Title and Author columns for that MR. Do not repeat them in the cells.
- In a file you write: MR descriptions, commit messages, review files, code, comments, and docs. Those keep plain numbers, because a title inside them goes stale and can break the format of the file.
- Inside a quoted error, log line, command, or URL. Keep those exact.

## How to look it up

Resolve each number once per session, then reuse the result. The title and author of an open MR rarely change within a session. Look it up again when the MR was retitled or you pushed a rename.

GitLab (the Butler project is `butlerinc/butler`):

```bash
glab api projects/butlerinc%2Fbutler/merge_requests/<iid> | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'], '|', d['author']['username'])"
```

Look up several MRs in one command when a reply names more than one.

GitHub:

```bash
gh pr view <number> --repo <owner>/<repo> --json title,author --jq '.title + " | " + .author.login'
```

If a lookup fails, still name the number. Write `(title and author not found)` in the parentheses and say why in one short phrase. Never guess a title or an author.

## Author wording

The author is the account that opened the MR, not necessarily who wrote the code. When the branch name suggests another origin, such as a `walle/` branch, say so only when the user asks who built it.
