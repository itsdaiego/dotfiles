"""Tests for the graph-based blast-radius estimate used by the Wall-E risk skill."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import blast_radius  # noqa: E402

PREFIX = "src/app"

# Line numbers matter: the graph below places `status` at line 10, `core` at
# line 20, and `leaf` at line 30.
SERVICE_SOURCE = {
    1: "import os",
    2: "import sys",
    6: '_STATUS_DESC = "Lead status."',
    7: 'HANDLERS = {"open": 1}',
    10: "class Status(str, Enum):",
    11: '    """Lead status."""',
    12: '    OPEN = "open"',
    13: '    CLOSED = "closed"',
    20: "def core(value: str) -> str:",
    21: '    """Describe the value."""',
    22: '    result = Field(description="old text")',
    23: "    return value.upper()",
    30: "def leaf():",
    31: "    return 1",
}


def service_text():
    return "".join(f"{SERVICE_SOURCE.get(i, '')}\n" for i in range(1, 41))


def node(node_id, source_file, line=None, community=0, file_type="code"):
    return {
        "id": node_id,
        "label": node_id,
        "file_type": file_type,
        "source_file": source_file,
        "source_location": f"L{line}" if line is not None else None,
        "community": community,
    }


def edge(source, target, relation="calls"):
    return {"source": source, "target": target, "relation": relation}


def fixture_graph():
    nodes = [
        node("service_file", "svc/service.py"),
        node("status", "svc/service.py", 10, community=1),
        node("core", "svc/service.py", 20, community=1),
        node("leaf", "svc/service.py", 30, community=1),
        node("caller_a", "svc/a.py", 5, community=2),
        node("caller_b", "svc/b.py", 5, community=3),
        node("caller_c", "other/c.py", 5, community=4),
        node("caller_d", "other/d.py", 5, community=4),
        node("core_test", "svc/tests/test_service.py", 3, community=5),
        node("core_doc", "svc/service.py", 21, file_type="rationale"),
    ]
    nodes += [node(f"filler_{i}", f"filler/f{i}.py", 1, community=9) for i in range(40)]
    edges = [
        edge("service_file", "status", "contains"),
        edge("service_file", "core", "contains"),
        edge("service_file", "leaf", "contains"),
        edge("caller_a", "core"),
        edge("caller_b", "core", "references"),
        edge("caller_c", "core", "imports_from"),
        edge("caller_a", "status", "references"),
        edge("caller_b", "status", "references"),
        edge("caller_c", "status", "imports_from"),
        edge("caller_d", "caller_a"),
        edge("core_test", "core"),
        edge("core_doc", "core", "rationale_for"),
    ]
    return {"directed": False, "nodes": nodes, "links": edges}


def git(repo, *args):
    return subprocess.run(
        ["git", "-C", str(repo), *args], check=True, capture_output=True, text=True
    ).stdout.strip()


class BlastRadiusTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.graph_path = root / "graphify-out" / "graph.json"
        self.graph_path.parent.mkdir()
        self.graph_path.write_text(json.dumps(fixture_graph()))
        (root / "graphify-out" / "cost.json").write_text(
            json.dumps({"runs": [{"date": "2026-11-04T18:59:29+00:00"}]})
        )

        self.repo = root / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "test@example.com")
        git(self.repo, "config", "user.name", "Test")
        self.service = self.repo / PREFIX / "svc" / "service.py"
        self.service.parent.mkdir(parents=True)
        self.service.write_text(service_text())
        (self.repo / "README.md").write_text("readme\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-q", "-m", "base")
        git(self.repo, "branch", "base")

    def tearDown(self):
        self.tmp.cleanup()

    def commit_lines(self, replacements=None, insert_after=None):
        """Replace whole lines and/or insert a line after a base line, then commit."""
        lines = self.service.read_text().splitlines()
        for number, text in (replacements or {}).items():
            lines[number - 1] = text
        if insert_after:
            number, text = insert_after
            lines.insert(number, text)
        self.service.write_text("\n".join(lines) + "\n")
        git(self.repo, "commit", "-qam", "change")

    def analyze(self, base="base"):
        return blast_radius.analyze(
            graph_path=self.graph_path,
            repo=self.repo,
            base=base,
            head="HEAD",
            prefix=PREFIX,
        )

    def only_node(self, result):
        [changed] = result["changed_nodes"]
        return changed

    def test_logic_change_in_shared_function_is_hub(self):
        self.commit_lines({23: "    return value.lower()"})

        result = self.analyze()

        changed = self.only_node(result)
        self.assertEqual(changed["id"], "core")
        self.assertEqual(changed["change"], "logic")
        self.assertEqual(changed["direct_prod_dependents"], 3)
        self.assertEqual(changed["transitive_prod_dependents"], 4)
        self.assertEqual(changed["test_dependents"], 1)
        self.assertEqual(changed["communities_reached"], 3)
        self.assertEqual(changed["tier"], "hub")
        self.assertEqual(result["overall"], "hub")

    def test_logic_change_in_leaf_function_is_leaf(self):
        self.commit_lines({31: "    return 2"})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "leaf")
        self.assertEqual(changed["change"], "logic")
        self.assertEqual(changed["transitive_prod_dependents"], 0)
        self.assertEqual(changed["tier"], "leaf")

    def test_added_enum_member_in_hub_is_additive_and_not_a_hub(self):
        self.commit_lines(insert_after=(13, '    PENDING = "pending"'))

        result = self.analyze()

        changed = self.only_node(result)
        self.assertEqual(changed["id"], "status")
        self.assertEqual(changed["change"], "additive")
        self.assertEqual(changed["reach_tier"], "hub")
        self.assertEqual(changed["tier"], "leaf")
        self.assertEqual(result["overall"], "leaf")

    def test_new_module_constant_after_hub_class_is_additive_on_the_module(self):
        self.commit_lines(insert_after=(13, "PENDING_STATUSES = frozenset({Status.OPEN})"))

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "service_file")
        self.assertEqual(changed["change"], "additive")
        self.assertEqual(changed["tier"], "leaf")

    def test_new_method_in_hub_class_is_additive(self):
        self.commit_lines(insert_after=(13, "    def label(self):\n        return self.value.title()"))

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "status")
        self.assertEqual(changed["change"], "additive")
        self.assertEqual(changed["tier"], "leaf")

    def test_reworded_description_constant_is_text(self):
        self.commit_lines({6: '_STATUS_DESC = "Status of the lead."'})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "service_file")
        self.assertEqual(changed["change"], "text")

    def test_new_registry_entry_is_additive(self):
        self.commit_lines({7: 'HANDLERS = {"open": 1, "closed": 2}'})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "service_file")
        self.assertEqual(changed["change"], "additive")

    def test_changed_registry_entry_is_logic(self):
        self.commit_lines({7: 'HANDLERS = {"open": 3}'})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "service_file")
        self.assertEqual(changed["change"], "logic")

    def test_changed_enum_value_in_hub_is_logic(self):
        self.commit_lines({12: '    OPEN = "opened"'})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "status")
        self.assertEqual(changed["change"], "logic")
        self.assertEqual(changed["tier"], "hub")

    def test_docstring_and_description_edits_in_hub_are_text(self):
        self.commit_lines(
            {
                21: '    """Describe the value in more words."""',
                22: '    result = Field(description="new text")',
            }
        )

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "core")
        self.assertEqual(changed["change"], "text")
        self.assertEqual(changed["reach_tier"], "hub")
        self.assertEqual(changed["tier"], "leaf")

    def test_import_block_edit_is_imports(self):
        self.commit_lines({2: "import json"})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["id"], "service_file")
        self.assertEqual(changed["change"], "imports")
        self.assertEqual(changed["tier"], "leaf")

    def test_unparseable_file_counts_as_logic(self):
        self.commit_lines({23: "    return value.upper("})

        changed = self.only_node(self.analyze())

        self.assertEqual(changed["change"], "logic")
        self.assertEqual(changed["tier"], "hub")

    def test_files_outside_graph_make_result_partial(self):
        (self.repo / "README.md").write_text("changed\n")
        git(self.repo, "commit", "-qam", "docs")

        result = self.analyze()

        self.assertEqual(result["changed_nodes"], [])
        self.assertEqual(result["files_outside_graph"], ["README.md"])
        self.assertEqual(result["overall"], "unknown")

    def test_reports_graph_build_time(self):
        self.commit_lines({31: "    return 2"})

        result = self.analyze()

        self.assertEqual(result["graph"]["built_at"], "2026-11-04T18:59:29+00:00")

    def test_logic_change_in_hub_has_high_reach_with_plain_reason(self):
        self.commit_lines({23: "    return value.lower()"})

        result = self.analyze()

        self.assertEqual(result["reach"], "high")
        self.assertEqual(
            result["reason"],
            "Changes logic in core, which 4 functions depend on. 1 test covers it.",
        )

    def test_additive_change_in_hub_has_low_reach_with_plain_reason(self):
        self.commit_lines(insert_after=(13, '    PENDING = "pending"'))

        result = self.analyze()

        self.assertEqual(result["reach"], "low")
        self.assertEqual(
            result["reason"],
            "Only adds names, text, or imports to code that 4 functions depend on. "
            "Nothing that depends on it can break.",
        )

    def test_logic_change_in_leaf_has_low_reach(self):
        self.commit_lines({31: "    return 2"})

        result = self.analyze()

        self.assertEqual(result["reach"], "low")
        self.assertEqual(result["reason"], "Logic changes reach at most 0 other functions.")

    def test_unmapped_diff_has_unknown_reach(self):
        (self.repo / "README.md").write_text("changed\n")
        git(self.repo, "commit", "-qam", "docs")

        result = self.analyze()

        self.assertEqual(result["reach"], "unknown")
        self.assertEqual(result["reason"], "No changed file is in the code graph.")
        first_line = blast_radius.render_text(result, limit=5).splitlines()[0]
        self.assertEqual(first_line, "Blast radius: unknown. No changed file is in the code graph.")

    def test_shared_tier_maps_to_medium_reach(self):
        self.assertEqual(blast_radius.REACH_FOR_TIER, {"hub": "high", "shared": "medium", "leaf": "low"})

    def test_reports_sensitive_paths_changed_lines_and_exact_revisions(self):
        (self.repo / ".gitlab-ci.yml").write_text("stages: [test]\n")
        migration = self.repo / PREFIX / "db" / "alembic" / "versions" / "0001_add.py"
        migration.parent.mkdir(parents=True)
        migration.write_text("revision = '1'\ndown_revision = None\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "ci and migration")
        self.commit_lines({31: "    return 2"})

        result = self.analyze()

        self.assertEqual(
            result["sensitive_paths"],
            [
                {"path": ".gitlab-ci.yml", "area": "CI pipeline"},
                {"path": f"{PREFIX}/db/alembic/versions/0001_add.py", "area": "database migration"},
            ],
        )
        self.assertEqual(result["changed_lines"], 5)  # 1 + 2 new lines, 1 replaced line
        self.assertEqual(result["revisions"]["head"], git(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(result["revisions"]["merge_base"], git(self.repo, "rev-parse", "base"))

    def test_text_report_leads_with_reach_and_reason(self):
        self.commit_lines({23: "    return value.lower()"})

        text = blast_radius.render_text(self.analyze(), limit=5)

        self.assertTrue(
            text.startswith(
                "Blast radius: high. Changes logic in core, which 4 functions depend on. 1 test covers it."
            ),
            text,
        )

    def test_built_from_sha_counts_target_commits_in_scope_since_build(self):
        built_from = git(self.repo, "rev-parse", "base")
        (self.graph_path.parent.parent / "BUILT_FROM").write_text(built_from + "\n")
        self.commit_lines({5: "# in scope"})
        (self.repo / "README.md").write_text("outside scope\n")
        git(self.repo, "commit", "-qam", "outside scope")
        git(self.repo, "branch", "-f", "target")
        self.commit_lines({31: "    return 2"})

        result = self.analyze(base="target")

        self.assertEqual(result["graph"]["built_from"], built_from)
        self.assertEqual(result["graph"]["target_commits_since_build"], 1)


if __name__ == "__main__":
    unittest.main()
