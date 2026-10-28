---
name: oncall-intake
description: Use when Daiego asks about intake on-call pings, "who pinged me", "what's pending on on-call", "check oncall-intake", wants to move a ping to pending, doing, or done, or wants to open, install, fix, or change the on-call intake dashboard. Tracks Slack pings to @oncall-intake (plus mentions of Daiego in #intake-comms), polled every 5 minutes by a launchd job, and shows them in a local dashboard with Pending, Doing, and Done tabs.
---

# On-call intake tracker

A launchd agent polls Slack every 5 minutes. It finds messages that mention the
`@oncall-intake` user group (`S08UQQB1W01`). It stores them in
`~/ai/eve/oncall-intake/pings.json` and serves a dashboard at http://127.0.0.1:47821.

The same files work for Claude Code and Pi. Both skill directories link to
`~/.agent-customizations/oncall-intake/`.

## Terms

- **Item**: one Slack thread that holds one or more pings. Follow-up pings in the same thread
  update the same item.
- **Status**: the dashboard tab of an item. It is `pending`, `doing`, or `done`. New items start
  as `pending`.
- **Reopened**: a new ping arrived in a thread that was `done`. The tracker moves the item back
  to `pending` and marks it "pinged again".
- **Window**: the dashboard and `list` show only items whose latest ping is from today or the
  previous 6 days (`window_days`, default 7). Older items stay in `pings.json`.

## What counts as a ping

- A mention of the `@oncall-intake` group in any channel, during Daiego's shift. The shift starts
  at Slackbot's "You have been added to the Oncall Intake user group" DM and ends at its "removed
  from" DM. The poller stores them as `shift_started_ts` and `shift_ended_ts` in `pings.json`.
  Pings to the group before the shift belong to the previous on-call person and stay hidden.
- A mention of Daiego (`U0C0Q7F8CFL`) only in #intake-comms (`my_mention_channel_ids`, default
  `C08NLEVC6AY`). Daiego's name comes up too often elsewhere.
- Every message in #case-comms-alerts and #intake-alerts (`source_channel_ids`), during Daiego's
  shift. The dashboard adds these possible intake sources to Pending.
- A message in #prod-alerts (`intake_check_channel_ids`) only when it mentions the group, or when
  the intake check marks it as intake work. Each poll checks up to 10 new #prod-alerts messages.
  Sentry alerts have no Slack text, so the poller reads each message first and stores its text.
  One headless `claude -p --model haiku` run then compares the batch against `intake_scope` in
  `config.json`. The ping stores `intake` and `intake_reason`. An unchecked message stays hidden. A
  #prod-alerts item that Daiego moved out of `pending` stays visible.
- Never a direct message.

## Channels

The group gets pinged in these channels. The list comes from every item in `pings.json` as of
2026-10-20, most pings first. #intake-comms also counts Daiego's own mentions. New channels can
show up at any time. The list leaves out #walle-dyego because the poller ignores it.

| Channel | ID |
| --- | --- |
| #case-comms-alerts | `C0B0XQPDXPX` |
| #intake-internal | `C09CZ4YH4M6` |
| #bug-report | `C08SP7E2S90` |
| #intake-comms | `C08NLEVC6AY` |
| #intake-alerts | `C09AFN8BVDJ` |
| #prod-alerts | `C01NBFKGRCP` |
| #voice-agent-war-room | `C0BDTD1223S` |
| #epd-infra-sec | `C096UF931QS` |
| #release | `C01LXEL9SF4` |
| #epd-case-comms | `C0AL4HF6CM7` |
| #spaulding-firm | `C0BJ4UH3X9D` |
| #dubin-law-group-and-law-office-of-joshua-e--campbell-pllc | `C0B6PLC1TUL` |

The dashboard has multi-select filters for severity and channel. Selecting one or more values
shows cards that match any selected value. The Types menu can hide selected types or show only
selected types. Types include handoff, source channel, @oncall, @you, multiple pings, pinged again,
and you replied. The browser remembers the selections. For the full history, count the channels in
`pings.json`:

```bash
/usr/bin/python3 -c "import json,collections;s=json.load(open('$HOME/ai/eve/oncall-intake/pings.json'));print(collections.Counter(i['channel_name'] for i in s['items'].values()).most_common())"
```

## Automatic status changes

- When Daiego replies in an item's thread after its latest ping, a `pending` item moves to
  `doing`. A new ping after that reply keeps the item `pending`. The tracker never changes a
  `done` item, except to reopen it on a new ping.
- For each visible `doing` item, the poller posts one new top-level message in #walle-dyego
  (`C0C0YFLFUR4`). The message mentions @WALL-E (`U0AF0Q79FA7`) with the ping link and asks for the
  likely root cause and first checks. It never posts in the original thread. It sends once per
  item (`walle_requested_at`) and does not retry a failed send, because a retry could post twice.
  Set `"walle_requests": false` to stop it.
- It sends once per incident, not once per thread. Two items are the same incident when they
  share a key: the item's own thread, a Slack thread that a ping links to, or the first Linear
  issue in the first ping. The later item sends no message. It stores `walle_shared_with` and
  shows the first item's WALL-E thread and session. An item with no shared key, such as a
  top-level "^ look at these" message with no links, still gets its own request.
- Later polls read the WALL-E thread and store the `<url|session>` link WALL-E posts. The Doing
  card shows "WALL-E session" and "WALL-E thread" links.

## Severity

Each item can show a severity: `urgent`, `high`, `medium`, or `low`. The tracker picks the first
source that gives one:

1. The priority set on a Linear issue that the item's first ping links to. Later pings are
   skipped, because replies often list many older tickets. With two linked issues, the higher
   priority wins.
2. An urgency marker in the newest ping that has one. `P0` is urgent, `P1` high, `P2` medium,
   `P3` and `P4` low. `SEV0` and `SEV1` are urgent, `SEV2` high, `SEV3` medium, `SEV4` low. The
   words "urgent", "ASAP", and "emergency", and phrases like "high priority" or "Priority: Low",
   also count. When a ping has more than one marker, the first one wins, so a WALL-E triage of
   "P1 (filed Urgent)" reads as high.
3. The "Suggested priority" line in the linked Linear issue's description.

An item with no source has no severity. The card shows the level and its source, and links to
the Linear issue when the severity comes from one. The dashboard can filter each tab by severity.

The poller fetches Linear issues with `mcp__linear__get_issue` through headless Claude Code, the
same way it reaches Slack. It fetches at most 5 issues per poll, only for open visible items, and
caches them in `meta.linear_issues` in `pings.json`. It fetches a cached issue again after 6 hours.

## Import an on-call handoff

When Daiego gives a handoff doc (usually a Notion page) and asks to add its unfinished items:

1. Read the doc. Keep every item that is not finished and has a Slack thread link. Notion writes
   Slack links as `slackMessage://butlerlabs.slack.com/<channel_id>/<message_ts>/<thread_ts>`.
2. Write `~/ai/eve/oncall-intake/handoffs/<start-date>-<owner>.json` with `doc_title`, `doc_url`,
   `from`, and `items`. Each item has `channel_id`, `channel_name`, `message_ts`, `thread_ts` (when
   it differs), `title` (problem first), `note` (the next step from the doc), and `priority` (the
   doc's "open items" order, or leave it out). Write ticket and MR references in words: a hook
   blocks ticket IDs and MR numbers in non-Markdown files, and the card links to the doc.
3. Run `import-handoff <path>`. Items that are already tracked keep their status and get the
   handoff details. New items start as `pending`.

Handoff items skip the shift and window filters. A reply from Daiego moves one to `doing` only
when the reply comes after the import. The "Handoff priority" sort orders them by priority.

## Commands

```bash
ONCALL=~/.agent-customizations/oncall-intake/oncall.py

/usr/bin/python3 $ONCALL status                      # daemon, token, last poll, counts per tab
/usr/bin/python3 $ONCALL list --status pending       # newest first; add --oldest to reverse
/usr/bin/python3 $ONCALL list --severity urgent      # urgent | high | medium | low | none
/usr/bin/python3 $ONCALL move <item-id> doing         # pending | doing | done
/usr/bin/python3 $ONCALL poll                        # poll Slack now
/usr/bin/python3 $ONCALL poll --since-days 7         # backfill; merge skips pings already tracked
/usr/bin/python3 $ONCALL import-handoff <json>       # add unfinished items from a handoff doc
/usr/bin/python3 $ONCALL check-intake --limit 100     # check unchecked #prod-alerts messages now
/usr/bin/python3 $ONCALL install                     # write the launchd plist and start it
/usr/bin/python3 $ONCALL uninstall                   # stop the agent, keep the data
```

Open the dashboard with `open http://127.0.0.1:47821`.

## How to answer common requests

- "Who pinged me?" or "what's pending?": run `status`, then `list --status pending`. Summarize
  each item in one line: who, channel, when, what they want, and the Slack link.
- "I'm on it" or "done with X": find the item ID with `list`, then run `move`. Confirm the new
  status.
- To read the full thread before you summarize, use the Slack tools on the item's permalink.
- Do not reply in Slack for Daiego unless Daiego asks for that exact message.

## How the poller reaches Slack

The poller has two sources. It uses the first one that is available.

1. **Slack user token.** If the macOS Keychain has service `oncall-intake-slack`, account `slack`,
   the poller calls the Slack Web API directly. The token needs the `search:read` and `users:read`
   user scopes. Never print, log, or copy the token.
2. **Slack MCP through headless Claude Code (default).** Without a token, each search starts one
   `claude -p --model haiku` run. That run makes one call to
   `mcp__slack__slack_search_public_and_private` with the Slack MCP login that Claude Code already
   has. The poller reads the raw tool result from the `stream-json` events and parses it itself,
   so the model cannot drop or rewrite messages. One run takes about 15 seconds.

Each poll runs these searches: `<!subteam^S08UQQB1W01>` (how bots write the group mention),
`<@S08UQQB1W01>` (how people write it), `<@U0C0Q7F8CFL>` in each `my_mention_channel_ids` channel,
and `from:<@U0C0Q7F8CFL> is:thread` (Daiego's thread replies, for the move to `doing`). While a
WALL-E session is missing, it also searches #walle-dyego and reads each WALL-E request thread. A poll searches from one hour
before the last successful poll. The overlap catches messages that Slack indexed late.

The child run drops `ANTHROPIC_API_KEY` from its environment. The key in Daiego's shell has no
credit, and without it Claude Code uses the normal Claude login.

`config.json` filters: `ignore_user_ids` (default `USLACK`, Slack system messages) and
`ignore_channel_ids` (default `C0C0YFLFUR4`, `#walle-dyego`, where WALL-E answers Daiego's own
questions).

## Files

| Path | Purpose |
| --- | --- |
| `~/.agent-customizations/oncall-intake/oncall.py` | Poller, dashboard server, and CLI. System Python 3.9, standard library only. |
| `~/.agent-customizations/oncall-intake/dashboard.html` | Dashboard page that the server serves. |
| `~/ai/eve/oncall-intake/pings.json` | Tracked items and poll metadata. |
| `~/ai/eve/oncall-intake/config.json` | IDs, poll interval, lookback days, port. Restart the agent after a port change. |
| `~/ai/eve/oncall-intake/daemon.log` | Daemon output. |
| `~/Library/LaunchAgents/com.daiego.oncall-intake.plist` | launchd agent. `KeepAlive` restarts it after a crash or a reboot. |

## Troubleshooting

- `last error: not_allowed_token_type` or `missing_scope`: the token is a bot token or lacks
  `search:read`. Search needs a user token (`xoxp-`).
- `claude -p failed: Credit balance is too low`: the run used an API key. Check that
  `ANTHROPIC_API_KEY` is not set in the launchd environment (`launchctl getenv ANTHROPIC_API_KEY`).
- `claude -p made no Slack call`: the Slack MCP login expired. Run `/mcp` in Claude Code and
  reconnect `slack`.
- Dashboard does not load: run `status`. If the daemon is not loaded, run `install`. Check
  `daemon.log`.
- A ping is missing: Slack search indexes new messages with a delay of up to a few minutes. The
  next poll picks it up. The search looks back `lookback_days` days, 7 by default.
