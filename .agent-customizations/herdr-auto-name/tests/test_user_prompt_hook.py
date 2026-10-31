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
        self.assertIn('herdr agent rename "$HERDR_PANE_ID"', context)
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


if __name__ == "__main__":
    unittest.main()
