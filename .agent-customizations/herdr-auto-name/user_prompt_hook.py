#!/usr/bin/env python3

from pathlib import Path
import runpy


script_path = Path.home() / ".config/herdr/scripts/auto-name/user_prompt_hook.py"
if not script_path.exists():
    script_path = (
        Path(__file__).resolve().parents[2]
        / ".config/herdr/scripts/auto-name/user_prompt_hook.py"
    )

runpy.run_path(str(script_path), run_name="__main__")
