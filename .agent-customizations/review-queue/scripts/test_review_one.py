"""Tests for review-queue result normalization."""

import json
import tempfile
import unittest
from pathlib import Path

import review_one


class ReviewRiskResultTest(unittest.TestCase):
    def normalize(self, review):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "result.json"
            path.write_text(json.dumps(review))
            review_one.attach_review_risk(path)
            return json.loads(path.read_text())

    def test_preserves_valid_review_risk(self):
        review = {
            "review_risk": {
                "available": True,
                "risk": "low",
                "reason": "Localized presentation change.",
            }
        }

        self.assertEqual(self.normalize(review), review)

    def test_marks_missing_review_risk_unavailable(self):
        result = self.normalize({"iid": 123})

        self.assertFalse(result["review_risk"]["available"])
        self.assertIn("did not return", result["review_risk"]["reason"])

    def test_rejects_invalid_risk_level(self):
        result = self.normalize(
            {"review_risk": {"available": True, "risk": "critical"}}
        )

        self.assertFalse(result["review_risk"]["available"])
        self.assertIn("invalid risk level", result["review_risk"]["reason"])


if __name__ == "__main__":
    unittest.main()
