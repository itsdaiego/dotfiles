"""Run the review queue server as a launchd agent, so the 20-minute refresh survives reboots.

Usage: python3 -I launchd.py install [--interval-minutes 20] | uninstall | status
"""

import argparse
import json
import os
import plistlib
import subprocess
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from queue_lib import WORK_DIR  # noqa: E402

LABEL = "com.daiego.review-queue"
PLIST_PATH = os.path.expanduser(f"~/Library/LaunchAgents/{LABEL}.plist")
LOG_PATH = os.path.join(WORK_DIR, "daemon.log")
SERVE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "serve.py")
PYTHON = "/opt/homebrew/bin/python3"
# launchd starts with a bare PATH, and the server shells out to glab, claude and pi.
PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + os.path.expanduser("~/.local/bin")
DOMAIN = f"gui/{os.getuid()}"


def install(interval_minutes):
    os.makedirs(WORK_DIR, exist_ok=True)
    plist = {
        "Label": LABEL,
        "ProgramArguments": [PYTHON, "-I", SERVE, "--interval-minutes", f"{interval_minutes:g}"],
        "EnvironmentVariables": {"PATH": PATH},
        "RunAtLoad": True,
        "KeepAlive": True,
        "StandardOutPath": LOG_PATH,
        "StandardErrorPath": LOG_PATH,
    }
    with open(PLIST_PATH, "wb") as f:
        plistlib.dump(plist, f)
    subprocess.run(["launchctl", "bootout", DOMAIN, PLIST_PATH], capture_output=True)
    subprocess.run(["launchctl", "bootstrap", DOMAIN, PLIST_PATH], check=True)
    print(f"Installed {LABEL}, every {interval_minutes:g} min. Page: http://127.0.0.1:8787  Log: {LOG_PATH}")


def uninstall():
    subprocess.run(["launchctl", "bootout", DOMAIN, PLIST_PATH], capture_output=True)
    if os.path.exists(PLIST_PATH):
        os.remove(PLIST_PATH)
    print(f"Removed {LABEL}. Data kept in {WORK_DIR}")


def status():
    loaded = subprocess.run(["launchctl", "print", f"{DOMAIN}/{LABEL}"], capture_output=True).returncode == 0
    print(f"agent loaded: {loaded}")
    try:
        jobs = json.load(urllib.request.urlopen("http://127.0.0.1:8787/api/jobs", timeout=3))
    except OSError as exc:
        print(f"server: not answering ({exc})")
        return
    print(f"schedule: {jobs.get('schedule')}")
    print(f"refresh: {jobs.get('refresh')}")
    for iid, job in jobs.items():
        if iid.isdigit():
            print(f"!{iid}: {job.get('state')} {job.get('error') or ''}".rstrip())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["install", "uninstall", "status"])
    ap.add_argument("--interval-minutes", type=float, default=20)
    a = ap.parse_args()
    if a.command == "install":
        install(a.interval_minutes)
    elif a.command == "uninstall":
        uninstall()
    else:
        status()


if __name__ == "__main__":
    main()
