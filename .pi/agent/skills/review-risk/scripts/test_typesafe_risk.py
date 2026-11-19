"""Tests for the TypeSafe Jev review-risk classifier."""

import io
import json
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import typesafe_risk  # noqa: E402


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return json.dumps(self.payload).encode()


class TypeSafeRiskTest(unittest.TestCase):
    def test_environment_key_takes_priority(self):
        with mock.patch.dict(os.environ, {"TYPESAFE_API_KEY": "from-env"}, clear=True):
            with mock.patch.object(typesafe_risk.subprocess, "run") as run:
                self.assertEqual(typesafe_risk.load_api_key(), "from-env")

        run.assert_not_called()

    def test_zshrc_key_is_loaded_when_environment_is_empty(self):
        completed = mock.Mock(returncode=0, stdout="from-zshrc", stderr="")
        with mock.patch.dict(os.environ, {}, clear=True):
            with mock.patch.object(typesafe_risk.subprocess, "run", return_value=completed) as run:
                self.assertEqual(typesafe_risk.load_api_key(), "from-zshrc")

        self.assertIn("source ~/.zshrc", run.call_args.args[0][-1])

    def test_classifier_posts_policy_evidence_without_exposing_the_key(self):
        evidence = {
            "head_sha": "abc123",
            "target_branch": "master",
            "summary": "Documentation-only change",
            "changed_paths": ["docs/review.md"],
            "tests": "docs checks pass",
        }
        response = {
            "answers": {
                "risk": {
                    "type": "choice",
                    "choice": "low",
                    "probabilities": {"low": 0.91, "medium": 0.07, "high": 0.02},
                    "confidence": 0.91,
                }
            },
            "usage": {"input_tokens": 100, "output_tokens": 10},
        }
        captured = {}

        def urlopen(request, timeout):
            captured["url"] = request.full_url
            captured["headers"] = dict(request.header_items())
            captured["body"] = json.loads(request.data)
            captured["timeout"] = timeout
            return FakeResponse(response)

        with mock.patch.object(typesafe_risk.urllib.request, "urlopen", side_effect=urlopen):
            result = typesafe_risk.classify(evidence, api_key="secret-value")

        self.assertEqual(captured["url"], "https://api.typesafe.ai/v1/systemone")
        self.assertEqual(captured["headers"]["Authorization"], "Bearer secret-value")
        self.assertEqual(captured["body"]["model"], "jev-latest")
        self.assertEqual(captured["body"]["state"]["review"], evidence)
        self.assertEqual(
            set(captured["body"]["questions"]["risk"]["criteria"]),
            {"low", "medium", "high"},
        )
        self.assertTrue(result["available"])
        self.assertEqual(result["risk"], "low")
        self.assertNotIn("secret-value", json.dumps(result))

    def test_authentication_failure_returns_unavailable_result(self):
        error = typesafe_risk.urllib.error.HTTPError(
            "https://api.typesafe.ai/v1/systemone",
            401,
            "Unauthorized",
            {},
            io.BytesIO(b'{"detail":"bad key"}'),
        )
        with mock.patch.object(typesafe_risk.urllib.request, "urlopen", side_effect=error):
            result = typesafe_risk.classify({"summary": "change"}, api_key="bad-secret")

        self.assertFalse(result["available"])
        self.assertEqual(result["status"], 401)
        self.assertIn("authentication failed", result["reason"].lower())
        self.assertNotIn("bad-secret", json.dumps(result))


if __name__ == "__main__":
    unittest.main()
