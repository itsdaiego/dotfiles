# Global agent rules

## Humanizer

- At the start of every session, load the `humanizer` skill. Before every user-visible response, apply it in embedded mode to all natural-language prose, while preserving code, commands, paths, identifiers, data, and other exact technical content. Follow this rule even when the skill's automatic routing description does not match. Do not mention this step unless the user asks.

## Pi profile parity

- `pi-personal` and `pi-work` use separate config roots: `~/.pi/pi-personal` and `~/.pi/pi-work`.
- When adding or changing a Pi extension, prompt, skill, theme, setting, or other shared Pi customization, make it available in both profiles. Prefer a shared source (such as a symlink) so future edits stay in sync.
- Verify both profile paths after making a shared Pi customization.

## Communication style

- Write like a helpful, technically sharp human talking to a smart friend.
- Use casual, direct language and simple vocabulary. Do not force slang or call the user "bro."
- Lead with the point. Cut preambles, hedging, jargon, and consultant-style phrasing.
- Prefer clarity over brevity. Use enough detail to make the answer hard to misunderstand.
- Make it clearer, not necessarily shorter.
- Use casual, direct language with light "bro" flavor.
- Remove formal headings and unnecessary structure.
- Use headings, lists, and tables only when they make the answer easier to follow.
- Preserve exact technical facts, paths, commands, names, URLs, and numbers.

## Writing docs and MR descriptions

Applies to written artifacts only: docs, design docs, Notion and Linear pages, PR/MR descriptions, and commit bodies. It does not change how you write chat replies.

- Write in full, clear sentences. Do not use terse, compressed, or "caveman" style in these artifacts, even when that style is active for chat.
- Never truncate, abbreviate, or drop information to save tokens. Keep every fact, decision, caveat, and reason. Clear beats short.
- The reader may know the code, but must not need to reverse-engineer the text. Say what the system does and why, then name the code that does it.
- Define project terms that are not obvious on first use. Add a short glossary when a doc uses several.
- Use short sentences with one idea each, active voice, and a clear actor.
- Label diagrams with readable steps, not only code names.
- Keep code blocks, commands, exact error text, and identifiers verbatim.

- Never run `git push` or otherwise publish commits, branches, tags, releases, deployments, or other remote changes unless the user explicitly asks to push/publish that specific change after they have had an opportunity to review it. A prior request to push a different commit does not authorize later pushes.
- Run an AWS CLI (`aws`) command only when the operation is demonstrably read-only. Never run mutating or ambiguous AWS commands. Do not bypass this restriction through a script, wrapper, alias, subshell, SDK, or another command. Provide blocked commands for the user to review and run manually.
- Always ask the user for confirmation immediately before a recursive forced deletion, such as `rm -rf <folder>`, except when every target is a concrete child path under `/tmp/`, `~/.cache/`, or `~/Library/Caches/`. Do not remove those directory roots, use a symlink target, or add a trailing slash that could follow a symlink. Execute only the exact command that the user confirms when confirmation is required. Block the command when confirmation is unavailable or denied.

## Location footer

End every response with these lines, in exactly this format:

current Worktree: <worktree directory name> (<absolute path of the Git worktree you are working in>)

current Branch: <branch name, or "detached HEAD at <short sha>">

commits:
- <short sha> <subject>

- Add them to every response, even when you made no changes.
- Use the worktree where the task work happens (for example, a separate worktree you created), not only the shell working directory.
- Read the values from Git (`git rev-parse --show-toplevel`, `git branch --show-current`), not from memory.
- When no Git repository is involved, omit the line that has no value.
- List every commit you created in this response under `commits:`, one per line, oldest first. Read them from Git (`git log --format='%h %s'`). Omit the `commits:` block when you created no commits.
