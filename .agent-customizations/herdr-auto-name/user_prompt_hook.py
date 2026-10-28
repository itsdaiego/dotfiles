#!/usr/bin/env python3

import json
import os
import subprocess
import sys


RENAME_CONTEXT = (
    "The current root agent is running inside Herdr and has no task name. "
    "Before substantive work, infer a concise task description from the user's prompt. "
    "Convert it to a lowercase ASCII kebab-case slug with two to five useful words and "
    "at most 32 characters. Run `herdr agent rename \"$HERDR_PANE_ID\" \"<slug>\"` "
    "once. Herdr's bold top line combines the workspace/project name with the harness "
    "tab label (for example, `chessan · codex`). The inferred task name belongs on the "
    "lower description line. Do not rename an agent that already has a task name, and "
    "do not rename subagents."
)


def current_agent(pane_id):
    try:
        result = subprocess.run(
            ["herdr", "agent", "get", pane_id],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )
        if result.returncode != 0:
            return None
        payload = json.loads(result.stdout)
        return payload.get("result", {}).get("agent")
    except (FileNotFoundError, json.JSONDecodeError, subprocess.TimeoutExpired):
        return None


def set_harness_tab_label(tab_id, harness):
    if not tab_id or harness not in {"codex", "claude", "pi"}:
        return

    try:
        subprocess.run(
            ["herdr", "tab", "rename", tab_id, harness],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def main():
    sys.stdin.read()

    if os.environ.get("HERDR_ENV") != "1":
        return

    pane_id = os.environ.get("HERDR_PANE_ID")
    if not pane_id:
        return

    agent = current_agent(pane_id)
    if not agent:
        return

    set_harness_tab_label(os.environ.get("HERDR_TAB_ID"), agent.get("agent"))

    if agent.get("name"):
        return

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": RENAME_CONTEXT,
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
