"""Install and manage the 30-minute start-reviewer LaunchAgent."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import plistlib
import subprocess
from pathlib import Path


HOME = Path.home()
LABEL = "com.daiego.start-reviewer"
DOMAIN = f"gui/{os.getuid()}"
PLIST_PATH = HOME / f"Library/LaunchAgents/{LABEL}.plist"
WORK_DIR = HOME / "Code/.claude/code-reviews/start-reviewer"
LOG_PATH = WORK_DIR / "daemon.log"
STATE_PATH = WORK_DIR / "state.json"
RUNNER = Path(__file__).with_name("start_reviewer.py")
PYTHON = "/opt/homebrew/bin/python3"
INTERVAL_SECONDS = 30 * 60
PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + str(HOME / ".local/bin")


def install() -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    PLIST_PATH.parent.mkdir(parents=True, exist_ok=True)
    plist = {
        "Label": LABEL,
        "ProgramArguments": [PYTHON, "-I", str(RUNNER)],
        "EnvironmentVariables": {
            "HOME": str(HOME),
            "PATH": PATH,
            "PI_CODING_AGENT_DIR": str(HOME / ".pi/pi-personal"),
            "PYTHONUNBUFFERED": "1",
        },
        "RunAtLoad": True,
        "StartInterval": INTERVAL_SECONDS,
        "StandardOutPath": str(LOG_PATH),
        "StandardErrorPath": str(LOG_PATH),
    }
    with PLIST_PATH.open("wb") as handle:
        plistlib.dump(plist, handle)
    subprocess.run(["launchctl", "bootout", DOMAIN, str(PLIST_PATH)], capture_output=True)
    subprocess.run(["launchctl", "bootstrap", DOMAIN, str(PLIST_PATH)], check=True)
    print(f"Installed {LABEL}; runs every 30 minutes and once at load.")
    print(f"Log: {LOG_PATH}")


def uninstall() -> None:
    subprocess.run(["launchctl", "bootout", DOMAIN, str(PLIST_PATH)], capture_output=True)
    if PLIST_PATH.exists():
        PLIST_PATH.unlink()
    print(f"Removed {LABEL}. Logs and state remain in {WORK_DIR}.")


def status() -> None:
    loaded = subprocess.run(
        ["launchctl", "print", f"{DOMAIN}/{LABEL}"],
        capture_output=True,
        text=True,
    )
    print(f"loaded: {loaded.returncode == 0}")
    print("interval_minutes: 30")
    print(f"plist: {PLIST_PATH}")
    print(f"log: {LOG_PATH}")
    if LOG_PATH.exists():
        lines = LOG_PATH.read_text(errors="replace").splitlines()
        for line in lines[-12:]:
            print(line)
    if STATE_PATH.exists():
        try:
            actions = json.loads(STATE_PATH.read_text()).get("actions", {})
        except (json.JSONDecodeError, OSError):
            actions = {}
        print(f"recorded_actions: {len(actions)}")


def run_now() -> None:
    started = dt.datetime.now(dt.timezone.utc)
    completed = subprocess.run([PYTHON, "-I", str(RUNNER)])
    elapsed = (dt.datetime.now(dt.timezone.utc) - started).total_seconds()
    print(f"run_exit: {completed.returncode}")
    print(f"elapsed_seconds: {elapsed:.1f}")
    raise SystemExit(completed.returncode)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["install", "status", "run", "uninstall"])
    args = parser.parse_args()
    if args.command == "install":
        install()
    elif args.command == "status":
        status()
    elif args.command == "run":
        run_now()
    else:
        uninstall()


if __name__ == "__main__":
    main()
