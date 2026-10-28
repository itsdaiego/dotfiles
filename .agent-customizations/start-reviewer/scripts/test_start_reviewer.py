"""Focused behavior tests for start_reviewer."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
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

    def test_fingerprint_ignores_generated_wording(self) -> None:
        first = {
            "file": "service.py",
            "line": 10,
            "title": "[adversarial: correctness] Lost update",
            "detail": "Long explanation one",
            "suggested_comment": "Fix it one way.",
        }
        second = {
            "file": "service.py",
            "line": 10,
            "title": "Lost update",
            "detail": "Different explanation",
            "suggested_comment": "Fix it another way.",
        }
        self.assertEqual(
            reviewer.finding_fingerprint(123, "abc123", first),
            reviewer.finding_fingerprint(123, "abc123", second),
        )

    def test_review_activity_detects_teammate_and_unexpected_own_notes(self) -> None:
        notes = [
            {"system": False, "author": {"username": "teammate"}, "body": "Reviewing"},
        ]
        with patch.object(reviewer, "discussion_notes", return_value=notes):
            self.assertTrue(
                reviewer.review_activity_exists(
                    123,
                    author="author",
                    me="me",
                    team={"teammate"},
                    allowed_my_note_bodies=set(),
                )
            )
        own_notes = [
            {"system": False, "author": {"username": "me"}, "body": "My manual note"},
        ]
        with patch.object(reviewer, "discussion_notes", return_value=own_notes):
            self.assertTrue(
                reviewer.review_activity_exists(
                    123,
                    author="author",
                    me="me",
                    team={"teammate"},
                    allowed_my_note_bodies={"Automated critical note"},
                )
            )

    @patch.object(reviewer, "delete_draft")
    @patch.object(reviewer, "publish_draft")
    @patch.object(reviewer, "existing_drafts", return_value={"Fix it.": 88})
    @patch.object(reviewer, "existing_note_bodies", return_value=set())
    @patch.object(reviewer, "approval_usernames", return_value={"someone_else"})
    @patch.object(reviewer, "still_untouched", side_effect=[True, True, False])
    @patch.object(
        reviewer,
        "live_mr",
        side_effect=[
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
            {"sha": "abc123", "state": "opened", "draft": False, "diff_refs": {}},
            {"sha": "changed", "state": "opened", "draft": False, "diff_refs": {}},
        ],
    )
    def test_preexisting_draft_is_not_deleted_when_state_changes(
        self,
        _live_mr,
        _still_untouched,
        _approvals,
        _existing_notes,
        _existing_drafts,
        publish_draft,
        delete_draft,
    ) -> None:
        result = {
            "head_sha": "abc123",
            "can_approve": False,
            "new_critical": [{"suggested_comment": "Fix it."}],
        }
        reviewer.act_on_result(candidate(), result, "me", {"actions": {}})
        publish_draft.assert_not_called()
        delete_draft.assert_not_called()

    @patch.object(reviewer, "act_on_result")
    @patch.object(reviewer, "load_state", return_value={"actions": {}})
    @patch.object(reviewer, "result_is_current", return_value=True)
    @patch.object(
        reviewer,
        "load_result",
        return_value={"head_sha": "abc123", "can_approve": True, "new_critical": []},
    )
    @patch.object(reviewer, "review", return_value=(123, None))
    @patch.object(reviewer, "refresh_queue")
    def test_cycle_refreshes_queue_once_then_uses_live_action_guards(
        self,
        refresh_queue,
        _review,
        _load_result,
        _result_is_current,
        _load_state,
        act_on_result,
    ) -> None:
        queue = {"me": "me", "team": ["teammate"], "mrs": [candidate()]}
        refresh_queue.return_value = queue
        with tempfile.TemporaryDirectory() as temp_dir:
            with patch.object(reviewer, "WORK_DIR", Path(temp_dir)), patch.object(
                reviewer, "LOCK_FILE", Path(temp_dir) / "cycle.lock"
            ):
                self.assertEqual(reviewer.cycle(), 0)
        self.assertEqual(refresh_queue.call_count, 1)
        act_on_result.assert_called_once()


if __name__ == "__main__":
    unittest.main()
