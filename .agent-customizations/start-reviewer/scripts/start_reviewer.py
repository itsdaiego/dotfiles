"""Review untouched assigned MRs and take critical-only GitLab actions."""

from __future__ import annotations

import concurrent.futures
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


HOME = Path.home()
BUTLER_REPO = HOME / "Documents/code-stuff/eve/butler"
REVIEW_QUEUE = HOME / ".agent-customizations/review-queue/scripts"
FETCH_QUEUE = REVIEW_QUEUE / "fetch_queue.py"
REVIEW_ONE = REVIEW_QUEUE / "review_one.py"
QUEUE_FILE = HOME / "Code/.claude/code-reviews/queue/queue.json"
RESULTS_DIR = HOME / "Code/.claude/code-reviews/queue/results"
WORK_DIR = HOME / "Code/.claude/code-reviews/start-reviewer"
STATE_FILE = WORK_DIR / "state.json"
LOCK_FILE = WORK_DIR / "cycle.lock"
PYTHON = "/opt/homebrew/bin/python3"
MAX_PARALLEL_REVIEWS = 3


def emit(event: str, **fields: object) -> None:
    print(
        json.dumps(
            {
                "at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "event": event,
                **fields,
            },
            sort_keys=True,
        ),
        flush=True,
    )


def run_command(
    args: list[str],
    *,
    check: bool = True,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=BUTLER_REPO,
        input=input_text,
        text=True,
        capture_output=True,
        check=check,
    )


def glab_json(endpoint: str, *, method: str | None = None, payload: object | None = None) -> object:
    args = ["glab", "api", endpoint]
    temp_path: str | None = None
    try:
        if method:
            args.extend(["--method", method])
        if payload is not None:
            with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as handle:
                json.dump(payload, handle)
                temp_path = handle.name
            args.extend(["--input", temp_path, "-H", "Content-Type: application/json"])
        result = run_command(args)
        return json.loads(result.stdout) if result.stdout.strip() else {}
    finally:
        if temp_path:
            os.unlink(temp_path)


def refresh_queue() -> dict[str, object]:
    run_command([PYTHON, "-I", str(FETCH_QUEUE)])
    return json.loads(QUEUE_FILE.read_text())


def is_candidate(mr: dict[str, object]) -> bool:
    return (
        "reviewer" in mr.get("sources", [])
        and not mr.get("draft", False)
        and not mr.get("approved_by_me", False)
        and mr.get("nobody_started") is True
        and mr.get("needs_review") is True
    )


def load_result(iid: int) -> dict[str, object] | None:
    path = RESULTS_DIR / f"{iid}.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    if isinstance(data, list) and len(data) == 1:
        data = data[0]
    return data if isinstance(data, dict) else None


def result_is_current(result: dict[str, object] | None, mr: dict[str, object]) -> bool:
    return bool(
        result
        and result.get("head_sha") == mr.get("sha")
        and isinstance(result.get("can_approve"), bool)
        and len(result.get("adversarial", [])) == 2
    )


def review(mr: dict[str, object]) -> tuple[int, str | None]:
    iid = int(mr["iid"])
    result = load_result(iid)
    if result_is_current(result, mr):
        emit("review_reused", iid=iid, head_sha=mr.get("sha"))
        return iid, None
    completed = run_command(
        [PYTHON, "-I", str(REVIEW_ONE), str(iid), "--runner", "pi", "--no-render"],
        check=False,
    )
    if completed.returncode:
        error = (completed.stderr or completed.stdout).strip()
        emit("review_failed", iid=iid, error=error)
        return iid, error
    emit("review_completed", iid=iid, head_sha=mr.get("sha"))
    return iid, None


def load_state() -> dict[str, object]:
    if not STATE_FILE.exists():
        return {"actions": {}}
    try:
        state = json.loads(STATE_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return {"actions": {}}
    state.setdefault("actions", {})
    return state


def save_state(state: dict[str, object]) -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix="state.", suffix=".json", dir=WORK_DIR)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(state, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temp_name, STATE_FILE)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def action_key(kind: str, iid: int, head_sha: str, fingerprint: str = "") -> str:
    return f"{kind}:{iid}:{head_sha}:{fingerprint}"


def finding_fingerprint(iid: int, head_sha: str, finding: dict[str, object]) -> str:
    title = str(finding.get("title") or "")
    title = re.sub(r"^\[[^]]+\]\s*", "", title)
    title = re.sub(r"[^a-z0-9]+", " ", title.lower()).strip()
    raw = json.dumps(
        {
            "iid": iid,
            "head_sha": head_sha,
            "file": finding.get("file"),
            "line": finding.get("line"),
            "title": title,
        },
        sort_keys=True,
    )
    return hashlib.sha256(raw.encode()).hexdigest()[:20]


def live_mr(iid: int) -> dict[str, object]:
    return glab_json(f"projects/:id/merge_requests/{iid}")  # type: ignore[return-value]


def approvals(iid: int) -> dict[str, object]:
    return glab_json(f"projects/:id/merge_requests/{iid}/approvals")  # type: ignore[return-value]


def approval_usernames(iid: int) -> set[str]:
    data = approvals(iid)
    return {
        username
        for item in data.get("approved_by", [])
        if isinstance(item, dict)
        and isinstance(item.get("user"), dict)
        and isinstance((username := item["user"].get("username")), str)
    }


def discussion_notes(iid: int) -> list[dict[str, object]]:
    notes: list[dict[str, object]] = []
    page = 1
    while True:
        batch = glab_json(
            f"projects/:id/merge_requests/{iid}/discussions?per_page=100&page={page}"
        )
        if not isinstance(batch, list):
            return notes
        for discussion in batch:
            if not isinstance(discussion, dict):
                continue
            for note in discussion.get("notes", []):
                if isinstance(note, dict):
                    notes.append(note)
        if len(batch) < 100:
            return notes
        page += 1


def review_activity_exists(
    iid: int,
    *,
    author: str,
    me: str,
    team: set[str],
    allowed_my_note_bodies: set[str],
) -> bool:
    for note in discussion_notes(iid):
        note_author = note.get("author", {})
        username = note_author.get("username") if isinstance(note_author, dict) else None
        if note.get("system") or username == author:
            continue
        body = str(note.get("body") or "").strip()
        if username == me and body not in allowed_my_note_bodies:
            return True
        if username in team:
            return True
    return False


def existing_note_bodies(iid: int) -> set[str]:
    result = run_command(
        [
            "glab",
            "api",
            f"projects/:id/merge_requests/{iid}/notes?per_page=100",
            "--paginate",
        ]
    )
    try:
        notes = json.loads(result.stdout)
    except json.JSONDecodeError:
        return set()
    return {note.get("body", "").strip() for note in notes if isinstance(note, dict)}


def existing_drafts(iid: int, head_sha: str) -> dict[str, int]:
    drafts = glab_json(f"projects/:id/merge_requests/{iid}/draft_notes")
    if not isinstance(drafts, list):
        return {}
    matching: dict[str, int] = {}
    for draft in drafts:
        if not isinstance(draft, dict):
            continue
        note = draft.get("note")
        draft_id = draft.get("id")
        position = draft.get("position") or {}
        positioned_head = position.get("head_sha") if isinstance(position, dict) else None
        if (
            isinstance(note, str)
            and isinstance(draft_id, int)
            and positioned_head in (None, head_sha)
        ):
            matching[note.strip()] = draft_id
    return matching


def make_position(path: str, new_line: int, refs: dict[str, object]) -> dict[str, object]:
    line_code = f"{hashlib.sha1(path.encode()).hexdigest()}_0_{new_line}"
    anchor = {
        "line_code": line_code,
        "type": "new",
        "old_line": None,
        "new_line": new_line,
    }
    return {
        **refs,
        "position_type": "text",
        "new_path": path,
        "old_path": path,
        "old_line": None,
        "new_line": new_line,
        "line_range": {"start": anchor, "end": anchor},
    }


def create_draft(iid: int, finding: dict[str, object], refs: dict[str, object], note: str) -> int:
    path = finding.get("file")
    line = finding.get("line")
    payload: dict[str, object] = {"note": note}
    if isinstance(path, str) and isinstance(line, int):
        payload["position"] = make_position(path, line, refs)
    try:
        draft = glab_json(
            f"projects/:id/merge_requests/{iid}/draft_notes",
            method="POST",
            payload=payload,
        )
    except subprocess.CalledProcessError:
        draft = glab_json(
            f"projects/:id/merge_requests/{iid}/draft_notes",
            method="POST",
            payload={"note": note},
        )
    return int(draft["id"])  # type: ignore[index]


def delete_draft(iid: int, draft_id: int) -> None:
    glab_json(
        f"projects/:id/merge_requests/{iid}/draft_notes/{draft_id}",
        method="DELETE",
    )


def publish_draft(iid: int, draft_id: int) -> None:
    glab_json(
        f"projects/:id/merge_requests/{iid}/draft_notes/{draft_id}/publish",
        method="PUT",
    )


def still_untouched(
    entry: dict[str, object],
    live: dict[str, object],
    me: str,
    *,
    team: set[str] | None = None,
    allowed_my_note_bodies: set[str] | None = None,
) -> bool:
    reviewers = live.get("reviewers", [])
    assigned_usernames = {
        reviewer.get("username")
        for reviewer in reviewers
        if isinstance(reviewer, dict)
    }
    untouched = bool(
        is_candidate(entry)
        and live.get("state") == "opened"
        and not live.get("draft", False)
        and me in assigned_usernames
        and not approval_usernames(int(entry["iid"]))
    )
    if not untouched or team is None:
        return untouched
    return not review_activity_exists(
        int(entry["iid"]),
        author=str(entry.get("author") or ""),
        me=me,
        team=team,
        allowed_my_note_bodies=allowed_my_note_bodies or set(),
    )


def act_on_result(
    entry: dict[str, object],
    result: dict[str, object],
    me: str,
    state: dict[str, object],
    *,
    team: set[str] | None = None,
) -> None:
    iid = int(entry["iid"])
    head_sha = str(result["head_sha"])
    live = live_mr(iid)
    if live.get("sha") != head_sha or not still_untouched(entry, live, me, team=team):
        emit("action_skipped_changed_state", iid=iid, reviewed_head=head_sha, live_head=live.get("sha"))
        return

    actions: dict[str, object] = state["actions"]  # type: ignore[assignment]
    critical = result.get("new_critical", [])
    if result.get("can_approve") is True and not critical:
        key = action_key("approve", iid, head_sha)
        if key in actions:
            emit("approval_already_recorded", iid=iid, head_sha=head_sha)
            return
        approved = run_command(["glab", "mr", "approve", str(iid), "--sha", head_sha], check=False)
        if approved.returncode:
            emit("approval_failed", iid=iid, head_sha=head_sha, error=(approved.stderr or approved.stdout).strip())
            return
        actions[key] = {"at": dt.datetime.now(dt.timezone.utc).isoformat(), "kind": "approval"}
        save_state(state)
        emit("approved", iid=iid, head_sha=head_sha)
        return

    if not isinstance(critical, list) or not critical:
        emit("no_action_without_new_critical", iid=iid, head_sha=head_sha)
        return

    note_bodies = existing_note_bodies(iid)
    drafts_by_note = existing_drafts(iid, head_sha)
    refs = live.get("diff_refs")
    if not isinstance(refs, dict):
        emit("comments_skipped_missing_diff_refs", iid=iid, head_sha=head_sha)
        return

    published_this_run: set[str] = set()
    for finding in critical:
        if not isinstance(finding, dict):
            continue
        note = finding.get("suggested_comment") or finding.get("detail")
        if not isinstance(note, str) or not note.strip():
            emit("finding_skipped_missing_comment", iid=iid, title=finding.get("title"))
            continue
        note = note.strip()
        fingerprint = finding_fingerprint(iid, head_sha, finding)
        key = action_key("comment", iid, head_sha, fingerprint)
        if key in actions or note in note_bodies:
            emit("comment_already_present", iid=iid, fingerprint=fingerprint)
            continue
        current = live_mr(iid)
        if current.get("sha") != head_sha or not still_untouched(
            entry,
            current,
            me,
            team=team,
            allowed_my_note_bodies=published_this_run,
        ):
            emit("comment_cancelled_changed_state", iid=iid)
            return
        draft_id = drafts_by_note.get(note)
        created_this_run = draft_id is None
        if draft_id is None:
            draft_id = create_draft(iid, finding, refs, note)
        else:
            emit("existing_draft_reused", iid=iid, draft_id=draft_id)
        current = live_mr(iid)
        if current.get("sha") != head_sha or not still_untouched(
            entry,
            current,
            me,
            team=team,
            allowed_my_note_bodies=published_this_run,
        ):
            if created_this_run:
                delete_draft(iid, draft_id)
            emit("comment_cancelled_changed_state", iid=iid, draft_id=draft_id)
            return
        publish_draft(iid, draft_id)
        published_this_run.add(note)
        actions[key] = {
            "at": dt.datetime.now(dt.timezone.utc).isoformat(),
            "kind": "critical_comment",
            "draft_id": draft_id,
        }
        save_state(state)
        emit("critical_comment_published", iid=iid, draft_id=draft_id, fingerprint=fingerprint)


def cycle() -> int:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    with LOCK_FILE.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            emit("cycle_skipped_already_running")
            return 0

        emit("cycle_started")
        queue = refresh_queue()
        candidates = [mr for mr in queue.get("mrs", []) if isinstance(mr, dict) and is_candidate(mr)]
        emit("candidates_found", iids=[mr["iid"] for mr in candidates])
        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_PARALLEL_REVIEWS) as executor:
            results = list(executor.map(review, candidates))
        failed = {iid for iid, error in results if error}

        me = str(queue.get("me", ""))
        team = {str(username) for username in queue.get("team", [])}
        state = load_state()
        for original in candidates:
            iid = int(original["iid"])
            if iid in failed:
                continue
            result = load_result(iid)
            if not result_is_current(result, original):
                emit("action_skipped_not_current_candidate", iid=iid)
                continue
            act_on_result(original, result, me, state, team=team)
        emit("cycle_completed")
        return 0


if __name__ == "__main__":
    raise SystemExit(cycle())
