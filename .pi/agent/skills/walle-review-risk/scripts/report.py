"""Run the target branch's authoritative Wall-E risk classifier for one committed ref."""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, Optional, Sequence


CLASSIFIER_PATH = "src/document_extractor/tools/risk_tier.py"
RISK_NAMES = {"A": "low", "B": "medium", "C": "high"}


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default="origin/master", help="Target-branch Git ref.")
    parser.add_argument("--head", default="HEAD", help="Committed MR-source Git ref.")
    parser.add_argument("--working-tree", action="store_true", help="Rejected: the authoritative CLI classifies commits only.")
    parser.add_argument("--json", action="store_true", help="Emit the tier and raw authoritative report as JSON.")
    return parser.parse_args(argv)


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], text=True, capture_output=True, check=check)


def resolve_ref(ref: str) -> str:
    return git("rev-parse", "--verify", f"{ref}^{{commit}}").stdout.strip()


def classifier_exists(target: str) -> bool:
    return git("cat-file", "-e", f"{target}:{CLASSIFIER_PATH}", check=False).returncode == 0


@contextmanager
def target_worktree(target: str) -> Iterator[Path]:
    with tempfile.TemporaryDirectory(prefix="walle-review-risk-") as directory:
        path = Path(directory)
        git("worktree", "add", "--detach", str(path), target)
        try:
            yield path
        finally:
            git("worktree", "remove", "--force", str(path), check=False)


def risk_from_report(report: str) -> Optional[str]:
    match = re.search(r"^Tier: ([ABC])$", report, flags=re.MULTILINE)
    return RISK_NAMES[match.group(1)] if match else None


def emit_unlabelled(target: str, json_output: bool) -> int:
    message = f"Wall-E would leave this MR unlabelled because {target} has no {CLASSIFIER_PATH}."
    if json_output:
        print(json.dumps({"risk": None, "target": target, "reason": message}))
    else:
        print(message)
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    if args.working_tree:
        print("Wall-E would leave this preview unlabelled: its authoritative target-branch CLI classifies committed refs only.", file=sys.stderr)
        return 2

    try:
        target = resolve_ref(args.target)
        head = resolve_ref(args.head)
        base = git("merge-base", target, head).stdout.strip()
    except subprocess.CalledProcessError as error:
        print(f"Wall-E would leave this MR unlabelled because Git could not resolve the target or head: {error.stderr.strip()}", file=sys.stderr)
        return 2

    if not classifier_exists(target):
        return emit_unlabelled(target, args.json)

    with target_worktree(target) as worktree:
        run = subprocess.run(
            [sys.executable, "-m", "tools.risk_tier", "report", "--base", target, "--head", head],
            cwd=worktree / "src" / "document_extractor",
            text=True,
            capture_output=True,
        )
    report = run.stdout + run.stderr
    risk = risk_from_report(report)
    if run.returncode != 0 or risk is None:
        print("Wall-E would leave this MR unlabelled because its authoritative classifier did not produce a tier.", file=sys.stderr)
        if report:
            print(report, end="", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps({"risk": risk, "target": target, "head": head, "base": base, "working_tree": False, "report": report}))
    else:
        print(f"Risk: {risk}\nTarget policy and implementation: {target}\nComparison: {base}..{head}\n")
        print(report, end="" if report.endswith("\n") else "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
