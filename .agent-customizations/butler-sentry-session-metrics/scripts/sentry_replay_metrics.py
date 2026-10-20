#!/usr/bin/env python3
"""Pull Sentry Session Replay durations and report engaged-session metrics.

Sentry Replay is the only source today that measures engaged session length
with an inactivity timeout + ~60min cap (see EASE-280). This script shells out
to the `sentry` CLI (`sentry replay list`), paginates past the per-call cap via
the returned nextCursor, and computes: overall distribution, per-org (email
domain) breakdown, per-user breakdown, and a daily trend. Optionally emits a
self-contained HTML dashboard.

Prereqs: the `sentry` CLI installed and authenticated (`sentry auth status`).
No third-party Python packages — standard library only.

Usage:
    python sentry_replay_metrics.py [options]

    --org <slug>        Sentry org slug (default: butler-0x)
    --project <slug>    Scope to one project slug (default: whole org)
    --env <name>        Environment filter (default: production)
    --period <window>   Lookback window, e.g. 24h, 7d, 30d (default: 30d)
    --max <n>           Max sessions to pull (default: 20000)
    --include-errors    Include error sessions (default: excluded; they are
                        100% sampled vs ~10% for normal sessions, so including
                        them biases durations upward)
    --include-internal  Include eve.legal (internal) users (default: excluded)
    --top <n>           Rows in per-org/per-user console tables (default: 25)
    --html <path>       Also write a self-contained HTML dashboard
    --json <path>       Also write the computed metrics as JSON

Inputs:  the `sentry` CLI (live Sentry Replay data)
Output:  console tables; optional HTML dashboard and/or metrics JSON
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

CONSUMER_DOMAINS = {
    "gmail.com",
    "outlook.com",
    "hotmail.com",
    "yahoo.com",
    "icloud.com",
    "aol.com",
    "protonmail.com",
    "proton.me",
    "me.com",
    "live.com",
    "msn.com",
}
INTERNAL_DOMAINS = {"eve.legal", "butlerlabs.ai"}

FIELDS = "duration,started_at,count_errors,environment,user,project_id"
PAGE_SIZE = 1000

# (label, lo_inclusive, hi_exclusive) in seconds
BUCKETS = [
    ("<10s", 0, 10),
    ("10-30s", 10, 30),
    ("30-60s", 30, 60),
    ("1-2m", 60, 120),
    ("2-5m", 120, 300),
    ("5-10m", 300, 600),
    ("10-20m", 600, 1200),
    ("20-30m", 1200, 1800),
    ("30-60m", 1800, 3600),
    ("60m+", 3600, float("inf")),
]


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Sentry Replay session-length metrics",
        add_help=True,
    )
    p.add_argument("--org", default="butler-0x")
    p.add_argument("--project", default=None)
    p.add_argument("--env", default="production")
    p.add_argument("--period", default="30d")
    p.add_argument("--max", type=int, default=20000)
    p.add_argument("--top", type=int, default=25)
    p.add_argument("--html", default=None)
    p.add_argument("--json", dest="json_out", default=None)
    p.add_argument("--include-errors", action="store_true")
    p.add_argument("--include-internal", action="store_true")
    return p.parse_args(argv)


def fetch_replays(args: argparse.Namespace) -> list[dict]:
    target = f"{args.org}/{args.project}" if args.project else f"{args.org}/"
    query = None if args.include_errors else "count_errors:0"
    rows: list[dict] = []
    cursor: str | None = None
    page = 0

    while len(rows) < args.max:
        cmd = [
            "sentry",
            "replay",
            "list",
            target,
            "-e",
            args.env,
            "--period",
            args.period,
            "--limit",
            str(PAGE_SIZE),
            "--json",
            "--fields",
            FIELDS,
        ]
        if query:
            cmd += ["-q", query]
        if cursor:
            cmd += ["--cursor", cursor]

        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print("sentry CLI failed:", file=sys.stderr)
            print(res.stderr or res.stdout or "(no output)", file=sys.stderr)
            sys.exit(res.returncode or 30)

        try:
            parsed = json.loads(res.stdout)
        except json.JSONDecodeError as e:
            print(f"Could not parse sentry CLI JSON output: {e}", file=sys.stderr)
            sys.exit(30)

        data = parsed.get("data", [])
        rows += data
        page += 1
        print(
            f"\rFetched {len(rows)} sessions (page {page})...", end="", file=sys.stderr
        )

        if not parsed.get("hasMore") or not parsed.get("nextCursor") or not data:
            break
        cursor = parsed["nextCursor"]

    print("", file=sys.stderr)
    return rows[: args.max]


def domain_of(row: dict) -> str | None:
    email = (row.get("user") or {}).get("email")
    if not email or "@" not in email:
        return None
    return email.split("@")[1].lower()


def classify_domain(domain: str | None) -> str:
    if domain in INTERNAL_DOMAINS:
        return "internal"
    if domain in CONSUMER_DOMAINS:
        return "consumer"
    return "firm"


def percentile(ordered: list[float], p: float) -> float:
    """Match the JS tool's indexing exactly: ordered[floor((n-1)*p)]."""
    if not ordered:
        return 0
    return ordered[int((len(ordered) - 1) * p)]


def summarize(durations: list) -> dict | None:
    s = sorted(d for d in durations if isinstance(d, (int, float)))
    n = len(s)
    if not n:
        return None
    total = sum(s)
    return {
        "n": n,
        "mean": total / n,
        "median": percentile(s, 0.5),
        "p25": percentile(s, 0.25),
        "p75": percentile(s, 0.75),
        "p90": percentile(s, 0.9),
        "p95": percentile(s, 0.95),
        "p99": percentile(s, 0.99),
        "max": s[-1],
        "totalSec": total,
        "bounce10": sum(1 for d in s if d < 10) / n,
        "under60": sum(1 for d in s if d < 60) / n,
        "over1800": sum(1 for d in s if d >= 1800) / n,
    }


def histogram(durations: list) -> list[dict]:
    nums = [d for d in durations if isinstance(d, (int, float))]
    return [
        {"label": label, "count": sum(1 for d in nums if lo <= d < hi)}
        for label, lo, hi in BUCKETS
    ]


def group_by(rows: list[dict], key_fn) -> dict:
    groups: dict = defaultdict(list)
    for row in rows:
        key = key_fn(row)
        if key is None:
            continue
        groups[key].append(row)
    return groups


def per_group(rows: list[dict], key_fn, extra=None) -> list[dict]:
    out = []
    for key, group_rows in group_by(rows, key_fn).items():
        stats = summarize([r.get("duration") for r in group_rows])
        if not stats:
            continue
        entry = {"key": key, "stats": stats}
        if extra:
            entry.update(extra(key, group_rows))
        out.append(entry)
    return sorted(out, key=lambda g: g["stats"]["n"], reverse=True)


def daily_trend(rows: list[dict]) -> list[dict]:
    by_day = group_by(rows, lambda r: (r.get("started_at") or "")[:10] or None)
    out = [
        {"day": day, "stats": summarize([r.get("duration") for r in day_rows])}
        for day, day_rows in by_day.items()
    ]
    return sorted(out, key=lambda d: d["day"])


def build_metrics(rows: list[dict], args: argparse.Namespace) -> dict:
    with_domain = [{**r, "_domain": domain_of(r)} for r in rows]
    if args.include_internal:
        filtered = with_domain
    else:
        filtered = [
            r for r in with_domain if classify_domain(r["_domain"]) != "internal"
        ]

    dates = sorted(r["started_at"] for r in filtered if r.get("started_at"))

    return {
        "meta": {
            "org": args.org,
            "project": args.project or "(all)",
            "env": args.env,
            "period": args.period,
            "includeErrors": args.include_errors,
            "includeInternal": args.include_internal,
            "totalSessions": len(filtered),
            "windowStart": dates[0] if dates else None,
            "windowEnd": dates[-1] if dates else None,
            "generatedAt": datetime.now(timezone.utc).isoformat(),
        },
        "overall": summarize([r.get("duration") for r in filtered]),
        "histogram": histogram([r.get("duration") for r in filtered]),
        "perOrg": per_group(
            filtered,
            lambda r: r["_domain"],
            lambda key, _rows: {"kind": classify_domain(key)},
        ),
        "perUser": per_group(filtered, lambda r: (r.get("user") or {}).get("email")),
        "daily": daily_trend(filtered),
    }


# ---- console rendering ----


def mins(sec: float) -> str:
    return f"{sec / 60:.1f}"


def pct(frac: float) -> str:
    return f"{round(frac * 100)}%"


def print_table(headers: list[str], rows: list[list]) -> None:
    cols = list(zip(*([headers] + rows))) if rows else [[h] for h in headers]
    widths = [max(len(str(c)) for c in col) for col in cols]

    def line(cells):
        return "  ".join(str(c).ljust(widths[i]) for i, c in enumerate(cells))

    print(line(headers))
    print("  ".join("-" * w for w in widths))
    for r in rows:
        print(line(r))


def render_console(m: dict, args: argparse.Namespace) -> None:
    meta, overall = m["meta"], m["overall"]
    print("\nSentry Replay session-length metrics")
    print("====================================")
    print(
        f"org={meta['org']} project={meta['project']} env={meta['env']} "
        f"period={meta['period']}"
    )
    print(
        f"sessions={meta['totalSessions']} "
        f"window={(meta['windowStart'] or '')[:16]} → "
        f"{(meta['windowEnd'] or '')[:16]}"
    )
    print(
        f"filters: errors={'included' if meta['includeErrors'] else 'excluded'}, "
        f"internal={'included' if meta['includeInternal'] else 'excluded'}"
    )
    if not overall:
        print("\nNo sessions found for these filters.")
        return

    print("\n-- Overall distribution --")
    print_table(
        ["metric", "value"],
        [
            ["sessions", overall["n"]],
            ["median", f"{mins(overall['median'])} min"],
            ["mean", f"{mins(overall['mean'])} min"],
            ["p75", f"{mins(overall['p75'])} min"],
            ["p90", f"{mins(overall['p90'])} min"],
            ["p95", f"{mins(overall['p95'])} min"],
            ["p99", f"{mins(overall['p99'])} min"],
            ["max", f"{mins(overall['max'])} min"],
            ["bounce (<10s)", pct(overall["bounce10"])],
            ["short (<60s)", pct(overall["under60"])],
            ["capped (>=30m)", pct(overall["over1800"])],
            ["total time", f"{overall['totalSec'] / 3600:.1f} h"],
        ],
    )

    print(f"\n-- Per-org (email domain), top {args.top} by sessions --")
    print_table(
        ["domain", "kind", "sessions", "median", "mean", "total_min"],
        [
            [
                g["key"],
                g["kind"],
                g["stats"]["n"],
                f"{mins(g['stats']['median'])}m",
                f"{mins(g['stats']['mean'])}m",
                round(g["stats"]["totalSec"] / 60),
            ]
            for g in m["perOrg"][: args.top]
        ],
    )

    print(f"\n-- Per-user, top {args.top} by sessions --")
    print_table(
        ["user", "sessions", "median", "mean", "total_min"],
        [
            [
                g["key"],
                g["stats"]["n"],
                f"{mins(g['stats']['median'])}m",
                f"{mins(g['stats']['mean'])}m",
                round(g["stats"]["totalSec"] / 60),
            ]
            for g in m["perUser"][: args.top]
        ],
    )

    print("\n-- Daily trend --")
    print_table(
        ["day", "sessions", "median", "mean"],
        [
            [
                d["day"],
                d["stats"]["n"],
                f"{mins(d['stats']['median'])}m",
                f"{mins(d['stats']['mean'])}m",
            ]
            for d in m["daily"]
        ],
    )

    if not meta["includeErrors"]:
        print(
            "\nNote: error sessions excluded (100% sampled vs ~10% for normal "
            "sessions). Consumer domains (gmail, etc.) are not orgs."
        )


# ---- HTML rendering (self-contained, zero deps) ----


def svg_bars(data, value_fn, label_fn, width=720, fmt=None) -> str:
    pad, bar_h, gap = 140, 22, 6
    vmax = max([1] + [value_fn(d) for d in data])
    height = len(data) * (bar_h + gap) + gap
    parts = []
    for i, d in enumerate(data):
        v = value_fn(d)
        bw = round((width - pad - 60) * v / vmax)
        y = gap + i * (bar_h + gap)
        label = label_fn(d)
        shown = fmt(v) if fmt else v
        parts.append(
            f'<text x="{pad - 8}" y="{y + bar_h // 2 + 4}" text-anchor="end" '
            f'class="lbl">{label}</text>'
            f'<rect x="{pad}" y="{y}" width="{bw}" height="{bar_h}" class="bar"/>'
            f'<text x="{pad + bw + 6}" y="{y + bar_h // 2 + 4}" '
            f'class="val">{shown}</text>'
        )
    return f'<svg viewBox="0 0 {width} {height}" width="100%">{"".join(parts)}</svg>'


def html_table(headers: list[str], rows: list[list]) -> str:
    head = "".join(f'<th data-col="{i}">{h}</th>' for i, h in enumerate(headers))
    body = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return (
        f'<table class="sortable"><thead><tr>{head}</tr></thead>'
        f"<tbody>{body}</tbody></table>"
    )


_STYLE = """
:root{--bg:#0b0d12;--panel:#151922;--ink:#e7ebf2;--mut:#8a93a6;
--acc:#5b8cff;--bar:#3a6df0;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:14px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;padding:24px}
h1{font-size:20px;margin:0 0 4px}
.sub{color:var(--mut);margin-bottom:20px;font-size:13px}
.cards{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:24px}
.card{background:var(--panel);border-radius:10px;padding:12px 16px;min-width:120px}
.card .k{color:var(--mut);font-size:12px}
.card .v{font-size:22px;font-weight:600;margin-top:2px}
section{background:var(--panel);border-radius:12px;padding:16px 18px;
margin-bottom:20px}
h2{font-size:15px;margin:0 0 12px}
svg .bar{fill:var(--bar)}
svg .lbl{fill:var(--mut);font-size:11px}
svg .val{fill:var(--ink);font-size:11px}
table{border-collapse:collapse;width:100%;font-size:13px}
th,td{text-align:left;padding:6px 10px;border-bottom:1px solid #232838}
th{color:var(--mut);font-weight:600;position:sticky;top:0;background:var(--panel)}
td:first-child{max-width:280px;overflow:hidden;text-overflow:ellipsis}
.scroll{max-height:520px;overflow:auto}
.note{color:var(--mut);font-size:12px;margin-top:8px}
"""

_SORT_SCRIPT = (
    'document.querySelectorAll("table.sortable th").forEach(function(th){'
    'th.style.cursor="pointer";th.addEventListener("click",function(){'
    'var tb=th.closest("table"),idx=+th.dataset.col,'
    "rows=Array.from(tb.tBodies[0].rows),"
    'asc=th.dataset.asc!=="1";th.dataset.asc=asc?"1":"0";'
    "rows.sort(function(a,b){var x=a.cells[idx].textContent,"
    "y=b.cells[idx].textContent,nx=parseFloat(x),ny=parseFloat(y);"
    "if(!isNaN(nx)&&!isNaN(ny)){return asc?nx-ny:ny-nx;}"
    "return asc?x.localeCompare(y):y.localeCompare(x);});"
    "rows.forEach(function(r){tb.tBodies[0].appendChild(r);});});});"
)


def render_html(m: dict) -> str:
    meta, overall = m["meta"], m["overall"]

    def card(label, value):
        return (
            f'<div class="card"><div class="k">{label}</div>'
            f'<div class="v">{value}</div></div>'
        )

    if overall:
        cards = "".join(
            [
                card("Sessions", overall["n"]),
                card("Median", f"{mins(overall['median'])}m"),
                card("Mean", f"{mins(overall['mean'])}m"),
                card("p90", f"{mins(overall['p90'])}m"),
                card("p95", f"{mins(overall['p95'])}m"),
                card("Bounce &lt;10s", pct(overall["bounce10"])),
                card("Total time", f"{overall['totalSec'] / 3600:.1f}h"),
            ]
        )
    else:
        cards = "<p>No sessions found.</p>"

    hist = svg_bars(m["histogram"], lambda d: d["count"], lambda d: d["label"])
    trend = svg_bars(
        m["daily"],
        lambda d: d["stats"]["median"],
        lambda d: d["day"],
        width=760,
        fmt=lambda v: f"{mins(v)}m",
    )
    org_table = html_table(
        ["Domain", "Kind", "Sessions", "Median (m)", "Mean (m)", "Total (m)"],
        [
            [
                g["key"],
                g["kind"],
                g["stats"]["n"],
                mins(g["stats"]["median"]),
                mins(g["stats"]["mean"]),
                round(g["stats"]["totalSec"] / 60),
            ]
            for g in m["perOrg"]
        ],
    )
    user_table = html_table(
        ["User", "Sessions", "Median (m)", "Mean (m)", "Total (m)"],
        [
            [
                g["key"],
                g["stats"]["n"],
                mins(g["stats"]["median"]),
                mins(g["stats"]["mean"]),
                round(g["stats"]["totalSec"] / 60),
            ]
            for g in m["perUser"][:200]
        ],
    )

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sentry Replay metrics — {meta["org"]}</title>
<style>{_STYLE}</style></head>
<body>
<h1>Sentry Replay session-length metrics</h1>
<div class="sub">
org <b>{meta["org"]}</b> · project {meta["project"]} · env {meta["env"]} ·
period {meta["period"]} · window {(meta["windowStart"] or "")[:16]} →
{(meta["windowEnd"] or "")[:16]} ·
errors {"included" if meta["includeErrors"] else "excluded"} ·
internal {"included" if meta["includeInternal"] else "excluded"} ·
generated {meta["generatedAt"][:16]}
</div>
<div class="cards">{cards}</div>
<section><h2>Duration distribution</h2>{hist}</section>
<section><h2>Daily median session length</h2>{trend}</section>
<section><h2>Per-org (email domain)</h2><div class="scroll">{org_table}</div>
<div class="note">Domain is an org proxy. "consumer" rows (gmail, etc.) pool
unrelated solo users; "internal" is Eve staff.</div></section>
<section><h2>Per-user (top 200)</h2><div class="scroll">{user_table}</div>
</section>
<script>{_SORT_SCRIPT}</script>
</body></html>"""


def main() -> None:
    args = parse_args(sys.argv[1:])
    rows = fetch_replays(args)
    metrics = build_metrics(rows, args)

    render_console(metrics, args)

    if args.json_out:
        Path(args.json_out).write_text(json.dumps(metrics, indent=2))
        print(f"\nWrote metrics JSON → {args.json_out}")
    if args.html:
        Path(args.html).write_text(render_html(metrics))
        print(f"Wrote HTML dashboard → {args.html}")


if __name__ == "__main__":
    main()
