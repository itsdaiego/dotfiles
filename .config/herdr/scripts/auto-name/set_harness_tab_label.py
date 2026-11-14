#!/usr/bin/env python3

import os
import subprocess
import sys


KNOWN_HARNESSES = {"claude", "codex", "pi"}


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if len(arguments) != 1 or arguments[0] not in KNOWN_HARNESSES:
        raise SystemExit("usage: set_harness_tab_label.py {claude|codex|pi}")

    if os.environ.get("HERDR_ENV") != "1":
        return

    tab_id = os.environ.get("HERDR_TAB_ID")
    if not tab_id:
        return

    try:
        subprocess.run(
            ["herdr", "tab", "rename", tab_id, arguments[0]],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


if __name__ == "__main__":
    main()
