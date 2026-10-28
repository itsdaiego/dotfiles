"""Report a local Wall-E risk tier with the policy from the target ref."""

import argparse
import json
import sys
from collections.abc import Sequence

from tools.risk_tier import MAP_PATH, Tier, TierMap, classify, collect_changes, run_git

_RISK_NAMES = {
    Tier.A: "low",
    Tier.B: "medium",
    Tier.C: "high",
}


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target",
        default="origin/master",
        help="Git ref for the target branch and its risk policy.",
    )
    parser.add_argument(
        "--head",
        default="HEAD",
        help="Git ref for the MR source branch or commit.",
    )
    parser.add_argument(
        "--policy-ref",
        help="Git ref that supplies the risk policy. Defaults to --target.",
    )
    parser.add_argument(
        "--working-tree",
        action="store_true",
        help="Include unstaged and untracked files instead of classifying HEAD.",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON output.")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.working_tree and args.head != "HEAD":
        print("--working-tree cannot be combined with --head.", file=sys.stderr)
        return 2

    head = None if args.working_tree else args.head
    policy_ref = args.policy_ref or args.target
    try:
        base = run_git("merge-base", args.target, head or "HEAD").strip()
        policy = TierMap.parse(run_git("show", f"{policy_ref}:{MAP_PATH}"))
        changes = collect_changes(base, head)
    except Exception as error:
        print(
            "Wall-E would leave this MR unlabelled because it cannot read the "
            f"target-branch policy or diff: {error}",
            file=sys.stderr,
        )
        return 2

    if not changes:
        print(
            "Wall-E would leave this MR unlabelled because it has no changed files.",
            file=sys.stderr,
        )
        return 2

    report = classify(policy, changes)
    output = report.to_json()
    output.update(
        {
            "base": base,
            "head": args.head,
            "policy_ref": policy_ref,
            "risk": _RISK_NAMES[report.tier],
            "working_tree": args.working_tree,
        }
    )
    if args.json:
        print(json.dumps(output, indent=2))
        return 0

    print(
        f"Risk: {output['risk']} (Tier {report.tier})\n"
        f"Policy ref: {policy_ref}\n"
        f"Comparison: {base}..{'working tree' if args.working_tree else args.head}\n"
    )
    print(report.to_text())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
