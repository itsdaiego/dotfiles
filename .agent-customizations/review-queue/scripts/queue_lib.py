"""Shared paths and data loading for the review queue page and server."""

import glob
import json
import os

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEWS_DIR = os.path.expanduser("~/Code/.claude/code-reviews")
WORK_DIR = os.path.join(REVIEWS_DIR, "queue")
RESULTS_DIR = os.path.join(WORK_DIR, "results")
LOGS_DIR = os.path.join(WORK_DIR, "logs")
QUEUE_FILE = os.path.join(WORK_DIR, "queue.json")
PAGE_FILE = os.path.join(REVIEWS_DIR, "mr-review-queue.html")
TEMPLATE_FILE = os.path.join(SKILL_DIR, "app.html")
BUTLER_REPO = os.path.expanduser("~/Documents/code-stuff/eve/butler")


def load_results():
    """Return the latest review result per MR iid.

    A result file holds a JSON array of one or more MR results. When two files cover the
    same MR, the file with the newer mtime wins, so a re-review replaces a batch result.
    """
    by_iid = {}
    files = sorted(glob.glob(os.path.join(RESULTS_DIR, "*.json")), key=os.path.getmtime)
    for f in files:
        try:
            data = json.load(open(f))
        except (OSError, json.JSONDecodeError):
            continue
        for m in data if isinstance(data, list) else [data]:
            if isinstance(m, dict) and "iid" in m:
                m["result_mtime"] = os.path.getmtime(f)
                by_iid[m["iid"]] = m
    return by_iid


def load_data():
    queue = json.load(open(QUEUE_FILE)) if os.path.exists(QUEUE_FILE) else {"me": "", "team": [], "mrs": []}
    results = load_results()
    mrs = []
    for live in queue["mrs"]:
        review = results.get(live["iid"])
        reviewed_sha = (review or {}).get("head_sha") or ""
        stale = bool(reviewed_sha) and not live["sha"].startswith(reviewed_sha[:10])
        review_file = os.path.join(REVIEWS_DIR, f'MR-{live["iid"]}-review.md')
        mrs.append({
            "live": live,
            "review": review,
            "stale": stale,
            "review_file": review_file if os.path.exists(review_file) else None,
        })
    return {
        "me": queue.get("me", ""),
        "team": queue.get("team", []),
        "fetched_at": queue.get("fetched_at"),
        "mrs": mrs,
    }


def render_page(data, server=None):
    """Fill the app template. `server` is {"token": str} when the page is served live."""
    tpl = open(TEMPLATE_FILE).read()
    boot = {"data": data, "server": server}
    payload = json.dumps(boot).replace("</", "<\\/")
    return tpl.replace("/*__BOOT__*/null", payload)
