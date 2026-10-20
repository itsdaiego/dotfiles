---
name: butler-sentry-session-metrics
description: Use when someone asks how long users are engaged per session, wants user/firm/org session-length or engagement metrics for the Eve web app, or asks whether/where we track session duration. Pulls Sentry Session Replay durations via the `sentry` CLI and reports overall, per-org (email domain), per-user, and daily-trend distributions, with an optional self-contained HTML dashboard.
---

# Sentry session-length metrics

Engaged-session-length metrics for the Eve web app, pulled from **Sentry Session
Replay** (the only data source that actually measures engaged time) and rendered
as console tables plus an optional HTML dashboard.

The work is done by the bundled script: `scripts/sentry_replay_metrics.py`
(Python 3 standard library only — no pip install, no third-party packages).

## When to use

- "How long are users active per session?" / "average session length"
- "Session/engagement metrics by firm / by user / over time"
- "Do we track session length anywhere?" (answer: not in the app — see below;
  Sentry Replay is the usable proxy)

## Prerequisites

- The standalone **`sentry` CLI** installed and authenticated. Check with
  `sentry auth status`; if not, `sentry auth login`.
- This is the newer `sentry` binary from cli.sentry.dev, **not** the legacy
  `sentry-cli` release tool — the legacy one has no `replay` command and cannot
  do this.

## Running

The script lives at `scripts/sentry_replay_metrics.py` inside this skill's
directory (the loader prints the base directory when the skill activates).

```bash
SKILL_DIR=<this skill's base directory>

# Console report: default 30d / production, error + internal sessions excluded
python3 "$SKILL_DIR/scripts/sentry_replay_metrics.py"

# 7-day window with an HTML dashboard
python3 "$SKILL_DIR/scripts/sentry_replay_metrics.py" --period 7d --html /tmp/replays.html

# One project, more table rows, dump raw metrics JSON too
python3 "$SKILL_DIR/scripts/sentry_replay_metrics.py" --project web_client --top 50 --json /tmp/m.json
```

Flags: `--org` (default `butler-0x`) `--project` `--env` (default `production`)
`--period` (e.g. 24h/7d/30d) `--max` `--top` `--include-errors`
`--include-internal` `--html` `--json`. Run with `--help` for details.

Output blocks: overall distribution (median/mean/p25-p99/max, bounce shares,
total hours, histogram), per-org (email domain), per-user, and a daily trend.
The HTML dashboard has sortable tables and inline SVG charts; it is fully
self-contained and opens with no server.

## Interpreting results — read before trusting the numbers

These are the traps. Always state the relevant ones when you report numbers.

- **Sampling.** Normal sessions are sampled at ~10%; error sessions at 100%.
  Error sessions are wildly over-represented and run far longer (tab-lifetime
  artifacts), so the script **excludes them by default** (`count_errors:0`). Use
  `--include-errors` only to inspect that bias, never for an engagement number.
- **No real orgId — domain is a proxy.** Sentry user context carries only
  `email` + `id`; there is no org tag. Per-org grouping uses the **email
  domain**. It cannot split two firms sharing a domain or merge a firm with
  multiple domains. Consumer domains (gmail, etc., flagged `kind=consumer`) pool
  unrelated solo users; `eve.legal` is internal staff (`kind=internal`, excluded
  unless `--include-internal`).
- **Per-call cap + recency sort.** `sentry replay list` returns ~1000 rows per
  call, newest first. The script paginates via `nextCursor` up to `--max`
  (default 20000). If a window has more sessions than `--max`, you get the most
  recent `--max`, not a random sample over the whole window — widen `--max` or
  shorten `--period` for a complete window.
- **Retention.** Sentry Replay retention is ~90 days; no long-horizon trends.

## Why Sentry Replay (and not Amplitude or an app field)

Butler does not store session length anywhere. The app-level signals are both
unusable for engaged time:

- The frontend's custom `sessionId` (`web_client/src/analytics/Analytics.ts`) is
  set once per browser tab and never expires — it measures tab-open lifetime,
  not engagement.
- Amplitude's native `session_id` is `-1` on every event (cloud-mode Segment to
  Amplitude link, `integrations.Amplitude.session_id` never set), so Amplitude's
  built-in session metrics are empty.

Sentry Replay (`web_client/src/core/logging/Sentry.ts`) is the only source with
a real session model: an inactivity timeout plus a ~60min max-duration cap, with
a `duration` per replay.

## Future direction

The natural next step is closing the orgId gap: join Sentry's `user.email` /
auth0 `user.id` to the app DB or the Snowflake mirror
(`FIVETRAN_DATABASE.APP_DB_PUBLIC`) to attribute sessions to a real `orgId`
instead of an email domain. Use the **`eve-snowflake` plugin**'s
`snowflake-context` skill for the warehouse side of that join.

## Related

- **Linear:** EASE-280 — Track real user session length in product analytics
  (the productionized, warehouse-queryable metric; this skill is the stopgap +
  investigation tool).
- **Plugin:** `eve-snowflake` → `snowflake-context` skill (warehouse queries for the orgId join).
- **Sentry config:** `web_client/src/core/logging/Sentry.ts`,
  `common-ui/src/utils/sentry-react-util.ts`.
