"""Serve the review queue page with working review buttons.

Usage: python3 -I serve.py [--port 8787] [--runner claude|pi] [--parallel 3] [--interval-minutes 20]
                            [--no-auto-review] [--review-drafts]

Every --interval-minutes (0 turns it off), the server refreshes the queue and starts a review for
each MR that has no result or a stale one. It skips MRs Daiego approved, drafts unless
--review-drafts, and an MR whose last automatic review failed on the same head.

Binds to 127.0.0.1 only. Every POST needs the per-run token that the served page carries,
so another site open in the browser cannot start reviews.
"""

import argparse
import json
import os
import secrets
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import review_one  # noqa: E402
from queue_lib import LOGS_DIR, PAGE_FILE, REVIEWS_DIR, load_data, render_page  # noqa: E402

TOKEN = secrets.token_urlsafe(24)
JOBS = {}
LOCK = threading.Lock()
SCRIPTS = os.path.dirname(os.path.abspath(__file__))


def write_static_page():
    open(PAGE_FILE, "w").write(render_page(load_data()))


def set_job(iid, **fields):
    with LOCK:
        JOBS.setdefault(iid, {}).update(fields)


def run_review(iid, runner, sha=None):
    set_job(iid, state="running", started=time.time(), sha=sha)
    try:
        review_one.run(iid, runner)
        set_job(iid, state="done", finished=time.time(), error=None)
        write_static_page()
    except Exception as exc:
        set_job(iid, state="failed", finished=time.time(), error=str(exc))


def submit_review(pool, iid, runner, sha=None):
    """Queue a review unless one is already queued or running. Returns False when skipped."""
    with LOCK:
        if JOBS.get(iid, {}).get("state") in ("queued", "running"):
            return False
        JOBS[iid] = {"state": "queued", "runner": runner, "queued": time.time(), "sha": sha}
    pool.submit(run_review, iid, runner, sha)
    return True


def needs_auto_review(mr, review_drafts):
    live = mr["live"]
    if live["approved_by_me"] or (live["draft"] and not review_drafts):
        return False
    if mr["review"] and not mr["stale"]:
        return False
    with LOCK:
        job = JOBS.get(live["iid"], {})
    return not (job.get("state") == "failed" and job.get("sha") == live["sha"])


def schedule_loop(pool, runner, interval_s, auto_review, review_drafts):
    while True:
        set_job("schedule", state="running", started=time.time(), next_run=None)
        started = []
        try:
            run_refresh()
            if auto_review and JOBS.get("refresh", {}).get("state") == "done":
                for mr in load_data()["mrs"]:
                    live = mr["live"]
                    if needs_auto_review(mr, review_drafts) and submit_review(pool, live["iid"], runner, live["sha"]):
                        started.append(live["iid"])
            error = None
        except Exception as exc:
            set_job("refresh", state="failed", finished=time.time(), error=str(exc))
            error = str(exc)
        print(f"{time.strftime('%Y-%m-%d %H:%M:%S')} scheduled run: refresh {JOBS['refresh']['state']}, "
              f"reviews started {started or 'none'}", flush=True)
        set_job("schedule", state="waiting", finished=time.time(), next_run=time.time() + interval_s,
                reviews_started=started, error=error)
        time.sleep(interval_s)


def run_refresh():
    set_job("refresh", state="running", started=time.time())
    proc = subprocess.run([sys.executable, "-I", os.path.join(SCRIPTS, "fetch_queue.py")],
                          capture_output=True, text=True, timeout=600)
    if proc.returncode == 0:
        set_job("refresh", state="done", finished=time.time(), error=None)
        write_static_page()
    else:
        set_job("refresh", state="failed", finished=time.time(), error=proc.stderr[-2000:])


class Handler(BaseHTTPRequestHandler):
    pool: ThreadPoolExecutor
    runner: str

    def log_message(self, format, *args):  # noqa: A002
        return

    def send(self, code, body, ctype="application/json"):
        raw = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def jobs_json(self):
        with LOCK:
            return json.dumps({str(k): v for k, v in JOBS.items()})

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            return self.send(200, render_page(load_data(), server={"token": TOKEN, "runner": self.runner}),
                             "text/html; charset=utf-8")
        if path == "/api/data":
            return self.send(200, json.dumps(load_data()))
        if path == "/api/jobs":
            return self.send(200, self.jobs_json())
        if path.startswith("/api/log/") or path.startswith("/api/review-file/"):
            iid = path.rsplit("/", 1)[-1]
            if not iid.isdigit():
                return self.send(400, '{"error":"bad iid"}')
            f = (os.path.join(LOGS_DIR, f"{iid}.log") if "/log/" in path
                 else os.path.join(REVIEWS_DIR, f"MR-{iid}-review.md"))
            if not os.path.exists(f):
                return self.send(404, "not found", "text/plain")
            text = open(f, errors="replace").read()
            return self.send(200, text[-20000:] if "/log/" in path else text, "text/plain; charset=utf-8")
        self.send(404, '{"error":"not found"}')

    def do_POST(self):
        if self.headers.get("X-Token") != TOKEN:
            return self.send(403, '{"error":"bad token"}')
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        if self.path == "/api/review":
            iid = int(body["iid"])
            runner = body.get("runner") or self.runner
            if runner not in ("claude", "pi"):
                return self.send(400, '{"error":"bad runner"}')
            if not submit_review(self.pool, iid, runner):
                return self.send(409, '{"error":"already running"}')
            return self.send(202, self.jobs_json())
        if self.path == "/api/refresh":
            with LOCK:
                if JOBS.get("refresh", {}).get("state") == "running":
                    return self.send(409, '{"error":"already refreshing"}')
            threading.Thread(target=run_refresh, daemon=True).start()
            return self.send(202, self.jobs_json())
        self.send(404, '{"error":"not found"}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--runner", choices=["claude", "pi"], default="claude")
    ap.add_argument("--parallel", type=int, default=3)
    ap.add_argument("--interval-minutes", type=float, default=20)
    ap.add_argument("--no-auto-review", action="store_true")
    ap.add_argument("--review-drafts", action="store_true")
    a = ap.parse_args()
    Handler.pool = ThreadPoolExecutor(max_workers=a.parallel)
    Handler.runner = a.runner
    server = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    print(f"review queue: http://127.0.0.1:{a.port}/  (runner={a.runner}, parallel={a.parallel}, "
          f"every {a.interval_minutes:g} min, auto review {'off' if a.no_auto_review else 'on'})", flush=True)
    if a.interval_minutes > 0:
        threading.Thread(target=schedule_loop, daemon=True,
                         args=(Handler.pool, a.runner, a.interval_minutes * 60, not a.no_auto_review,
                               a.review_drafts)).start()
    server.serve_forever()


if __name__ == "__main__":
    main()
