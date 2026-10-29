import io
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import user_prompt_hook


class UserPromptHookTest(unittest.TestCase):
    def run_hook(self, agent_payload, env=None):
        get_completed = subprocess.CompletedProcess(
            args=["herdr", "agent", "get", "w1:p1"],
            returncode=0,
            stdout=json.dumps(agent_payload),
            stderr="",
        )
        rename_completed = subprocess.CompletedProcess(
            args=["herdr", "tab", "rename", "w1:t1", "codex"],
            returncode=0,
            stdout="{}",
            stderr="",
        )
        output = io.StringIO()
        hook_input = io.StringIO(json.dumps({"hook_event_name": "UserPromptSubmit"}))
        hook_env = {
            "HERDR_ENV": "1",
            "HERDR_PANE_ID": "w1:p1",
            "HERDR_TAB_ID": "w1:t1",
            **(env or {}),
        }

        with (
            patch.dict(os.environ, hook_env, clear=True),
            patch("sys.stdin", hook_input),
            patch("sys.stdout", output),
            patch(
                "subprocess.run",
                side_effect=[get_completed, rename_completed],
            ) as run,
        ):
            user_prompt_hook.main()

        return output.getvalue(), run.call_args_list

    def test_injects_rename_instruction_when_agent_has_no_name(self):
        output, calls = self.run_hook({"result": {"agent": {"agent": "codex"}}})

        payload = json.loads(output)
        context = payload["hookSpecificOutput"]["additionalContext"]
        self.assertEqual(
            payload["hookSpecificOutput"]["hookEventName"],
            "UserPromptSubmit",
        )
        self.assertIn("infer a concise task description", context)
        self.assertIn('herdr agent rename "w1:p1"', context)
        self.assertIn("lower description line", context)
        self.assertIn("workspace/project", context)
        self.assertIn("harness", context)
        self.assertEqual(
            calls[1].args[0],
            ["herdr", "tab", "rename", "w1:t1", "codex"],
        )

    def test_emits_nothing_when_agent_already_has_a_name(self):
        output, calls = self.run_hook(
            {"result": {"agent": {"agent": "codex", "name": "update-dotfiles"}}}
        )

        self.assertEqual(output, "")
        self.assertEqual(
            calls[1].args[0],
            ["herdr", "tab", "rename", "w1:t1", "codex"],
        )

    def test_emits_nothing_outside_herdr(self):
        output = io.StringIO()

        with (
            patch.dict(os.environ, {}, clear=True),
            patch("sys.stdin", io.StringIO("{}")),
            patch("sys.stdout", output),
        ):
            user_prompt_hook.main()

        self.assertEqual(output.getvalue(), "")

    def test_injects_live_pane_when_inherited_pane_id_is_stale(self):
        stale_get = subprocess.CompletedProcess(
            args=["herdr", "agent", "get", "w1:p1"],
            returncode=1,
            stdout="",
            stderr="agent target w1:p1 not found",
        )
        agent_list = subprocess.CompletedProcess(
            args=["herdr", "agent", "list"],
            returncode=0,
            stdout=json.dumps(
                {
                    "result": {
                        "agents": [
                            {
                                "agent": "codex",
                                "focused": True,
                                "name": None,
                                "pane_id": "w1:p2",
                                "tab_id": "w1:t2",
                                "workspace_id": "w1",
                            }
                        ]
                    }
                }
            ),
            stderr="",
        )
        tab_rename = subprocess.CompletedProcess(
            args=["herdr", "tab", "rename", "w1:t2", "codex"],
            returncode=0,
            stdout="{}",
            stderr="",
        )
        output = io.StringIO()

        with (
            patch.dict(
                os.environ,
                {
                    "HERDR_ENV": "1",
                    "HERDR_PANE_ID": "w1:p1",
                    "HERDR_TAB_ID": "w1:t1",
                    "HERDR_WORKSPACE_ID": "w1",
                },
                clear=True,
            ),
            patch("sys.stdin", io.StringIO("{}")),
            patch("sys.stdout", output),
            patch(
                "subprocess.run",
                side_effect=[stale_get, agent_list, tab_rename],
            ) as run,
        ):
            user_prompt_hook.main()

        context = json.loads(output.getvalue())["hookSpecificOutput"][
            "additionalContext"
        ]
        self.assertIn('herdr agent rename "w1:p2"', context)
        self.assertEqual(
            run.call_args_list[2].args[0],
            ["herdr", "tab", "rename", "w1:t2", "codex"],
        )

    def test_injects_focused_pane_when_inherited_workspace_is_stale(self):
        stale_get = subprocess.CompletedProcess(
            args=["herdr", "agent", "get", "w1:p1"],
            returncode=1,
            stdout="",
            stderr="agent target w1:p1 not found",
        )
        agent_list = subprocess.CompletedProcess(
            args=["herdr", "agent", "list"],
            returncode=0,
            stdout=json.dumps(
                {
                    "result": {
                        "agents": [
                            {
                                "agent": "codex",
                                "focused": True,
                                "name": None,
                                "pane_id": "w2:p2",
                                "tab_id": "w2:t2",
                                "workspace_id": "w2",
                            }
                        ]
                    }
                }
            ),
            stderr="",
        )
        tab_rename = subprocess.CompletedProcess(
            args=["herdr", "tab", "rename", "w2:t2", "codex"],
            returncode=0,
            stdout="{}",
            stderr="",
        )
        output = io.StringIO()

        with (
            patch.dict(
                os.environ,
                {
                    "HERDR_ENV": "1",
                    "HERDR_PANE_ID": "w1:p1",
                    "HERDR_TAB_ID": "w1:t1",
                    "HERDR_WORKSPACE_ID": "w1",
                },
                clear=True,
            ),
            patch("sys.stdin", io.StringIO("{}")),
            patch("sys.stdout", output),
            patch(
                "subprocess.run",
                side_effect=[stale_get, agent_list, tab_rename],
            ) as run,
        ):
            user_prompt_hook.main()

        context = json.loads(output.getvalue())["hookSpecificOutput"][
            "additionalContext"
        ]
        self.assertIn('herdr agent rename "w2:p2"', context)
        self.assertEqual(
            run.call_args_list[2].args[0],
            ["herdr", "tab", "rename", "w2:t2", "codex"],
        )


if __name__ == "__main__":
    unittest.main()
