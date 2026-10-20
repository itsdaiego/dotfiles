"""Run one unattended MR review with Claude Code or Pi, then re-render the page.

Usage: python3 -I review_one.py <iid> [--runner claude|pi] [--no-render]

The runner follows the read-mr and review-mr skills (see review_prompt.md) and writes
results/<iid>.json. The log goes to logs/<iid>.log. Exit code 0 means the result file
exists and parses.

The prompt forbids GitLab writes. The Claude runner also denies the common write forms of
`glab`, but `glab api` stays allowed for reads, so the prompt is the main guard. The Pi
runner has unrestricted bash and relies on the prompt alone.
"""

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from queue_lib import (  # noqa: E402
    BUTLER_REPO,
    LOGS_DIR,
    PAGE_FILE,
    QUEUE_FILE,
    RESULTS_DIR,
    SKILL_DIR,
    load_data,
    render_page,
)

READ_MR_SKILL = os.path.expanduser("~/.claude/skills/read-mr/SKILL.md")
REVIEW_MR_SKILL = os.path.expanduser("~/.claude/skills/review-mr/SKILL.md")
TIMEOUT_S = 40 * 60

CLAUDE_TOOLS = [
    "Skill", "Read", "Grep", "Glob", "Write",
    "Bash(glab mr view:*)", "Bash(glab mr diff:*)", "Bash(glab api:*)",
    "Bash(git fetch:*)", "Bash(git show:*)", "Bash(git log:*)", "Bash(git diff:*)",
    "Bash(git rev-parse:*)", "Bash(git grep:*)", "Bash(git ls-tree:*)",
    "Bash(python3 -c:*)", "Bash(rg:*)", "Bash(grep:*)", "Bash(ls:*)", "Bash(cat:*)",
]

CLAUDE_DENIED = [
    "Bash(glab api --method:*)", "Bash(glab api -X:*)", "Bash(glab mr approve:*)",
    "Bash(glab mr note:*)", "Bash(glab mr merge:*)", "Bash(glab mr update:*)",
    "Bash(glab mr close:*)", "Bash(git push:*)", "Bash(git checkout:*)", "Bash(git switch:*)",
]


def stack_note(iid):
    if not os.path.exists(QUEUE_FILE):
        return ""
    mrs = json.load(open(QUEUE_FILE))["mrs"]
    me = next((m for m in mrs if m["iid"] == iid), None)
    if not me:
        return ""
    parent = next((m for m in mrs if m["source_branch"] == me["target_branch"]), None)
    if me["target_branch"] in ("master", "main"):
        return ""
    note = f'This MR is stacked: its target branch is `{me["target_branch"]}`'
    note += f' (!{parent["iid"]}).' if parent else "."
    return note + " Review only the diff against its target branch. It cannot merge before its parent, so it is not ready."


def build_prompt(iid, me, result_path):
    tpl = open(os.path.join(SKILL_DIR, "review_prompt.md")).read()
    return tpl.format(
        iid=iid, me=me, result_path=result_path, stack_note=stack_note(iid),
        read_mr_skill=READ_MR_SKILL, review_mr_skill=REVIEW_MR_SKILL,
    )


def command(runner, prompt):
    if runner == "pi":
        return ["pi", "-p", "--no-session", "--skill", os.path.dirname(READ_MR_SKILL),
                "--skill", os.path.dirname(REVIEW_MR_SKILL), prompt]
    return ["claude", "-p", "--allowedTools", ",".join(CLAUDE_TOOLS),
            "--disallowedTools", ",".join(CLAUDE_DENIED),
            "--add-dir", os.path.expanduser("~/Code/.claude/code-reviews"), "--", prompt]


def runner_env(runner):
    """Environment for the child run.

    Drops ANTHROPIC_API_KEY so `claude -p` uses the claude.ai login instead of an API key
    from the shell profile, and drops the parent session's Claude Code variables so the
    child does not attach to the session that started it.
    """
    env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_CODE_") and k not in ("CLAUDECODE", "CLAUDE_PID")}
    if runner == "claude":
        env.pop("ANTHROPIC_API_KEY", None)
    return env


def run(iid, runner):
    os.makedirs(RESULTS_DIR, exist_ok=True)
    os.makedirs(LOGS_DIR, exist_ok=True)
    result_path = os.path.join(RESULTS_DIR, f"{iid}.json")
    log_path = os.path.join(LOGS_DIR, f"{iid}.log")
    me = json.load(open(QUEUE_FILE)).get("me", "") if os.path.exists(QUEUE_FILE) else ""
    before = os.path.getmtime(result_path) if os.path.exists(result_path) else None
    with open(log_path, "w") as log:
        log.write(f"runner={runner} iid={iid}\n")
        log.flush()
        proc = subprocess.run(command(runner, build_prompt(iid, me, result_path)), cwd=BUTLER_REPO, env=runner_env(runner), stdin=subprocess.DEVNULL,
                              stdout=log, stderr=subprocess.STDOUT, timeout=TIMEOUT_S)
    if not os.path.exists(result_path) or os.path.getmtime(result_path) == before:
        raise RuntimeError(f"no new result file (exit {proc.returncode}); see {log_path}")
    json.load(open(result_path))
    return result_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("iid", type=int)
    ap.add_argument("--runner", choices=["claude", "pi"], default="claude")
    ap.add_argument("--no-render", action="store_true")
    a = ap.parse_args()
    path = run(a.iid, a.runner)
    print("result", path)
    if not a.no_render:
        open(PAGE_FILE, "w").write(render_page(load_data()))
        print("rendered", PAGE_FILE)


if __name__ == "__main__":
    main()
