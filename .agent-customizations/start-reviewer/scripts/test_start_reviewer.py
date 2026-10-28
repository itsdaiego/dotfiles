"""Focused behavior tests for start_reviewer."""

from __future__ import annotations

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("start_reviewer.py")
SPEC = importlib.util.spec_from_file_location("start_reviewer", MODULE_PATH)
assert SPEC and SPEC.loader
reviewer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reviewer)


def candidate() -> dict[str, object]:
    return {
        "iid": 123,
        "sha": "abc123",
        "sources": ["reviewer", "team"],
        "draft": False,
        "approved_by_me": False,
        "nobody_started": True,
        "needs_review": True,
    }


class StartReviewerTests(unittest.TestCase):
    def test_candidate_requires_assigned_untouched_mr(self) -> None:
        self.assertTrue(reviewer.is_candidate(candidate()))
        for field in ("draft", "approved_by_me"):
            changed = candidate()
            changed[field] = True
            self.assertFalse(reviewer.is_candidate(changed))
        changed = candidate()
        changed["nobody_started"] = False
        self.assertFalse(reviewer.is_candidate(changed))

    @patch.object(reviewer, "approval_usernames", return_value=set())
    def test_live_state_requires_current_reviewer_assignment(self, _approvals) -> None:
        live = {
            "state": "opened",
            "draft": False,
            "reviewers": [{"username": "me"}],
        }
        self.assertTrue(reviewer.still_untouched(candidate(), live, "me"))
        live["reviewers"] = [{"username": "someone_else"}]
        self.assertFalse(reviewer.still_untouched(candidate(), live, "me"))

    @patch.object(reviewer, "approval_usernames", return_value={"someone_else"})
    def test_live_state_stops_after_any_approval(self, _approvals) -> None:
        live = {
            "state": "opened",
            "draft": False,
            "reviewers": [{"username": "me"}],
        }
        self.assertFalse(reviewer.still_untouched(candidate(), live, "me"))

    @patch.object(reviewer, "save_state")
    @patch.object(reviewer, "run_command")
    @patch.object(reviewer, "still_untouched", return_value=True)
    @patch.object(reviewer, "live_mr", return_value={"sha": "abc123", "state": "opened", "draft": False})
    def test_clean_result_approves_exact_head(
        self,
        _live_mr,
        _still_untouched,
        run_command,
        _save_state,
    ) -> None:
        run_command.return_value = subprocess.CompletedProcess([], 0, "ok", "")
        state = {"actions": {}}
        reviewer.act_on_result(candidate(), {"head_sha": "abc123", "can_approve": True, "new_critical": []}, "me", state)
        run_command.assert_called_once_with(
            ["glab", "mr", "approve", "123", "--sha", "abc123"],
            check=False,
        )

    @patch.object(reviewer, "save_state")
    @patch.object(reviewer, "publish_draft")
    @patch.object(reviewer, "create_draft", return_value=77)
    @patch.object(reviewer, "existing_drafts", return_value={})
    @patch.object(reviewer, "existing_note_bodies", return_value=set())
    @patch.object(reviewer, "approval_usernames", return_value=set())
    @patch.object(reviewer, "still_untouched", return_value=True)
    @patch.object(
        reviewer,
        "live_mr",
        side_effect=[
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
        ],
    )
    def test_only_new_critical_is_published(
        self,
        _live_mr,
        _still_untouched,
        _approvals,
        _existing_notes,
        _existing_drafts,
        create_draft,
        publish_draft,
        _save_state,
    ) -> None:
        result = {
            "head_sha": "abc123",
            "can_approve": False,
            "new_critical": [{"file": "a.py", "line": 3, "suggested_comment": "Fix the data loss."}],
            "suggestion_count": 9,
            "nit_count": 12,
        }
        reviewer.act_on_result(candidate(), result, "me", {"actions": {}})
        create_draft.assert_called_once()
        publish_draft.assert_called_once_with(123, 77)

    @patch.object(reviewer, "save_state")
    @patch.object(reviewer, "publish_draft")
    @patch.object(reviewer, "create_draft")
    @patch.object(reviewer, "existing_drafts", return_value={"Fix it.": 88})
    @patch.object(reviewer, "existing_note_bodies", return_value=set())
    @patch.object(reviewer, "approval_usernames", return_value=set())
    @patch.object(reviewer, "still_untouched", return_value=True)
    @patch.object(
        reviewer,
        "live_mr",
        side_effect=[
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
        ],
    )
    def test_matching_existing_draft_is_reused(
        self,
        _live_mr,
        _still_untouched,
        _approvals,
        _existing_notes,
        _existing_drafts,
        create_draft,
        publish_draft,
        _save_state,
    ) -> None:
        result = {
            "head_sha": "abc123",
            "can_approve": False,
            "new_critical": [{"suggested_comment": "Fix it."}],
        }
        reviewer.act_on_result(candidate(), result, "me", {"actions": {}})
        create_draft.assert_not_called()
        publish_draft.assert_called_once_with(123, 88)


if __name__ == "__main__":
    unittest.main()
