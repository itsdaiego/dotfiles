#!/usr/bin/env python3
"""Classify Butler review risk with TypeSafe Jev.

The input is one JSON object containing the exact-head evidence gathered by the
review-risk skill. The API key is read from TYPESAFE_API_KEY or, when a
background review process did not inherit the shell environment, from ~/.zshrc
through a fresh zsh process. The key is never printed.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

API_URL = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"
TIMEOUT_SECONDS = 60
POLICY_VERSION = "Wall-E agent policy v6"

RISK_CRITERIA = {
    "low": (
        "Localized product fixes or isolated behavior with focused verification; localized "
        "self-service configuration; tests, documentation, copy, local tooling, internal-only "
        "features, presentation-only changes, verified mechanical refactors, compatible internal "
        "additions, or logic fully behind a feature flag that defaults off."
    ),
    "medium": (
        "Product or business behavior with meaningful shared reach; shared account or integration "
        "configuration; background jobs or alerts; provider handling; data selection or persistence; "
        "infrastructure; compatibility-changing generated contracts; prompts, caching, Celery work, "
        "integration sync, or a realistic main failure mode without focused test coverage."
    ),
    "high": (
        "Authentication or authorization boundaries; secret storage, transmission, redaction, or "
        "access; payments; destructive data operations; database migrations; tenant isolation; "
        "public API compatibility breaks; deployment controls; an always-human path; or an unbounded "
        "change without credible verification."
    ),
}


def load_zshrc_api_key():
    """Load the key from a fresh shell without exposing it in process arguments."""
    command = [
        "zsh",
        "-fc",
        'source ~/.zshrc >/dev/null 2>&1; print -rn -- "${TYPESAFE_API_KEY-}"',
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def load_api_key():
    """Return the TypeSafe key without exposing it in command arguments or output."""
    return os.environ.get("TYPESAFE_API_KEY", "").strip() or load_zshrc_api_key()


def build_payload(evidence):
    return {
        "model": MODEL,
        "state": {
            "policy_version": POLICY_VERSION,
            "review": evidence,
        },
        "questions": {
            "risk": {
                "type": "choice",
                "instructions": (
                    "Classify the exact change as low, medium, or high review risk. Use the highest "
                    "applicable consequence and the supplied diff, tests, pipeline, discussion, size, "
                    "feature-flag, compatibility, and blast-radius evidence. An always-human path is "
                    "high. More than 1,000 semantic changed lines raises risk one level. High blast "
                    "radius raises risk one level; medium blast radius raises a low shared-logic change "
                    "to medium. Do not infer risk from filenames alone outside always-human paths."
                ),
                "criteria": RISK_CRITERIA,
            }
        },
    }


def unavailable(reason, status=None):
    result = {
        "available": False,
        "provider": "typesafe",
        "model": MODEL,
        "reason": reason,
    }
    if status is not None:
        result["status"] = status
    return result


def classify(evidence, api_key=None):
    """Return a sanitized TypeSafe classification result for one exact-head review."""
    if api_key is not None:
        keys = [api_key.strip()]
    else:
        keys = [os.environ.get("TYPESAFE_API_KEY", "").strip(), load_zshrc_api_key()]
    keys = list(dict.fromkeys(key for key in keys if key))
    if not keys:
        return unavailable("TYPESAFE_API_KEY is unavailable in the environment and ~/.zshrc.")

    body = None
    for key in keys:
        request = urllib.request.Request(
            API_URL,
            data=json.dumps(build_payload(evidence), separators=(",", ":")).encode(),
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                body = json.loads(response.read())
            break
        except urllib.error.HTTPError as error:
            if error.code in (401, 403):
                continue
            return unavailable(f"TypeSafe returned HTTP {error.code}.", error.code)
        except urllib.error.URLError as error:
            return unavailable(f"TypeSafe request failed: {error.reason}")
        except (TimeoutError, json.JSONDecodeError) as error:
            return unavailable(f"TypeSafe returned no usable classification: {error}")
    if body is None:
        return unavailable("TypeSafe authentication failed; refresh TYPESAFE_API_KEY.", 401)

    answer = body.get("answers", {}).get("risk", {}) if isinstance(body, dict) else {}
    risk = answer.get("choice") if isinstance(answer, dict) else None
    if risk not in RISK_CRITERIA:
        return unavailable("TypeSafe returned an invalid risk answer.")

    return {
        "available": True,
        "provider": "typesafe",
        "model": MODEL,
        "policy_version": POLICY_VERSION,
        "risk": risk,
        "confidence": answer.get("confidence"),
        "probabilities": answer.get("probabilities", {}),
        "usage": body.get("usage"),
    }


def read_evidence(path):
    if path == "-":
        return json.load(sys.stdin)
    with open(path) as source:
        return json.load(source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", default="-", help="Evidence JSON file, or - for stdin")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    try:
        evidence = read_evidence(args.input)
    except (OSError, json.JSONDecodeError) as error:
        parser.error(f"could not read evidence JSON: {error}")
    if not isinstance(evidence, dict):
        parser.error("evidence JSON must be an object")

    json.dump(classify(evidence), sys.stdout, indent=2 if args.pretty else None, sort_keys=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
