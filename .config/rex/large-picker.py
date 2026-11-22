#!/usr/bin/env python3

import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Optional


AGENT_NAMES = {
    "claude": "Claude",
    "claude-code": "Claude",
    "codex": "Codex",
    "gemini": "Gemini",
    "pi": "Pi",
}
PROGRAM_NAMES = {
    **AGENT_NAMES,
    "nvim": "Neovim",
    "vim": "Vim",
    "zsh": "zsh",
    "bash": "bash",
    "fish": "fish",
    "node": "Node",
    "python": "Python",
    "python3": "Python",
}


def find_binary(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found

    if name == "rex":
        rex_bin_dir = os.environ.get("REX_BIN_DIR")
        if rex_bin_dir:
            candidate = Path(rex_bin_dir) / "rex"
            if candidate.is_file():
                return str(candidate)

    homebrew = Path("/opt/homebrew/bin") / name
    if homebrew.is_file():
        return str(homebrew)

    raise RuntimeError(f"Could not find {name}")


def run_json(command: list[str]) -> dict:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def try_json(command: list[str]) -> dict:
    try:
        return run_json(command)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return {}


def session_records(rex: str) -> list[tuple[str, ...]]:
    sessions = run_json([rex, "ls", "--json"]).get("sessions", [])
    return [(session["label"], session["session_id"]) for session in sessions]


def compact_path(path: str) -> str:
    home = str(Path.home())
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        return "~" + path[len(home):]
    return path


def process_name(process: dict, block_label: str) -> tuple[str, bool]:
    foreground = process.get("foreground") or process.get("child") or {}
    raw_name = (
        foreground.get("argv0")
        or (Path(foreground["script"]).name if foreground.get("script") else None)
        or foreground.get("name")
        or block_label
        or "Pane"
    )
    normalized = Path(str(raw_name)).name.lower().lstrip("-")
    return PROGRAM_NAMES.get(normalized, Path(str(raw_name)).name), normalized in AGENT_NAMES


STATUS_PRIORITY = {"working": 5, "blocked": 4, "error": 3, "done": 2, "idle": 1}
STATUS_LABELS = {
    "working": "running",
    "blocked": "idle",
    "error": "done",
    "done": "done",
    "idle": "idle",
}


def normalized_agent_status(program_status: dict) -> str:
    states = [
        record.get("state")
        for record in program_status.get("records", [])
        if record.get("state") in STATUS_PRIORITY
    ]
    if not states:
        return "idle"
    state = max(states, key=lambda item: STATUS_PRIORITY[item])
    return STATUS_LABELS[state]


def clipped(value: str, limit: int) -> str:
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "…"


def aligned_records(rows: list[dict], agents_only: bool) -> list[tuple[str, ...]]:
    if not rows:
        return []

    for row in rows:
        row["program"] = clipped(row["program"], 10)
        row["session"] = clipped(row["session"], 32)
        row["detail"] = clipped(row["detail"], 36)

    program_width = max(5, *(len(row["program"]) for row in rows))
    session_width = max(7, *(len(row["session"]) for row in rows))
    detail_width = max(4, *(len(row["detail"]) for row in rows))

    records: list[tuple[str, ...]] = []
    for row in rows:
        columns = [row["program"].ljust(program_width)]
        if agents_only:
            columns.append(row["status"].ljust(7))
        columns.extend(
            [
                row["session"].ljust(session_width),
                row["detail"].ljust(detail_width),
                row["cwd"],
            ]
        )
        display = " │ ".join(columns).rstrip()
        records.append((display, *row["metadata"]))
    return records


def records_from_snapshot(
    snapshot: list[dict], agents_only: bool
) -> list[tuple[str, ...]]:
    rows: list[dict] = []
    for pane in snapshot:
        session_id = pane["session_id"]
        session_label = pane["session_label"]
        window_id = pane["window_id"]
        window_label = pane["window_label"]
        block_id = pane["block_id"]
        block_label = pane["block_label"]
        window_zoomed = pane.get("window_zoomed", False)
        process = pane.get("process") or {}
        foreground = process.get("foreground") or process.get("child") or {}
        if Path(foreground.get("script", "")).name == "large-picker.py":
            continue

        program, is_agent = process_name(process, block_label)
        if agents_only and not is_agent:
            continue

        cwd = compact_path(foreground.get("cwd", ""))
        detail = block_label
        if detail.lower() in {"pane", "shell", "terminal"} or detail == program:
            detail = window_label
        if detail.startswith("Window ") or detail in {program, session_label}:
            detail = ""

        rows.append(
            {
                "program": program,
                "status": normalized_agent_status(pane.get("program_status") or {}),
                "session": session_label,
                "detail": detail,
                "cwd": cwd,
                "metadata": (
                    session_id,
                    window_id,
                    block_id,
                    "1" if window_zoomed else "0",
                ),
            }
        )

    return aligned_records(rows, agents_only)


def detailed_records(rex: str, agents_only: bool) -> list[tuple[str, ...]]:
    sessions = run_json([rex, "ls", "--json"]).get("sessions", [])
    current_block = os.environ.get("REX_BLOCK")

    def inspect_session(session: dict) -> tuple[dict, dict]:
        view = run_json([rex, "session", "inspect", session["session_id"], "--json"])
        return session, view

    with ThreadPoolExecutor(max_workers=max(1, min(8, len(sessions)))) as executor:
        inspected_sessions = list(executor.map(inspect_session, sessions))

    panes: list[tuple[str, str, str, str, str, str, bool]] = []
    for session, view in inspected_sessions:
        session_id = session["session_id"]
        session_label = session["label"]
        for window in view.get("windows", []):
            window_id = window["window_id"]
            window_label = window.get("label") or "Tab"
            for layer in window.get("layers", []):
                for block in layer.get("blocks", []):
                    block_id = block["block_id"]
                    if block_id == current_block:
                        continue
                    panes.append(
                        (
                            session_id,
                            session_label,
                            window_id,
                            window_label,
                            block_id,
                            block.get("label") or "Pane",
                            window.get("zoomed_block_id") is not None,
                        )
                    )

    def inspect_pane(
        pane: tuple[str, ...],
    ) -> tuple[tuple[str, ...], dict, dict]:
        session_id, _, _, _, block_id, _, _ = pane
        base = [rex, "block", "call", "-s", session_id, "-b", block_id]
        process = try_json([*base, "process"])
        program_status = try_json([*base, "program_status"])
        return pane, process, program_status

    with ThreadPoolExecutor(max_workers=max(1, min(16, len(panes)))) as executor:
        inspected_panes = list(executor.map(inspect_pane, panes))

    snapshot = []
    for pane, process, program_status in inspected_panes:
        (
            session_id,
            session_label,
            window_id,
            window_label,
            block_id,
            block_label,
            window_zoomed,
        ) = pane
        snapshot.append(
            {
                "session_id": session_id,
                "session_label": session_label,
                "window_id": window_id,
                "window_label": window_label,
                "block_id": block_id,
                "block_label": block_label,
                "window_zoomed": window_zoomed,
                "process": process,
                "program_status": program_status,
            }
        )

    return records_from_snapshot(snapshot, agents_only)


def block_records(rex: str) -> list[tuple[str, ...]]:
    return detailed_records(rex, agents_only=False)


def agent_records(rex: str) -> list[tuple[str, ...]]:
    return detailed_records(rex, agents_only=True)


def run_picker_command(command: list[str], description: str) -> bool:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode == 0:
        return True

    detail = (result.stderr or result.stdout).strip()
    print(f"Could not {description}.", file=sys.stderr)
    if detail:
        print(detail, file=sys.stderr)
    print("Press Enter to close.", file=sys.stderr)
    try:
        input()
    except EOFError:
        pass
    return False


def open_choice(
    rex: str, client_target: str, mode: str, choice: tuple[str, ...]
) -> bool:
    if mode == "sessions":
        _, session_id = choice
        return run_picker_command(
            [rex, "-C", client_target, "do", "session.select", f"session_id={session_id}"],
            "switch sessions",
        )

    _, session_id, window_id, block_id, *metadata = choice
    was_zoomed = bool(metadata and metadata[0] == "1")
    if not run_picker_command(
        [rex, "focus", "-s", session_id, block_id],
        "focus the selected pane",
    ):
        return False

    if was_zoomed and not run_picker_command(
        [rex, "zoom", "-s", session_id, block_id, "--on"],
        "restore the selected pane's zoom",
    ):
        return False

    return run_picker_command(
        [
            rex,
            "-C",
            client_target,
            "do",
            "session.select",
            f"session_id={session_id}",
            f"window_id={window_id}",
        ],
        "show the selected pane",
    )


def pick(fzf: str, title: str, records: list[tuple[str, ...]]) -> Optional[tuple[str, ...]]:
    if not records:
        return None

    lines = "\n".join("\t".join(record) for record in records) + "\n"
    result = subprocess.run(
        [
            fzf,
            "--layout=reverse",
            "--border=rounded",
            "--padding=1,2",
            "--margin=1,2",
            "--info=inline-right",
            "--delimiter=\t",
            "--with-nth=1",
            f"--prompt={title}  ",
            "--pointer=▶",
            "--header=Enter: open  •  Esc: close",
        ],
        input=lines,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return tuple(result.stdout.rstrip("\n").split("\t"))


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "usage: large-picker.py <sessions|blocks|agents> <client-target> [--print]",
            file=sys.stderr,
        )
        return 2

    mode, client_target = sys.argv[1:3]
    extra_args = sys.argv[3:]
    rex = find_binary("rex")
    if mode == "sessions":
        records = session_records(rex)
        title = "Sessions"
    elif "--snapshot-json" in extra_args:
        snapshot_index = extra_args.index("--snapshot-json") + 1
        snapshot = json.loads(extra_args[snapshot_index])
        records = records_from_snapshot(snapshot, agents_only=mode == "agents")
        title = "Agents" if mode == "agents" else "Programs"
    elif mode == "agents":
        records = agent_records(rex)
        title = "Agents"
    else:
        records = block_records(rex)
        title = "Programs"

    if "--print" in extra_args:
        for record in records:
            print("\t".join(record))
        return 0

    choice = pick(find_binary("fzf"), title, records)
    if choice is None:
        return 0

    return 0 if open_choice(rex, client_target, mode, choice) else 1


if __name__ == "__main__":
    raise SystemExit(main())
