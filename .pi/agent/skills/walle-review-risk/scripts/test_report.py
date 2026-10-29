"""Regression tests for the local Wall-E risk wrapper."""

import importlib.util
import unittest
from pathlib import Path


REPORT_PATH = Path(__file__).with_name("report.py")


def load_report_module():
    spec = importlib.util.spec_from_file_location("walle_risk_report", REPORT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReportImportTest(unittest.TestCase):
    def test_wrapper_is_self_contained(self):
        """The wrapper must not import a classifier from the caller's checkout."""
        load_report_module()

    def test_authoritative_tier_is_rendered_for_people(self):
        module = load_report_module()
        self.assertEqual(module.risk_from_report("Tier: A\n"), "low")
        self.assertEqual(module.risk_from_report("Tier: B\n"), "medium")
        self.assertEqual(module.risk_from_report("Tier: C\n"), "high")
        self.assertIsNone(module.risk_from_report("no tier"))


if __name__ == "__main__":
    unittest.main()
