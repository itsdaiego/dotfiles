import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import set_harness_tab_label


class SetHarnessTabLabelTest(unittest.TestCase):
    def test_renames_the_current_herdr_tab_with_the_known_harness(self):
        completed = subprocess.CompletedProcess(
            args=["herdr", "tab", "rename", "w1:t1", "pi"],
            returncode=0,
            stdout="{}",
            stderr="",
        )

        with (
            patch.dict(
                os.environ,
                {"HERDR_ENV": "1", "HERDR_TAB_ID": "w1:t1"},
                clear=True,
            ),
            patch("subprocess.run", return_value=completed) as run,
        ):
            set_harness_tab_label.main(["pi"])

        run.assert_called_once_with(
            ["herdr", "tab", "rename", "w1:t1", "pi"],
            capture_output=True,
            check=False,
            text=True,
            timeout=1,
        )

    def test_does_not_rename_outside_herdr(self):
        with patch.dict(os.environ, {}, clear=True), patch("subprocess.run") as run:
            set_harness_tab_label.main(["claude"])

        run.assert_not_called()

    def test_rejects_unknown_harnesses(self):
        with self.assertRaises(SystemExit):
            set_harness_tab_label.main(["unknown"])


if __name__ == "__main__":
    unittest.main()
