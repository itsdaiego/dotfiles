"""List open MRs for the review queue, with readiness, CI and team review activity.

Usage: python3 -I fetch_queue.py [--out FILE] [--team user1,user2] [--repo DIR] [--team-max-age-days 14]

The queue holds three sets, and each MR lists the sets it came from in `sources`:
- "reviewer": the current user is a reviewer.
- "mine": the current user is the author.
- "team": a teammate is the author. An MR that is only in this set is kept when it was
  updated in the last --team-max-age-days days.

A teammate has "started" a review when they left a non-system note or approved, and they
are not the MR author. Bot accounts never count. An MR needs review when no teammate
started one and the current user has not approved it. `nobody_started` is stricter: the
current user has not left a note or approved either.
"""

import argparse
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from queue_lib import BUTLER_REPO, QUEUE_FILE  # noqa: E402

DEFAULT_TEAM = "urvesh.patel1,acwang,shiva.eve"


def glab(args, repo):
    out = subprocess.run(["glab", *args], capture_output=True, text=True, cwd=repo, timeout=60)
    if out.returncode != 0:
        raise RuntimeError(f"glab {' '.join(args)} failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def discussions(iid, repo):
    notes, page = [], 1
    while True:
        batch = glab(["api", f"projects/:id/merge_requests/{iid}/discussions?per_page=100&page={page}"], repo)
        for d in batch:
            notes.extend(d["notes"])
        if len(batch) < 100:
            return notes
        page += 1


def ci_state(pipeline, repo):
    if not pipeline:
        return {"status": "none", "url": None, "failed_jobs": [], "running_jobs": 0, "manual_jobs": 0}
    jobs = glab(["api", f'projects/:id/pipelines/{pipeline["id"]}/jobs?per_page=100&include_retried=false'], repo)
    failed = [j["name"] for j in jobs if j["status"] == "failed" and not j.get("allow_failure")]
    return {
        "status": pipeline["status"],
        "url": pipeline.get("web_url"),
        "failed_jobs": failed,
        "running_jobs": sum(j["status"] in ("running", "pending") for j in jobs),
        "manual_jobs": sum(j["status"] == "manual" for j in jobs),
        "updated_at": pipeline.get("updated_at"),
    }


def enrich(mr, team, me, repo):
    iid = mr["iid"]
    author = mr["author"]["username"]
    detail = glab(["api", f"projects/:id/merge_requests/{iid}"], repo)
    approvals = glab(["api", f"projects/:id/merge_requests/{iid}/approvals"], repo)
    approved_by = [a["user"]["username"] for a in approvals["approved_by"]]

    team_comments, team_open_threads, my_notes = {}, {}, 0
    for n in discussions(iid, repo):
        user = n["author"]["username"]
        if n.get("system") or user == author:
            continue
        if user == me:
            my_notes += 1
        if user in team:
            team_comments[user] = team_comments.get(user, 0) + 1
            if n.get("resolvable") and not n.get("resolved"):
                team_open_threads[user] = team_open_threads.get(user, 0) + 1
    team_approved = [u for u in approved_by if u in team and u != author]
    started_by = sorted(set(team_comments) | set(team_approved))

    return {
        "iid": iid,
        "title": mr["title"],
        "url": mr["web_url"],
        "author": author,
        "source_branch": mr["source_branch"],
        "target_branch": mr["target_branch"],
        "draft": mr["draft"],
        "labels": mr.get("labels", []),
        "sha": detail["sha"],
        "ci": ci_state(detail.get("head_pipeline"), repo),
        "merge_status": detail["detailed_merge_status"],
        "has_conflicts": detail["has_conflicts"],
        "blocking_discussions_resolved": detail.get("blocking_discussions_resolved"),
        "approved_by": approved_by,
        "approvals_left": approvals.get("approvals_left"),
        "team_comments": team_comments,
        "team_open_threads": team_open_threads,
        "team_approved": team_approved,
        "team_started_by": started_by,
        "approved_by_me": me in approved_by,
        "needs_review": not started_by and me not in approved_by,
        "nobody_started": not started_by and me not in approved_by and not my_notes,
        "is_mine": author == me,
        "sources": mr["sources"],
        "created_at": mr["created_at"],
        "updated_at": mr["updated_at"],
    }


def list_sources(me, team, repo, team_max_age_days):
    queries = [("reviewer", "--reviewer=@me"), ("mine", "--author=@me")]
    queries += [("team", f"--author={user}") for user in sorted(team) if user != me]
    by_iid = {}
    for source, flag in queries:
        for mr in glab(["mr", "list", flag, "-F", "json", "--per-page", "100"], repo):
            by_iid.setdefault(mr["iid"], {**mr, "sources": []})["sources"].append(source)
    # Teammates keep many abandoned MRs open. Without a cutoff, each one would get an automatic review.
    now = datetime.now(timezone.utc)
    return [
        mr for mr in by_iid.values()
        if mr["sources"] != ["team"]
        or (now - datetime.fromisoformat(mr["updated_at"].replace("Z", "+00:00"))).days <= team_max_age_days
    ]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=QUEUE_FILE)
    p.add_argument("--team", default=DEFAULT_TEAM)
    p.add_argument("--repo", default=BUTLER_REPO)
    p.add_argument("--team-max-age-days", type=int, default=14)
    a = p.parse_args()
    team = set(a.team.split(","))
    me = glab(["api", "user"], a.repo)["username"]
    mrs = list_sources(me, team, a.repo, a.team_max_age_days)
    with ThreadPoolExecutor(max_workers=8) as pool:
        queue = list(pool.map(lambda m: enrich(m, team, me, a.repo), mrs))
    queue.sort(key=lambda m: -m["iid"])
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    fetched_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    json.dump({"me": me, "team": sorted(team), "fetched_at": fetched_at, "mrs": queue}, open(a.out, "w"), indent=1)
    for m in queue:
        if m["is_mine"]:
            flag = "yours, " + ("not started" if m["needs_review"] else "started by " + ", ".join(m["team_started_by"]))
        elif m["approved_by_me"]:
            flag = "approved by you"
        elif m["needs_review"]:
            flag = "NEEDS REVIEW"
        else:
            flag = "started by " + ", ".join(m["team_started_by"])
        ci = m["ci"]["status"] + (f' ({", ".join(m["ci"]["failed_jobs"])})' if m["ci"]["failed_jobs"] else "")
        print(f'!{m["iid"]}\t{"+".join(m["sources"])}\t{m["author"]}\t{"draft" if m["draft"] else m["merge_status"]}\tCI {ci}\t{flag}\t{m["sha"][:10]}')


if __name__ == "__main__":
    main()
