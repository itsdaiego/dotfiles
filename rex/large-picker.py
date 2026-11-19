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


def records_from_snapshot(
    snapshot: list[dict], agents_only: bool
) -> list[tuple[str, ...]]:
    records: list[tuple[str, ...]] = []
    for pane in snapshot:
        session_id = pane["session_id"]
        session_label = pane["session_label"]
        window_id = pane["window_id"]
        window_label = pane["window_label"]
        block_id = pane["block_id"]
        block_label = pane["block_label"]
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

        display_parts = [program, session_label]
        if detail:
            display_parts.append(detail)
        if cwd:
            display_parts.append(cwd)
        display = "  ·  ".join(display_parts[:2])
        if len(display_parts) > 2:
            display += "  ›  " + "  ›  ".join(display_parts[2:])
        records.append((display, session_id, window_id, block_id))

    return records


def detailed_records(rex: str, agents_only: bool) -> list[tuple[str, ...]]:
    sessions = run_json([rex, "ls", "--json"]).get("sessions", [])
    current_block = os.environ.get("REX_BLOCK")

    def inspect_session(session: dict) -> tuple[dict, dict]:
        view = run_json([rex, "session", "inspect", session["session_id"], "--json"])
        return session, view

    with ThreadPoolExecutor(max_workers=max(1, min(8, len(sessions)))) as executor:
        inspected_sessions = list(executor.map(inspect_session, sessions))

    panes: list[tuple[str, str, str, str, str, str]] = []
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
                        )
                    )

    def inspect_process(pane: tuple[str, ...]) -> tuple[tuple[str, ...], dict]:
        session_id, _, _, _, block_id, _ = pane
        command = [rex, "block", "call", "-s", session_id, "-b", block_id, "process"]
        return pane, try_json(command)

    with ThreadPoolExecutor(max_workers=max(1, min(16, len(panes)))) as executor:
        inspected_panes = list(executor.map(inspect_process, panes))

    snapshot = []
    for pane, process in inspected_panes:
        session_id, session_label, window_id, window_label, block_id, block_label = pane
        snapshot.append(
            {
                "session_id": session_id,
                "session_label": session_label,
                "window_id": window_id,
                "window_label": window_label,
                "block_id": block_id,
                "block_label": block_label,
                "process": process,
            }
        )

    return records_from_snapshot(snapshot, agents_only)


def block_records(rex: str) -> list[tuple[str, ...]]:
    return detailed_records(rex, agents_only=False)


def agent_records(rex: str) -> list[tuple[str, ...]]:
    return detailed_records(rex, agents_only=True)


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
            "usage: large-picker.py <sessions|blocks|agents> <client-id> [--print]",
            file=sys.stderr,
        )
        return 2

    mode, client_id = sys.argv[1:3]
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

    if mode == "sessions":
        _, session_id = choice
        subprocess.run(
            [rex, "-C", client_id, "do", "session.select", f"session_id={session_id}"],
            check=False,
        )
        return 0

    _, session_id, window_id, block_id = choice
    subprocess.run([rex, "focus", "-s", session_id, block_id], check=False)
    subprocess.run(
        [
            rex,
            "-C",
            client_id,
            "do",
            "session.select",
            f"session_id={session_id}",
            f"window_id={window_id}",
        ],
        check=False,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
