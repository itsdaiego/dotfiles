#!/usr/bin/env python3
"""On-call intake tracker: polls Slack for pings and serves a local dashboard.

Runs on the macOS system Python (3.9) with the standard library only, so the
launchd agent does not depend on pyenv or a virtualenv.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import plistlib
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("ONCALL_INTAKE_HOME", Path.home() / "ai/eve/oncall-intake"))
STORE_PATH = DATA_DIR / "pings.json"
LOCK_PATH = DATA_DIR / ".pings.lock"
CONFIG_PATH = DATA_DIR / "config.json"
LOG_PATH = DATA_DIR / "daemon.log"
DASHBOARD_PATH = SKILL_DIR / "dashboard.html"

LAUNCHD_LABEL = "com.daiego.oncall-intake"
PLIST_PATH = Path.home() / "Library/LaunchAgents" / f"{LAUNCHD_LABEL}.plist"
KEYCHAIN_SERVICE = "oncall-intake-slack"
KEYCHAIN_ACCOUNT = "slack"

STATUSES = ("pending", "doing", "done")
SEVERITIES = ("urgent", "high", "medium", "low")
P_LEVELS = {"0": "urgent", "1": "high", "2": "medium", "3": "low", "4": "low"}
SEV_LEVELS = {"0": "urgent", "1": "urgent", "2": "high", "3": "medium", "4": "low"}
WORD_LEVELS = {"urgent": "urgent", "asap": "urgent", "emergency": "urgent", "high": "high", "medium": "medium", "low": "low"}
SEVERITY_PATTERNS = (
    (re.compile(r"\bP([0-4])\b"), P_LEVELS),
    (re.compile(r"\bsev[- ]?([0-4])\b", re.I), SEV_LEVELS),
    (re.compile(r"\b(urgent|asap|emergency)\b", re.I), WORD_LEVELS),
    (re.compile(r"\bpriority\W{0,3}(urgent|high|medium|low)\b", re.I), WORD_LEVELS),
    (re.compile(r"\b(high|medium|low)[- ]priority\b", re.I), WORD_LEVELS),
)
LINEAR_ISSUE_RE = re.compile(r"linear\.app/[\w-]+/issue/([A-Z][A-Z0-9]*-\d+)")
SLACK_THREAD_LINK_RE = re.compile(r"slack\.com/archives/(C[A-Z0-9]+)/p(\d{10})(\d{6})(?:\?thread_ts=(\d+\.\d+))?")
LINEAR_SUGGESTED_RE = re.compile(r"suggested priority[^:\n]*:\W*(urgent|high|medium|low)\b", re.I)
LINEAR_PRIORITIES = {1: "urgent", 2: "high", 3: "medium", 4: "low"}
LINEAR_MAX_ISSUES_PER_ITEM = 2
LINEAR_MAX_FETCHES = 5
LINEAR_REFRESH_SECONDS = 6 * 3600

DEFAULT_CONFIG = {
    "user_id": "U0C0Q7F8CFL",
    "usergroup_id": "S08UQQB1W01",
    "usergroup_handle": "oncall-intake",
    "workspace_url": "https://butlerlabs.slack.com",
    "poll_seconds": 300,
    "lookback_days": 7,
    "port": 47821,
    "ignore_own_messages": True,
    "my_mention_channel_ids": ["C08NLEVC6AY"],
    "source_channel_ids": ["C01NBFKGRCP", "C0B0XQPDXPX", "C09AFN8BVDJ"],
    "intake_check_channel_ids": ["C01NBFKGRCP"],
    "intake_scope": (
        "Intake owns: phone calls and telephony integrations (RingCentral, Dialpad, call sync, recordings, "
        "transcripts, call agents), the Retell voice agent, live intake assist, transfer rules, intake call "
        "scoring, auto agents and their triggers and runs, CRM and case management integrations and lead "
        "sync (LeadDocket, Filevine, Litify, Clio and similar), data ingest, email routing, intake forms, "
        "and case comms (texts and emails to clients). Intake does not own: Ask Eve chat and its tools, "
        "case work, drafting, blueprints, demand letters, document upload and OCR, medical records, "
        "analyst, or general infrastructure."
    ),
    "window_days": 7,
    "ignore_user_ids": ["USLACK"],
    "ignore_channel_ids": ["C0C0YFLFUR4"],
    "walle_requests": True,
    "walle_user_id": "U0AF0Q79FA7",
    "walle_channel_id": "C0C0YFLFUR4",
    "claude_bin": "/opt/homebrew/bin/claude",
    "claude_model": "haiku",
}

MCP_TOOL = "mcp__slack__slack_search_public_and_private"
MCP_SEND_TOOL = "mcp__slack__slack_send_message"
MCP_READ_THREAD_TOOL = "mcp__slack__slack_read_thread"
MCP_LINEAR_ISSUE_TOOL = "mcp__linear__get_issue"
WALLE_PROMPT = """<@{walle_user_id}> Help me troubleshoot this on-call ping from #{channel_name} faster: {permalink}
Read the whole thread. Tell me the likely root cause, the evidence for it, and what I should check or do first.
Reply here only. Do not post in the original thread."""
INTAKE_CHECK_PROMPT = """Decide whether each production alert below belongs to the intake team.
{scope}

Reply with only a JSON object. Use each alert key as a property, with the value {{"intake": true or false, "reason": "<at most 12 words>"}}.

{alerts}"""
INTAKE_CHECK_MAX_ALERTS = 10
MCP_MAX_PAGES = 5
MCP_CALL_PROMPT = """Call {tool} exactly once with exactly these arguments, then reply "done":
{arguments}"""


def load_config() -> dict:
    config = dict(DEFAULT_CONFIG)
    if CONFIG_PATH.exists():
        config.update(json.loads(CONFIG_PATH.read_text()))
    return config


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@contextmanager
def locked_store():
    """Yield the store dict under an exclusive file lock and write it back on exit.

    The daemon and the CLI both mutate pings.json, so every read-modify-write
    goes through this lock.
    """
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOCK_PATH, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        store = {"items": {}, "meta": {}}
        if STORE_PATH.exists():
            store = json.loads(STORE_PATH.read_text())
        yield store
        tmp = STORE_PATH.with_suffix(".tmp")
        tmp.write_text(json.dumps(store, indent=2, ensure_ascii=False))
        tmp.replace(STORE_PATH)


def read_store() -> dict:
    with locked_store() as store:
        return json.loads(json.dumps(store))


def read_token() -> str | None:
    token = os.environ.get("ONCALL_INTAKE_SLACK_TOKEN")
    if token:
        return token
    result = subprocess.run(
        ["/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT, "-w"],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() or None


def slack_get(token: str, method: str, params: dict) -> dict:
    url = f"https://slack.com/api/{method}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.loads(response.read())
    if not payload.get("ok"):
        raise RuntimeError(f"Slack {method} failed: {payload.get('error')}")
    return payload


def search_web_api(token: str, queries: list[str]) -> list[dict]:
    matches: dict[str, dict] = {}
    for query in queries:
        for page in range(1, 4):
            payload = slack_get(
                token,
                "search.messages",
                {"query": query, "sort": "timestamp", "sort_dir": "desc", "count": 100, "page": page},
            )
            block = payload.get("messages", {})
            for match in block.get("matches", []):
                matches[f"{match.get('channel', {}).get('id')}:{match.get('ts')}"] = match
            if page >= block.get("paging", {}).get("pages", 1):
                break
    return list(matches.values())


def web_api_after(config: dict) -> str:
    return (datetime.now() - timedelta(days=config["lookback_days"] + 1)).strftime("%Y-%m-%d")


def search_my_replies(token: str, config: dict) -> list[dict]:
    return search_web_api(token, [f"from:<@{config['user_id']}> is:thread after:{web_api_after(config)}"])


def search_mentions(token: str, config: dict) -> list[dict]:
    after = web_api_after(config)
    queries = [
        f"<!subteam^{config['usergroup_id']}> after:{after}",
        f"@{config['usergroup_handle']} after:{after}",
    ]
    queries += [f"<@{config['user_id']}> in:<#{c}> after:{after}" for c in config["my_mention_channel_ids"]]
    queries += [f"in:<#{c}> after:{after}" for c in config["source_channel_ids"]]
    return search_web_api(token, queries)


def run_mcp_search(config: dict, arguments: dict) -> str:
    return run_mcp_tool(config, MCP_TOOL, arguments)


def run_mcp_tool(config: dict, tool: str, arguments: dict) -> str:
    """Run one Slack MCP tool call through a headless `claude -p` and return the raw tool result.

    The model only makes the tool call. The result is read from the stream-json
    events, so the model cannot drop or rewrite messages. Raises RuntimeError
    when the run fails or makes no tool call. ANTHROPIC_API_KEY is removed from
    the child environment so the run uses the Claude login.
    """
    prompt = MCP_CALL_PROMPT.format(tool=tool, arguments=json.dumps(arguments))
    env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}
    result = subprocess.run(
        [
            config["claude_bin"], "-p", prompt,
            "--model", config["claude_model"],
            "--output-format", "stream-json", "--verbose",
            "--allowedTools", tool,
            "--max-turns", "3",
        ],
        capture_output=True, text=True, timeout=180, env=env, cwd=str(DATA_DIR),
    )
    call_ids = set()
    for line in result.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "result" and event.get("is_error"):
            raise RuntimeError(f"claude -p failed: {event.get('result')}")
        for block in event.get("message", {}).get("content", []) if event.get("type") in ("assistant", "user") else []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") == tool:
                call_ids.add(block.get("id"))
            if block.get("type") != "tool_result" or block.get("tool_use_id") not in call_ids:
                continue
            content = block.get("content")
            if isinstance(content, list):
                content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
            if block.get("is_error"):
                raise RuntimeError(f"Slack MCP error: {str(content)[:300]}")
            return content or ""
    raise RuntimeError(f"claude -p made no {tool} call: {(result.stderr or result.stdout).strip()[-300:]}")


def parse_mcp_results(raw: str) -> tuple[list[dict], str | None]:
    payload = json.loads(raw)
    matches = []
    for block in payload.get("results", "").split("\n### Result ")[1:]:
        ts = re.search(r"^Message_ts: (\S+)", block, re.M)
        if not ts:
            continue
        channel = re.search(r"^Channel: (.+?) \(ID: (\w+)\)", block, re.M)
        author = re.search(r"^From: (.*?) \(ID: (\w+)\)", block, re.M)
        permalink = re.search(r"^Permalink: \[link\]\((.+?)\)", block, re.M)
        text = block.split("\nText: \n", 1)[1] if "\nText: \n" in block else ""
        matches.append(
            {
                "ts": ts.group(1),
                "text": re.sub(r"\n+---\s*$", "", text).strip(),
                "user": author.group(2) if author else None,
                "username": re.sub(r"\s*<[^>]*>", "", author.group(1)).strip() if author else None,
                "channel": {
                    "id": channel.group(2) if channel else None,
                    "name": channel.group(1).lstrip("#") if channel else None,
                },
                "permalink": permalink.group(1) if permalink else None,
            }
        )
    cursor = re.search(r"cursor `([^`]+)`", payload.get("pagination_info", "") or "")
    return matches, cursor.group(1) if cursor else None


def mcp_search_all(config: dict, after_ts: float, **search: object) -> list[dict]:
    matches: dict[str, dict] = {}
    cursor = None
    for _ in range(MCP_MAX_PAGES):
        arguments = {
            **search,
            "after": str(int(after_ts)),
            "sort": "timestamp",
            "limit": 20,
            "include_bots": True,
            "include_context": False,
            "response_format": "detailed",
            "natural_language_query": "",
        }
        if cursor:
            arguments["cursor"] = cursor
        page, cursor = parse_mcp_results(run_mcp_search(config, arguments))
        for match in page:
            matches[f"{match['channel']['id']}:{match['ts']}"] = match
        if not cursor or not page:
            break
    return list(matches.values())


def search_mentions_via_mcp(config: dict, after_ts: float) -> list[dict]:
    keywords = [f"<!subteam^{config['usergroup_id']}>", f"<@{config['usergroup_id']}>"]
    matches: list[dict] = []
    for keyword in keywords:
        matches.extend(mcp_search_all(config, after_ts, keywords=[keyword]))
    for channel_id in config["my_mention_channel_ids"]:
        matches.extend(mcp_search_all(config, after_ts, keywords=[f"<@{config['user_id']}>"], filters=f"in:<#{channel_id}>"))
    for channel_id in config["source_channel_ids"]:
        matches.extend(mcp_search_all(config, after_ts, filters=f"in:<#{channel_id}>"))
    return matches


def search_my_replies_via_mcp(config: dict, after_ts: float) -> list[dict]:
    return mcp_search_all(config, after_ts, filters=f"from:<@{config['user_id']}> is:thread")


def mention_kind(text: str, channel_id: str | None, config: dict) -> str | None:
    """Classify a message as an on-call ping, a counted mention of Daiego, or neither.

    Direct messages never count. A mention of Daiego counts only in
    my_mention_channel_ids, because Daiego's name comes up too often elsewhere.
    """
    if not channel_id or channel_id.startswith("D"):
        return None
    if f"<!subteam^{config['usergroup_id']}" in text or f"<@{config['usergroup_id']}" in text:
        return "oncall"
    if channel_id in config["my_mention_channel_ids"] and f"<@{config['user_id']}" in text:
        return "me"
    if channel_id in config["source_channel_ids"]:
        return "source"
    return None


def thread_root(match: dict) -> str:
    query = urllib.parse.urlparse(match.get("permalink") or "").query
    return urllib.parse.parse_qs(query).get("thread_ts", [match["ts"]])[0]


def resolve_names(matches: list[dict], token: str, cache: dict) -> dict:
    names = dict(cache)
    for user_id in {m.get("user") for m in matches if m.get("user")} - names.keys():
        try:
            profile = slack_get(token, "users.info", {"user": user_id})["user"]
            names[user_id] = profile.get("real_name") or profile.get("name") or user_id
        except (RuntimeError, OSError):
            pass
    return names


def merge_matches(store: dict, matches: list[dict], config: dict) -> int:
    """Add new pings to the store. Returns the count of items that are new or reopened.

    Pings are grouped by thread, so a follow-up mention in a thread updates the
    existing item. A new mention in a thread already marked done moves it back
    to pending, because the person is asking again.
    """
    names = store["meta"].get("names", {})
    changed = 0
    for match in sorted(matches, key=lambda m: float(m["ts"])):
        text = match.get("text", "")
        record_shift_change(store["meta"], match, config)
        kind = mention_kind(text, match.get("channel", {}).get("id"), config)
        if kind is None:
            continue
        if config["ignore_own_messages"] and match.get("user") == config["user_id"]:
            continue
        if match.get("user") in config["ignore_user_ids"]:
            continue
        if match.get("channel", {}).get("id") in config["ignore_channel_ids"]:
            continue
        channel = match.get("channel", {})
        root = thread_root(match)
        item_id = f"{channel.get('id')}-{root}"
        ping = {
            "ts": match["ts"],
            "author": names.get(match.get("user")) or match.get("username") or "unknown",
            "text": text,
            "permalink": match.get("permalink"),
            "kind": kind,
        }
        item = store["items"].get(item_id)
        if item is None:
            store["items"][item_id] = {
                "id": item_id,
                "channel_id": channel.get("id"),
                "channel_name": channel.get("name") or ("DM" if channel.get("is_im") else channel.get("id")),
                "thread_ts": root,
                "status": "pending",
                "status_changed_at": now_iso(),
                "first_seen_at": now_iso(),
                "pings": [ping],
            }
            changed += 1
            continue
        if any(p["ts"] == ping["ts"] for p in item["pings"]):
            continue
        is_newest = float(ping["ts"]) > float(item["pings"][-1]["ts"])
        item["pings"].append(ping)
        item["pings"].sort(key=lambda p: float(p["ts"]))
        if item["status"] == "done" and is_newest:
            item["status"] = "pending"
            item["status_changed_at"] = now_iso()
            item["reopened"] = True
        changed += 1
    return changed


def mcp_search_after(meta: dict, config: dict) -> float:
    """Start the search one hour before the last successful poll.

    Slack search indexes new messages late, and the overlap lets a late message
    show up in the next poll. Merging drops the duplicates.
    """
    last = meta.get("last_success_at")
    if last:
        return datetime.fromisoformat(last).timestamp() - 3600
    return (datetime.now(timezone.utc) - timedelta(days=config["lookback_days"])).timestamp()


def window_start(config: dict) -> float:
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    return (today - timedelta(days=config["window_days"] - 1)).timestamp()


def record_shift_change(meta: dict, match: dict, config: dict) -> None:
    """Record Daiego's on-call shift from Slackbot's user group membership DMs.

    Slackbot sends "You have been added to ... user group" when the rotation
    adds Daiego, and a "removed from" message when it removes Daiego.
    """
    text = match.get("text", "")
    if match.get("user") != "USLACK" or f"<!subteam^{config['usergroup_id']}" not in text:
        return
    key = "shift_started_ts" if "have been added to" in text else "shift_ended_ts" if "removed from" in text else None
    if key and float(match["ts"]) > float(meta.get(key) or 0):
        meta[key] = match["ts"]


def in_shift(ts: str, meta: dict) -> bool:
    """Return True when an on-call ping falls inside Daiego's current or last shift.

    With no recorded shift start, every ping counts.
    """
    started = float(meta.get("shift_started_ts") or 0)
    ended = float(meta.get("shift_ended_ts") or 0)
    if float(ts) < started:
        return False
    return not (ended > started and float(ts) > ended)


def counts(ping: dict, channel_id: str, meta: dict, config: dict) -> bool:
    """Return True when a ping puts its item on the dashboard.

    A source message in intake_check_channel_ids counts only after the intake
    check marks it as intake work. An unchecked message stays hidden.
    """
    kind = mention_kind(ping["text"], channel_id, config)
    if kind == "source" and channel_id in config["intake_check_channel_ids"] and ping.get("intake") is not True:
        return False
    return kind == "me" or (kind in ("oncall", "source") and in_shift(ping["ts"], meta))


def run_claude_prompt(config: dict, prompt: str) -> str:
    env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}
    result = subprocess.run(
        [config["claude_bin"], "-p", prompt, "--model", config["claude_model"], "--output-format", "json", "--max-turns", "1"],
        capture_output=True, text=True, timeout=180, env=env, cwd=str(DATA_DIR),
    )
    payload = json.loads(result.stdout or "{}")
    if payload.get("is_error") or "result" not in payload:
        raise RuntimeError(f"claude -p failed: {(payload.get('result') or result.stderr or result.stdout).strip()[-300:]}")
    return payload["result"]


def read_alert_text(config: dict, channel_id: str, ts: str) -> str:
    raw = run_mcp_tool(config, MCP_READ_THREAD_TOOL, {"channel_id": channel_id, "message_ts": ts, "limit": 1, "response_format": "concise"})
    text = json.loads(raw).get("messages", "")
    return re.sub(r"\n+No thread mess+ages\s*$", "", re.sub(r"^THREAD: ", "", text)).strip()


def check_intake_alerts(config: dict, limit: int = INTAKE_CHECK_MAX_ALERTS) -> list[str]:
    """Mark each unchecked source message in intake_check_channel_ids as intake work or not.

    Only messages inside the window and Daiego's shift get checked. Bot alerts
    such as Sentry have no Slack text, so the message is read first and its text
    is stored on the ping. One headless `claude -p` run classifies the batch.
    Returns error strings. A failed check leaves the messages unchecked for the next poll.
    """
    start = window_start(config)
    with locked_store() as store:
        meta = store["meta"]
        wanted = [
            (item["id"], dict(ping))
            for item in store["items"].values() if item["channel_id"] in config["intake_check_channel_ids"]
            for ping in item["pings"]
            if ping.get("kind") == "source" and "intake" not in ping
            and float(ping["ts"]) >= start and in_shift(ping["ts"], meta)
        ]
    wanted = sorted(wanted, key=lambda w: -float(w[1]["ts"]))[:limit]
    if not wanted:
        return []
    errors = []
    for item_id, ping in wanted:
        if not ping["text"].strip():
            try:
                ping["text"] = read_alert_text(config, item_id.split("-", 1)[0], ping["ts"])
            except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
                errors.append(f"read alert {ping['ts']}: {exc}")
    alerts = "\n\n".join(f"### a{n}\nFrom: {p['author']}\n{p['text'][:1500]}" for n, (_, p) in enumerate(wanted))
    try:
        answer = run_claude_prompt(config, INTAKE_CHECK_PROMPT.format(scope=config["intake_scope"], alerts=alerts))
        verdicts = json.loads(answer[answer.index("{"):answer.rindex("}") + 1])
    except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError, ValueError) as exc:
        return errors + [f"intake check: {exc}"]
    with locked_store() as store:
        for n, (item_id, ping) in enumerate(wanted):
            verdict = verdicts.get(f"a{n}")
            if not isinstance(verdict, dict) or not ping["text"].strip():
                continue
            stored = next(p for p in store["items"][item_id]["pings"] if p["ts"] == ping["ts"])
            stored["text"] = ping["text"]
            stored["intake"] = verdict.get("intake") is True
            stored["intake_reason"] = str(verdict.get("reason") or "")[:200]
    return errors


def visible_items(store: dict, config: dict) -> list[dict]:
    """Return the items the dashboard and CLI show.

    Hides items whose latest ping is before the window (today plus the previous
    `window_days - 1` days). Also hides items with no counted ping: a counted ping
    is an on-call ping inside Daiego's shift, or a mention of Daiego in
    my_mention_channel_ids. Direct messages never count. An item in
    intake_check_channel_ids that Daiego moved out of pending stays visible
    without the intake check. Hidden items stay in pings.json.
    """
    start = window_start(config)
    meta = store["meta"]
    return [
        i for i in store["items"].values()
        if i.get("handoff")
        or (
            float(i["pings"][-1]["ts"]) >= start
            and (
                any(counts(p, i["channel_id"], meta, config) for p in i["pings"])
                or (i["status"] != "pending" and i["channel_id"] in config["intake_check_channel_ids"])
            )
        )
    ]


def apply_my_replies(store: dict, replies: list[dict], config: dict) -> int:
    """Move a pending item to doing when Daiego replied in its thread after the latest ping.

    A ping that arrives after the reply leaves the item pending, so a follow-up
    question is not lost. Done items are never changed. Returns the count of moved items.
    """
    moved = 0
    for reply in replies:
        root = thread_root(reply)
        item = store["items"].get(f"{reply.get('channel', {}).get('id')}-{root}")
        if item is None or root == reply["ts"]:
            continue
        if float(reply["ts"]) > float(item.get("my_last_reply_ts") or 0):
            item["my_last_reply_ts"] = reply["ts"]
        since = max(float(item["pings"][-1]["ts"]), float((item.get("handoff") or {}).get("imported_at_ts") or 0))
        if item["status"] == "pending" and float(item["my_last_reply_ts"]) > since:
            item["status"] = "doing"
            item["status_changed_at"] = now_iso()
            item.pop("reopened", None)
            moved += 1
    return moved


def poll_once(since_days: float | None = None) -> dict:
    config = load_config()
    token = read_token()
    error = None
    matches: list[dict] = []
    replies: list[dict] = []
    meta = read_store()["meta"]
    names: dict = meta.get("names", {})
    try:
        if token:
            matches = search_mentions(token, config)
            replies = search_my_replies(token, config)
            names = resolve_names(matches, token, meta.get("names", {}))
        else:
            after = time.time() - since_days * 86400 if since_days else mcp_search_after(meta, config)
            matches = search_mentions_via_mcp(config, after)
            replies = search_my_replies_via_mcp(config, after)
    except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError, KeyError) as exc:
        error = str(exc)
    with locked_store() as store:
        meta = store["meta"]
        meta["last_poll_at"] = now_iso()
        meta["last_error"] = error
        if error:
            return {"ok": False, "error": error}
        meta["names"] = names
        meta["last_success_at"] = meta["last_poll_at"]
        changed = merge_matches(store, matches, config)
        moved = apply_my_replies(store, replies, config)
    intake_errors = check_intake_alerts(config)
    walle = request_walle_help(config)
    walle_errors = walle["errors"] + link_walle_sessions(config)
    other_errors = intake_errors + fetch_linear_priorities(config)
    if walle_errors or other_errors:
        parts = (["WALL-E: " + "; ".join(walle_errors)] if walle_errors else []) + other_errors
        with locked_store() as store:
            store["meta"]["last_error"] = "; ".join(parts)[:500]
    return {
        "ok": True, "matches": len(matches), "changed": changed, "replies": len(replies),
        "moved_to_doing": moved, "walle_sent": walle["sent"],
    }


def request_walle_help(config: dict) -> dict:
    """Ask WALL-E in #walle-dyego for help on each visible doing item, once per incident.

    An item that shares an incident key with an item that already has a request
    gets no new message. It records walle_shared_with and reuses that request. The message is a new top-level message in walle_channel_id. It never goes to
    the original thread. Items are claimed under the lock before the send, so two
    polls at the same time do not post twice. A failed send keeps the claim and
    records walle_request_error, because the message may have gone out before the
    failure. Retrying could post twice, so a retry is manual.
    """
    if not config["walle_requests"]:
        return {"sent": 0, "errors": []}
    with locked_store() as store:
        requested = {
            key: item["id"]
            for item in store["items"].values() if item.get("walle_requested_at") and not item.get("walle_shared_with")
            for key in incident_keys(item)
        }
        claimed = []
        for item in visible_items(store, config):
            if item["status"] != "doing" or item.get("walle_requested_at"):
                continue
            stored = store["items"][item["id"]]
            stored["walle_requested_at"] = now_iso()
            keys = incident_keys(item)
            source_id = next((requested[k] for k in keys if k in requested), None)
            if source_id:
                stored["walle_shared_with"] = source_id
                copy_walle_fields(store["items"][source_id], stored)
                continue
            requested.update(dict.fromkeys(keys, item["id"]))
            claimed.append(dict(item))
    sent, errors = 0, []
    for item in claimed:
        message = WALLE_PROMPT.format(
            walle_user_id=config["walle_user_id"],
            channel_name=item["channel_name"],
            permalink=item["pings"][0]["permalink"],
        )
        try:
            run_mcp_tool(config, MCP_SEND_TOOL, {"channel_id": config["walle_channel_id"], "message": message})
            sent += 1
        except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
            errors.append(f"{item['id']}: {exc}")
            with locked_store() as store:
                store["items"][item["id"]]["walle_request_error"] = str(exc)[:300]
    return {"sent": sent, "errors": errors}


def incident_keys(item: dict) -> set[str]:
    """Return the keys that tie an item to one incident, so the incident gets one WALL-E request.

    Keys are the item's own thread, each Slack thread that its pings link to, and the
    first Linear issue in its first ping. Later Linear links are skipped, because a
    triage often lists related tickets that other incidents share.
    """
    keys = {f"thread:{item['id']}"}
    for ping in item["pings"]:
        for channel_id, secs, micros, thread_ts in SLACK_THREAD_LINK_RE.findall(ping["text"]):
            keys.add(f"thread:{channel_id}-{thread_ts or f'{secs}.{micros}'}")
    issue = LINEAR_ISSUE_RE.search(item["pings"][0]["text"])
    if issue:
        keys.add(f"linear:{issue.group(1)}")
    return keys


def copy_walle_fields(source: dict, target: dict) -> None:
    for key in ("walle_request_ts", "walle_request_link", "walle_session_url"):
        if source.get(key):
            target[key] = source[key]


def find_walle_requests(config: dict, items: list[dict]) -> dict:
    """Map item IDs to Daiego's WALL-E request messages in walle_channel_id.

    A request matches an item when its text holds the link to the item's first ping.
    """
    since = min(datetime.fromisoformat(i["walle_requested_at"]).timestamp() for i in items) - 120
    requests = mcp_search_all(
        config, since, filters=f"in:<#{config['walle_channel_id']}> from:<@{config['user_id']}>"
    )
    found = {}
    for item in items:
        target = item["pings"][0]["permalink"].split("?")[0]
        for request in requests:
            if target in request["text"]:
                found[item["id"]] = request
    return found


def link_walle_sessions(config: dict) -> list[str]:
    """Store the WALL-E session URL on each item that has a WALL-E request.

    WALL-E replies in the request thread with a `<url|session>` link. Items keep
    retrying on later polls until WALL-E posts it. Returns error strings.
    """
    with locked_store() as store:
        for item in store["items"].values():
            if item.get("walle_shared_with") and not item.get("walle_session_url"):
                copy_walle_fields(store["items"].get(item["walle_shared_with"], {}), item)
        waiting = [
            dict(i) for i in store["items"].values()
            if i.get("walle_requested_at") and not i.get("walle_session_url") and not i.get("walle_shared_with")
        ]
    if not waiting:
        return []
    errors = []
    unmatched = [i for i in waiting if not i.get("walle_request_ts")]
    try:
        requests = find_walle_requests(config, unmatched) if unmatched else {}
    except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        return [f"WALL-E request lookup: {exc}"]
    for item in waiting:
        request = requests.get(item["id"])
        if request:
            item["walle_request_ts"] = request["ts"]
            item["walle_request_link"] = request["permalink"]
        if not item.get("walle_request_ts"):
            continue
        try:
            raw = run_mcp_tool(
                config, MCP_READ_THREAD_TOOL,
                {"channel_id": config["walle_channel_id"], "message_ts": item["walle_request_ts"], "response_format": "concise"},
            )
            session = re.search(r"<(https://[^|>\s]+/session/[^|>\s]+)\|session>", json.loads(raw).get("messages", ""))
        except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
            errors.append(f"WALL-E session {item['id']}: {exc}")
            session = None
        with locked_store() as store:
            stored = store["items"][item["id"]]
            for key in ("walle_request_ts", "walle_request_link"):
                if item.get(key):
                    stored[key] = item[key]
            if session:
                stored["walle_session_url"] = session.group(1)
    return errors


def text_severity(text: str) -> tuple[str, str] | None:
    """Return the severity level and the matched phrase of the earliest urgency marker in a ping.

    The earliest marker wins, so "P1 (filed Urgent)" from a WALL-E triage reads as high.
    """
    hits = [(m.start(), levels[m.group(1).lower()], m.group(0)) for pattern, levels in SEVERITY_PATTERNS for m in pattern.finditer(text)]
    if not hits:
        return None
    _, level, phrase = min(hits)
    return level, phrase


def linear_issue_ids(item: dict) -> list[str]:
    """Return the Linear issues linked in the item's first ping.

    Later pings are skipped because replies often list many older, related tickets.
    """
    ids = LINEAR_ISSUE_RE.findall(item["pings"][0]["text"])
    return list(dict.fromkeys(ids))[:LINEAR_MAX_ISSUES_PER_ITEM]


def item_severity(item: dict, linear_issues: dict) -> dict | None:
    """Pick the item's severity: a set Linear priority, then the newest ping text, then a Linear suggested priority."""
    linked = [(issue_id, linear_issues.get(issue_id) or {}) for issue_id in linear_issue_ids(item)]
    severity = linear_severity(linked, "priority", "Linear")
    if severity:
        return severity
    for ping in reversed(item["pings"]):
        hit = text_severity(ping["text"])
        if hit:
            return {"level": hit[0], "source": f"{ping['author']}: “{hit[1]}”"}
    return linear_severity(linked, "suggested", "Linear suggested")


def linear_severity(linked: list[tuple[str, dict]], key: str, label: str) -> dict | None:
    found = sorted((SEVERITIES.index(issue[key]), issue_id) for issue_id, issue in linked if issue.get(key))
    if not found:
        return None
    issue_id = found[0][1]
    issue = dict(linked)[issue_id]
    return {"level": issue[key], "source": f"{label} {issue_id}", "url": issue.get("url")}


def fetch_linear_priorities(config: dict) -> list[str]:
    """Cache the priority of Linear issues linked from open visible items in meta.linear_issues.

    Fetches at most LINEAR_MAX_FETCHES issues per poll, because each fetch is one
    headless `claude -p` run. A cached issue refreshes after LINEAR_REFRESH_SECONDS,
    also after a failed fetch, so a broken ticket does not block the others. Returns error strings.
    """
    now = time.time()
    with locked_store() as store:
        cache = store["meta"].get("linear_issues", {})
        wanted = dict.fromkeys(
            issue_id
            for item in visible_items(store, config) if item["status"] != "done"
            for issue_id in linear_issue_ids(item)
            if now - (cache.get(issue_id) or {}).get("fetched_at", 0) > LINEAR_REFRESH_SECONDS
        )
    errors, fetched = [], {}
    for issue_id in list(wanted)[:LINEAR_MAX_FETCHES]:
        entry: dict = {"fetched_at": now}
        try:
            issue = json.loads(run_mcp_tool(config, MCP_LINEAR_ISSUE_TOOL, {"id": issue_id}))
            suggested = LINEAR_SUGGESTED_RE.search(issue.get("description") or "")
            entry["priority"] = LINEAR_PRIORITIES.get((issue.get("priority") or {}).get("value") or 0)
            entry["suggested"] = suggested.group(1).lower() if suggested else None
            entry["url"] = issue.get("url")
        except (RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError, AttributeError) as exc:
            entry["error"] = str(exc)[:300]
            errors.append(f"Linear {issue_id}: {exc}")
        fetched[issue_id] = entry
    if fetched:
        with locked_store() as store:
            store["meta"].setdefault("linear_issues", {}).update(fetched)
    return errors


def import_handoff(path: Path, config: dict) -> dict:
    """Add the unfinished items of an on-call handoff doc to the tracker.

    The JSON file has `doc_url`, `doc_title`, `from`, and `items`. Each item has
    `channel_id`, `channel_name`, `message_ts`, optional `thread_ts`, `title`,
    `note`, and optional `priority`. An existing item keeps its status and pings
    and gets the handoff details. A new item starts as pending. Handoff items
    skip the shift and window filters. A reply from Daiego moves one to doing
    only when the reply comes after the import.
    """
    doc = json.loads(path.read_text())
    added, updated = 0, 0
    with locked_store() as store:
        for entry in doc["items"]:
            channel_id, message_ts = entry["channel_id"], entry["message_ts"]
            root = entry.get("thread_ts") or message_ts
            item_id = f"{channel_id}-{root}"
            permalink = f"{config['workspace_url']}/archives/{channel_id}/p{message_ts.replace('.', '')}"
            if root != message_ts:
                permalink += f"?thread_ts={root}&cid={channel_id}"
            handoff = {
                "title": entry["title"],
                "note": entry["note"],
                "priority": entry.get("priority"),
                "doc_url": doc["doc_url"],
                "doc_title": doc["doc_title"],
                "imported_at_ts": str(time.time()),
            }
            item = store["items"].get(item_id)
            if item:
                item["handoff"] = handoff
                updated += 1
                continue
            store["items"][item_id] = {
                "id": item_id,
                "channel_id": channel_id,
                "channel_name": entry["channel_name"],
                "thread_ts": root,
                "status": "pending",
                "status_changed_at": now_iso(),
                "first_seen_at": now_iso(),
                "handoff": handoff,
                "pings": [
                    {"ts": root, "author": doc.get("from", "Handoff"), "text": entry["title"], "permalink": permalink, "kind": "handoff"}
                ],
            }
            added += 1
    return {"added": added, "updated": updated}


def set_status(item_id: str, status: str) -> dict:
    if status not in STATUSES:
        raise ValueError(f"status must be one of {', '.join(STATUSES)}")
    with locked_store() as store:
        item = store["items"].get(item_id)
        if item is None:
            raise KeyError(item_id)
        item["status"] = status
        item["status_changed_at"] = now_iso()
        item.pop("reopened", None)
        return item


def log(message: str) -> None:
    print(f"{now_iso()} {message}", flush=True)


def poll_loop(stop: threading.Event) -> None:
    while not stop.is_set():
        result = poll_once()
        log(f"poll {json.dumps(result)}")
        stop.wait(load_config()["poll_seconds"])


class DashboardHandler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args) -> None:
        pass

    def send_json(self, payload: dict, code: int = 200) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in ("/", "/index.html"):
            body = DASHBOARD_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/items":
            store = read_store()
            config = load_config()
            self.send_json(
                {
                    "items": severity_items(store, config),
                    "meta": {k: v for k, v in store["meta"].items() if k not in ("names", "linear_issues")},
                    "config": {
                        "poll_seconds": config["poll_seconds"],
                        "usergroup_handle": config["usergroup_handle"],
                        "window_days": config["window_days"],
                    },
                }
            )
        else:
            self.send_json({"error": "not found"}, 404)

    def do_POST(self) -> None:
        if self.headers.get("Origin") not in (None, f"http://127.0.0.1:{load_config()['port']}", f"http://localhost:{load_config()['port']}"):
            self.send_json({"error": "forbidden origin"}, 403)
            return
        if self.path == "/api/poll":
            self.send_json(poll_once())
            return
        status_route = re.fullmatch(r"/api/items/([^/]+)/status", self.path)
        if status_route:
            length = int(self.headers.get("Content-Length", 0))
            payload = json.loads(self.rfile.read(length) or b"{}")
            try:
                self.send_json(set_status(urllib.parse.unquote(status_route.group(1)), payload.get("status", "")))
            except KeyError:
                self.send_json({"error": "unknown item"}, 404)
            except ValueError as error:
                self.send_json({"error": str(error)}, 400)
            return
        self.send_json({"error": "not found"}, 404)


def run_daemon() -> None:
    config = load_config()
    stop = threading.Event()
    threading.Thread(target=poll_loop, args=(stop,), daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", config["port"]), DashboardHandler)
    log(f"dashboard on http://127.0.0.1:{config['port']}")
    try:
        server.serve_forever()
    finally:
        stop.set()


def install() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps(DEFAULT_CONFIG, indent=2) + "\n")
    plist = {
        "Label": LAUNCHD_LABEL,
        "ProgramArguments": ["/usr/bin/python3", str(Path(__file__).resolve()), "daemon"],
        "RunAtLoad": True,
        "KeepAlive": True,
        "StandardOutPath": str(LOG_PATH),
        "StandardErrorPath": str(LOG_PATH),
    }
    PLIST_PATH.write_bytes(plistlib.dumps(plist))
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", domain, str(PLIST_PATH)], capture_output=True)
    subprocess.run(["launchctl", "bootstrap", domain, str(PLIST_PATH)], check=True)
    print(f"Installed {LAUNCHD_LABEL}. Dashboard: http://127.0.0.1:{load_config()['port']}")


def uninstall() -> None:
    subprocess.run(["launchctl", "bootout", f"gui/{os.getuid()}", str(PLIST_PATH)], capture_output=True)
    PLIST_PATH.unlink(missing_ok=True)
    print(f"Removed {LAUNCHD_LABEL}. Data kept in {DATA_DIR}")


def severity_items(store: dict, config: dict) -> list[dict]:
    linear_issues = store["meta"].get("linear_issues", {})
    return [{**i, "severity": item_severity(i, linear_issues)} for i in visible_items(store, config)]


def print_items(status: str | None, severity: str | None, oldest_first: bool) -> None:
    items = [
        i for i in severity_items(read_store(), load_config())
        if (status is None or i["status"] == status)
        and (severity is None or (i["severity"] or {}).get("level", "none") == severity)
    ]
    items.sort(key=lambda i: float(i["pings"][-1]["ts"]), reverse=not oldest_first)
    for item in items:
        last = item["pings"][-1]
        when = datetime.fromtimestamp(float(last["ts"])).strftime("%Y-%m-%d %H:%M")
        text = re.sub(r"\s+", " ", last["text"])[:120]
        level = f" {item['severity']['level'].upper()} ({item['severity']['source']})" if item["severity"] else ""
        print(f"[{item['status']}]{level} {item['id']}  {when}  #{item['channel_name']}  {last['author']}: {text}")
        print(f"    {last['permalink']}")


def print_status() -> None:
    store = read_store()
    loaded = subprocess.run(["launchctl", "print", f"gui/{os.getuid()}/{LAUNCHD_LABEL}"], capture_output=True).returncode == 0
    items = visible_items(store, load_config())
    counts = {s: sum(1 for i in items if i["status"] == s) for s in STATUSES}
    print(f"daemon loaded: {loaded}")
    print(f"dashboard: http://127.0.0.1:{load_config()['port']}")
    print(f"slack source: {'Slack token' if read_token() else 'Slack MCP via claude -p'}")
    print(f"last poll: {store['meta'].get('last_poll_at')}  last success: {store['meta'].get('last_success_at')}")
    print(f"last error: {store['meta'].get('last_error')}")
    print("counts: " + ", ".join(f"{s}={n}" for s, n in counts.items()))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("daemon", help="run the poller and the dashboard server (launchd runs this)")
    poll_cmd = sub.add_parser("poll", help="poll Slack once")
    poll_cmd.add_argument("--since-days", type=float, help="search this many days back instead of since the last poll")
    sub.add_parser("install", help="install and start the launchd agent")
    sub.add_parser("uninstall", help="stop and remove the launchd agent, keep data")
    sub.add_parser("status", help="show daemon, token, and poll state")
    list_cmd = sub.add_parser("list", help="list tracked pings")
    list_cmd.add_argument("--status", choices=STATUSES)
    list_cmd.add_argument("--severity", choices=SEVERITIES + ("none",))
    list_cmd.add_argument("--oldest", action="store_true", help="oldest first")
    handoff_cmd = sub.add_parser("import-handoff", help="add unfinished items from an on-call handoff JSON file")
    handoff_cmd.add_argument("path", type=Path)
    move = sub.add_parser("move", help="move an item to another tab")
    move.add_argument("item_id")
    move.add_argument("status", choices=STATUSES)
    check_cmd = sub.add_parser("check-intake", help="mark unchecked alerts in intake_check_channel_ids as intake work or not")
    check_cmd.add_argument("--limit", type=int, default=INTAKE_CHECK_MAX_ALERTS)
    args = parser.parse_args()

    if args.command == "daemon":
        run_daemon()
    elif args.command == "poll":
        print(json.dumps(poll_once(args.since_days)))
    elif args.command == "install":
        install()
    elif args.command == "uninstall":
        uninstall()
    elif args.command == "status":
        print_status()
    elif args.command == "list":
        print_items(args.status, args.severity, args.oldest)
    elif args.command == "import-handoff":
        print(json.dumps(import_handoff(args.path, load_config())))
    elif args.command == "move":
        try:
            item = set_status(args.item_id, args.status)
        except KeyError:
            sys.exit(f"Unknown item {args.item_id}")
        print(f"{item['id']} -> {item['status']}")
    elif args.command == "check-intake":
        print(json.dumps({"errors": check_intake_alerts(load_config(), args.limit)}))


if __name__ == "__main__":
    main()
