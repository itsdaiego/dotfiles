import importlib.util
import io
import subprocess
import unittest
from pathlib import Path
from unittest.mock import call, patch


SCRIPT = Path(__file__).resolve().parents[1] / "large-picker.py"
spec = importlib.util.spec_from_file_location("large_picker", SCRIPT)
large_picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(large_picker)


class LargePickerTest(unittest.TestCase):
    def setUp(self):
        self.sessions = {
            "sessions": [
                {
                    "session_id": "session:1",
                    "label": "rex-sidebar-session-naming",
                }
            ]
        }
        self.block_methods = []
        self.view = {
            "windows": [
                {
                    "window_id": "window:1",
                    "label": "Editor",
                    "layers": [
                        {
                            "blocks": [
                                {
                                    "block_id": "block:1",
                                    "label": "shell",
                                },
                                {
                                    "block_id": "block:2",
                                    "label": "shell",
                                },
                                {
                                    "block_id": "block:3",
                                    "label": "shell",
                                },
                            ]
                        }
                    ],
                }
            ]
        }

    def fake_run_json(self, command):
        if command[1:3] == ["ls", "--json"]:
            return self.sessions
        if command[1:3] == ["session", "inspect"]:
            return self.view

        block_id = command[command.index("-b") + 1]
        method = command[-1]
        self.block_methods.append(method)
        if block_id == "block:1" and method == "process":
            return {
                "foreground": {
                    "name": "node",
                    "argv0": "pi",
                    "cwd": "/Users/daiego/Documents/code-stuff/eve",
                }
            }
        if block_id == "block:1" and method == "program_status":
            return {"records": [{"effective_app": "pi", "state": "working"}]}
        if block_id == "block:1" and method == "title":
            return {"title": "π - daiego"}
        if block_id == "block:2" and method == "process":
            return {
                "foreground": {
                    "name": "nvim",
                    "argv0": "nvim",
                    "cwd": "/Users/daiego/Documents/code-stuff/eve",
                }
            }
        if block_id == "block:2" and method == "program_status":
            return {"records": []}
        if block_id == "block:2" and method == "title":
            return {"title": "Neovim"}
        if block_id == "block:3" and method == "process":
            return {"child": {"name": "login"}}
        if block_id == "block:3" and method == "program_status":
            return {"records": []}
        if block_id == "block:3" and method == "title":
            return {"title": "large-picker.py"}
        raise AssertionError(command)

    def test_program_picker_names_the_program_session_and_current_pane(self):
        with (
            patch.dict(large_picker.os.environ, {"REX_BLOCK": "block:3"}, clear=False),
            patch.object(large_picker, "run_json", side_effect=self.fake_run_json),
        ):
            records = large_picker.block_records("rex")

        self.assertEqual(len(records), 2)
        self.assertEqual(
            records[0][0],
            "Pi  ·  rex-sidebar-session-naming  ›  Editor  ›  ~/Documents/code-stuff/eve",
        )
        self.assertEqual(
            records[1][0],
            "Neovim  ·  rex-sidebar-session-naming  ›  Editor  ›  ~/Documents/code-stuff/eve",
        )

    def test_picker_fetches_only_process_metadata_for_each_pane(self):
        with (
            patch.dict(large_picker.os.environ, {"REX_BLOCK": "block:3"}, clear=False),
            patch.object(large_picker, "run_json", side_effect=self.fake_run_json),
        ):
            large_picker.block_records("rex")

        self.assertEqual(self.block_methods, ["process", "process"])

    def test_precomputed_snapshot_needs_no_rex_queries(self):
        snapshot = [
            {
                "session_id": "session:1",
                "session_label": "eve",
                "window_id": "window:1",
                "window_label": "Editor",
                "block_id": "block:1",
                "block_label": "review-api",
                "process": {
                    "foreground": {
                        "argv0": "pi",
                        "cwd": "/Users/daiego/Documents/code-stuff/eve",
                    }
                },
            }
        ]

        with patch.object(large_picker, "run_json") as run_json:
            records = large_picker.records_from_snapshot(snapshot, agents_only=False)

        run_json.assert_not_called()
        self.assertEqual(
            records[0][0],
            "Pi  ·  eve  ›  review-api  ›  ~/Documents/code-stuff/eve",
        )

    def test_program_picker_hides_generated_window_ids(self):
        self.view["windows"][0]["label"] = "Window 12345678"
        with (
            patch.dict(large_picker.os.environ, {"REX_BLOCK": "block:3"}, clear=False),
            patch.object(large_picker, "run_json", side_effect=self.fake_run_json),
        ):
            records = large_picker.block_records("rex")

        self.assertNotIn("Window 12345678", records[0][0])
        self.assertIn("~/Documents/code-stuff/eve", records[0][0])

    def test_agent_picker_includes_agent_and_rex_session_name(self):
        with (
            patch.dict(large_picker.os.environ, {"REX_BLOCK": "block:3"}, clear=False),
            patch.object(large_picker, "run_json", side_effect=self.fake_run_json),
        ):
            records = large_picker.agent_records("rex")

        self.assertEqual(len(records), 1)
        self.assertEqual(
            records[0][0],
            "Pi  ·  rex-sidebar-session-naming  ›  Editor  ›  ~/Documents/code-stuff/eve",
        )

    def test_open_choice_reports_client_action_failure(self):
        failed = subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr=(
                "Rex.app is not accepting actions. Turn on Remote Control in its "
                "Settings under Rex Server."
            ),
        )

        output = io.StringIO()
        with (
            patch.object(large_picker.subprocess, "run", return_value=failed),
            patch.object(large_picker.sys, "stderr", output),
            patch("builtins.input", return_value="") as wait_for_enter,
        ):
            opened = large_picker.open_choice(
                "rex",
                "client:remote",
                "sessions",
                ("eve", "session:1"),
            )

        self.assertFalse(opened)
        self.assertIn("Turn on Remote Control", output.getvalue())
        wait_for_enter.assert_called_once_with()

    def test_open_choice_focuses_block_then_selects_its_window(self):
        succeeded = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )

        with patch.object(
            large_picker.subprocess, "run", return_value=succeeded
        ) as run:
            opened = large_picker.open_choice(
                "rex",
                "client:remote",
                "agents",
                ("Pi · eve", "session:1", "window:1", "block:1", "0"),
            )

        self.assertTrue(opened)
        self.assertEqual(
            run.call_args_list,
            [
                call(
                    ["rex", "focus", "-s", "session:1", "block:1"],
                    capture_output=True,
                    text=True,
                ),
                call(
                    [
                        "rex",
                        "-C",
                        "client:remote",
                        "do",
                        "session.select",
                        "session_id=session:1",
                        "window_id=window:1",
                    ],
                    capture_output=True,
                    text=True,
                ),
            ],
        )

    def test_open_choice_restores_zoom_after_focusing_block(self):
        succeeded = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )

        with patch.object(
            large_picker.subprocess, "run", return_value=succeeded
        ) as run:
            opened = large_picker.open_choice(
                "rex",
                "client:remote",
                "agents",
                ("Pi · eve", "session:1", "window:1", "block:1", "1"),
            )

        self.assertTrue(opened)
        self.assertEqual(
            run.call_args_list[1],
            call(
                ["rex", "zoom", "-s", "session:1", "block:1", "--on"],
                capture_output=True,
                text=True,
            ),
        )


if __name__ == "__main__":
    unittest.main()
