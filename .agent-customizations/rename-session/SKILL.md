---
name: rename-session
description: Rename the current agent session to reflect what it is actually about, not the literal text of the first message. Use when the user asks to rename, relabel, or retitle this session or chat, says the session name is wrong, stale, or just echoes the first prompt, or runs /rename-session. Works with Pi sessions, local Herdr panes, Rex agent entries, Claude Code Remote sessions, or any combination of them, and updates every naming surface that applies.
---

# Rename session

A session name should describe the work, not quote the first message. Many surfaces default to
truncating the literal first user prompt as the title (for example Claude Code Remote's `title`
field). That is almost always the wrong name once the conversation has moved — a session opened
with "can you check X" and spending the next hour on Y should be named for Y.

This skill infers the session's real intent from the conversation so far and pushes that name to
every naming surface this session actually has, instead of guessing which one applies.

## Steps

1. **Infer the intent, not the literal text.** Read back over the conversation (not just the first
   message) and summarize what the session is actually doing or has mostly been doing. Prefer the
   dominant or most recent substantive task over an initial throwaway question. Do not copy a
   sentence verbatim from the transcript — compress it into a short label of the underlying task.

2. **Detect which naming surfaces apply to this session**, and update every one that does — a
   session can have more than one (e.g. a Herdr-wrapped bridge session is also a Claude Code Remote
   session):

   - **Pi session**: true when the `set_agent_session_name` tool is available. Call that tool with a
     lowercase ASCII kebab-case task slug. It persists the name through `pi.setSessionName()` so the
     name appears in `/resume`, Pi Pocket, and other Pi session listings. It also mirrors the same
     name to Herdr or Rex when the current Pi process runs inside one of those harnesses. Prefer this
     tool over changing a terminal title or editing a session JSONL file directly.
   - **Herdr-managed pane (local)**: true when `$HERDR_PANE_ID` is set and the `herdr` binary is on
     `PATH`. Herdr names a terminal pane, so the name must always be a lowercase ASCII kebab-case
     slug — dashes only, no spaces, no punctuation, no freeform text — 2–5 words, at most 32
     characters. Run `herdr agent rename "$HERDR_PANE_ID" "<slug>"`. Never rename a subagent's pane
     — only the root agent for the current pane.
   - **Rex agent session (local)**: true when `$REX_SESSION` and `$REX_BLOCK` are set and either
     `rex` is on `PATH` or `$REX_BIN_DIR/rex` is executable. Rex represents the current agent in
     the sidebar with its terminal block, so rename that block rather than the containing Rex
     workspace. Use the same lowercase ASCII kebab-case convention as Herdr: dashes only, no spaces
     or punctuation, 2–5 words, and at most 32 characters. Run
     `rex block rename -s "$REX_SESSION" "$REX_BLOCK" "<slug>"`; when `rex` is not on `PATH`, run
     `"$REX_BIN_DIR/rex" block rename -s "$REX_SESSION" "$REX_BLOCK" "<slug>"`. After a successful
     explicit rename, pin the label so automatic naming does not overwrite it:
     `state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rex/block-name-locks"; mkdir -p "$state_dir";
     printf '%s\n' "<slug>" > "$state_dir/${REX_BLOCK#block:}"`. Rename only the current block unless
     the user explicitly identifies another one. Remove the pin only when the user asks to resume
     automatic topic naming.
   - **Claude Code Remote session (cloud/mobile, "CCR")**: true when the
     `claude-code-remote` MCP tools are available in this session. Call `get_session` with no
     `session_id` to resolve this session's own ID, then call `set_session_title` with that ID.
     Unlike Herdr, CCR's title field is freestyle text — normal words, spaces, punctuation, no
     kebab-casing — so write it as a short, human-readable phrase. Keep it under roughly 60
     characters.

   If neither surface is detected, say so and stop — there is nothing to rename.

3. **Apply the same inferred intent to every detected surface**, formatted for each surface's
   convention: a lowercase-with-dashes slug for Pi, Herdr, and Rex, and a freestyle readable title for
   CCR. Do not silently skip one because another succeeded. When the user explicitly supplies a
   label, use it exactly when the target accepts it, even when it is a single word such as `eve`.

4. **Report back** which surface(s) were renamed and to what, or why a surface was skipped (not
   detected, command failed, etc.). Do not report success for a surface that was not actually
   detected as applicable.

## When not to rename

- Don't rename a session that already has a name that still matches its current dominant intent —
  re-running this skill should be a no-op in that case, not a cosmetic shuffle.
- Don't invent a name from a single ambiguous or off-topic message when the rest of the session
  gives a clearer signal — weigh the whole conversation.
- Don't rename any session other than the current one unless the user explicitly names a different
  session ID or pane to rename.
