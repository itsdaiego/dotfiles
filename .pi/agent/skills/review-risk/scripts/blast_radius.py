#!/usr/bin/env python3
"""Estimate how far a diff reaches through a graphify code graph.

The graph must be built from the target branch, because the diff's old-side
line numbers are matched to the graph's node start lines. A changed node's
blast radius is the set of production code nodes that call, import, reference,
inherit from, or otherwise depend on it, directly or through a short chain.
Test dependents are counted separately because they indicate coverage, not
reach.

The tier compares a node's transitive production dependents with every other
code node in the same graph, so the thresholds adapt to the graph's size.
"""

from __future__ import annotations

import argparse
import ast
import bisect
import copy
import json
import re
import subprocess
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, NamedTuple

DEPENDENCY_RELATIONS = {
    "calls",
    "indirect_call",
    "references",
    "imports",
    "imports_from",
    "uses",
    "inherits",
    "implements",
}
TIER_ORDER = ["leaf", "shared", "hub"]
HUB_PERCENTILE = 95.0
HUB_MIN_DEPENDENTS = 3
SHARED_PERCENTILE = 80.0
SHARED_MIN_DEPENDENTS = 2
REACH_FOR_TIER = {"hub": "high", "shared": "medium", "leaf": "low"}

# Paths that always need a person, whatever the rest of the assessment says.
# Patterns match repository-relative paths. Keep this list owned by Wall-E.
SENSITIVE_PATHS = [
    ("CI pipeline", re.compile(r"(^|/)\.gitlab-ci\.yml$|^\.gitlab/|(^|/)CODEOWNERS$")),
    ("infrastructure", re.compile(r"^devops/|(^|/)Dockerfile[^/]*$")),
    ("database migration", re.compile(r"(^|/)alembic/")),
    (
        "auth",
        re.compile(r"^src/document_extractor/services/llm_service/common/auth/|^src/js/web_client/src/auth/"),
    ),
    (
        "billing",
        re.compile(r"^src/document_extractor/services/llm_service/(billing|cp_billing|cp_claim_payment)/"),
    ),
]
# A change only counts toward the hub tier when it is "logic". The other kinds
# cannot break code that already depends on the changed node.
CHANGE_ORDER = ["text", "imports", "additive", "logic"]
TEXT_KEYWORDS = {"description", "title", "help", "help_text", "summary", "example", "examples", "label", "message", "msg"}
# A string constant whose name says it is human-readable text. Prompts are left
# out on purpose, because a prompt change changes what an LLM does.
TEXT_NAME = re.compile(r"(?i)(desc|description|help|doc|message|msg|title|summary|label|example)s?$")
DEF_TYPES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
HUNK_HEADER = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
LINE_NUMBER = re.compile(r"(\d+)\s*$")


def is_test_path(path: str) -> bool:
    parts = path.split("/")
    name = parts[-1]
    return (
        any(part in {"test", "tests"} for part in parts[:-1])
        or name.startswith("test_")
        or name.endswith("_test.py")
        or name == "conftest.py"
    )


def start_line(location: str | None) -> int | None:
    match = LINE_NUMBER.search(location or "")
    return int(match.group(1)) if match else None


class CodeGraph:
    def __init__(self, data: dict):
        self.nodes = {
            n["id"]: n for n in data["nodes"] if n.get("file_type") == "code"
        }
        self.dependents: dict[str, set[str]] = defaultdict(set)
        for link in data.get("links") or data.get("edges") or []:
            source, target = link["source"], link["target"]
            if (
                link.get("relation") in DEPENDENCY_RELATIONS
                and source in self.nodes
                and target in self.nodes
                and source != target
            ):
                self.dependents[target].add(source)

        self.lined_by_file: dict[str, list[tuple[int, str]]] = defaultdict(list)
        self.unlined_by_file: dict[str, list[str]] = defaultdict(list)
        for node_id, n in self.nodes.items():
            line = start_line(n.get("source_location"))
            if line is None:
                self.unlined_by_file[n["source_file"]].append(node_id)
            else:
                self.lined_by_file[n["source_file"]].append((line, node_id))
        for entries in self.lined_by_file.values():
            entries.sort()

    def has_file(self, path: str) -> bool:
        return path in self.lined_by_file or path in self.unlined_by_file

    def nodes_for_range(self, path: str, first: int, last: int) -> set[str]:
        """Return the node enclosing ``first`` plus nodes starting in the range."""
        entries = self.lined_by_file.get(path, [])
        starts = [line for line, _ in entries]
        found = set()
        index = bisect.bisect_right(starts, first) - 1
        if index >= 0:
            found.add(entries[index][1])
        for line, node_id in entries[index + 1 :]:
            if line > last:
                break
            found.add(node_id)
        if not found:
            found.update(self.unlined_by_file.get(path, []))
        return found

    def nodes_starting_at(self, path: str, lines: range) -> set[str]:
        """Return nodes whose start line is one of ``lines``, such as a definition's decorator and def lines."""
        return {node_id for line, node_id in self.lined_by_file.get(path, []) if line in lines}

    def file_nodes(self, path: str) -> set[str]:
        """Return the node that stands for the module itself."""
        found = {
            node_id
            for line, node_id in self.lined_by_file.get(path, [])
            if line == 1 and path.endswith(self.nodes[node_id].get("label", "\0"))
        }
        return found or set(self.unlined_by_file.get(path, []))

    def is_test(self, node_id: str) -> bool:
        return is_test_path(self.nodes[node_id]["source_file"])

    def reach(self, node_id: str, depth: int) -> tuple[set[str], set[str], set[str]]:
        """Return direct production, transitive production, and test dependents."""
        direct = {d for d in self.dependents[node_id] if not self.is_test(d)}
        production: set[str] = set()
        tests: set[str] = set()
        seen = {node_id}
        queue = deque([(node_id, 0)])
        while queue:
            current, distance = queue.popleft()
            if distance == depth:
                continue
            for dependent in self.dependents[current]:
                if dependent in seen:
                    continue
                seen.add(dependent)
                if self.is_test(dependent):
                    tests.add(dependent)
                else:
                    production.add(dependent)
                    queue.append((dependent, distance + 1))
        return direct, production, tests


class _StripText(ast.NodeTransformer):
    """Remove docstrings and blank human-readable keyword text before comparing code."""

    def _strip_docstring(self, node):
        body = node.body
        if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
            node.body = body[1:]
        return self.generic_visit(node)

    visit_Module = visit_ClassDef = visit_FunctionDef = visit_AsyncFunctionDef = _strip_docstring

    def visit_keyword(self, node):
        if node.arg in TEXT_KEYWORDS and isinstance(node.value, (ast.Constant, ast.JoinedStr)):
            node.value = ast.Constant("")
        return self.generic_visit(node)

    def _blank_text_constant(self, node, targets):
        named_text = all(isinstance(t, ast.Name) and TEXT_NAME.search(t.id) for t in targets)
        if named_text and isinstance(node.value, (ast.Constant, ast.JoinedStr)):
            if not isinstance(node.value, ast.Constant) or isinstance(node.value.value, str):
                node.value = ast.Constant("")
        return self.generic_visit(node)

    def visit_Assign(self, node):
        return self._blank_text_constant(node, node.targets)

    def visit_AnnAssign(self, node):
        return self._blank_text_constant(node, [node.target]) if node.value is not None else node


def _stripped(node: ast.AST) -> Any:
    return _StripText().visit(copy.deepcopy(node))


def _has_default(value: ast.expr) -> bool:
    """Return True when an annotated field's value gives it a default, so callers need not pass it."""
    if not isinstance(value, ast.Call):
        return True
    if any(k.arg in {"default", "default_factory"} for k in value.keywords):
        return True
    first = value.args[0] if value.args else None
    return first is not None and not (isinstance(first, ast.Constant) and first.value is Ellipsis)


def _assigned_names(statements) -> set[str]:
    names: set[str] = set()
    for statement in statements:
        if isinstance(statement, ast.Assign):
            names |= {t.id for t in statement.targets if isinstance(t, ast.Name)}
        elif isinstance(statement, ast.AnnAssign) and isinstance(statement.target, ast.Name):
            names.add(statement.target.id)
    return names


def _is_typed_dict_class(node: ast.ClassDef) -> bool:
    """Return True when a class uses TypedDict's structural contract."""
    for base in node.bases:
        if isinstance(base, ast.Name) and base.id == "TypedDict":
            return True
        if isinstance(base, ast.Attribute) and base.attr == "TypedDict":
            return True
    return False


def _is_not_required(annotation: ast.expr) -> bool:
    """Return True when a TypedDict annotation explicitly makes its key optional."""
    if not isinstance(annotation, ast.Subscript):
        return False
    value = annotation.value
    return (isinstance(value, ast.Name) and value.id == "NotRequired") or (
        isinstance(value, ast.Attribute) and value.attr == "NotRequired"
    )


def _is_additive(statement: ast.stmt, old_names: set[str], in_class: bool, typed_dict: bool) -> bool:
    """Return True when a new statement only defines a name that did not exist before.

    Existing code cannot depend on a brand-new enum member or constant. A new
    annotated class field counts only when it has a default, because a field
    without one becomes required for every caller that builds the class. A
    NotRequired TypedDict key has the same compatibility property: existing
    dictionaries can omit it.
    """
    if isinstance(statement, ast.Assign):
        return all(isinstance(t, ast.Name) and t.id not in old_names for t in statement.targets)
    if isinstance(statement, ast.AnnAssign):
        if not isinstance(statement.target, ast.Name) or statement.target.id in old_names:
            return False
        return not in_class or (
            (statement.value is not None and _has_default(statement.value))
            or (typed_dict and _is_not_required(statement.annotation))
        )
    return False


def _worst(kinds) -> str:
    return max(kinds, key=CHANGE_ORDER.index, default="text")


def _compare_container(old: Any, new: Any) -> str:
    """Classify the difference between two versions of a class or module, ignoring nested definitions' bodies."""
    old, new = _stripped(old), _stripped(new)
    in_class = isinstance(old, ast.ClassDef)
    typed_dict = in_class and _is_typed_dict_class(old)
    if in_class:
        if not isinstance(new, ast.ClassDef):
            return "logic"
        old_header, new_header = copy.copy(old), copy.copy(new)
        old_header.body, new_header.body = [], []
        if ast.dump(old_header) != ast.dump(new_header):
            return "logic"

    def split(node):
        defs = {s.name for s in node.body if isinstance(s, DEF_TYPES)}
        others: dict[str, list[ast.stmt]] = {}
        for s in node.body:
            if not isinstance(s, DEF_TYPES):
                others.setdefault(ast.dump(s), []).append(s)
        return defs, others

    old_defs, old_others = split(old)
    new_defs, new_others = split(new)
    if old_defs - new_defs:
        return "logic"
    old_names = _assigned_names(old.body) | old_defs
    kinds = ["additive"] if new_defs - old_defs else []
    removed = [s for dumped, group in old_others.items() for s in group[len(new_others.get(dumped, [])) :]]
    added = [s for dumped, group in new_others.items() for s in group[len(old_others.get(dumped, [])) :]]

    # A statement that assigns the same names on both sides was modified, not removed and added.
    for old_statement in list(removed):
        names = _target_names(old_statement)
        new_statement = next((s for s in added if names and _target_names(s) == names), None)
        if new_statement is None:
            continue
        removed.remove(old_statement)
        added.remove(new_statement)
        same_annotation = ast.dump(getattr(old_statement, "annotation", None) or ast.Pass()) == ast.dump(
            getattr(new_statement, "annotation", None) or ast.Pass()
        )
        grew = same_annotation and _collection_grew(getattr(old_statement, "value", None), getattr(new_statement, "value", None))
        kinds.append("additive" if grew else "logic")

    for statement in removed:
        kinds.append("imports" if isinstance(statement, (ast.Import, ast.ImportFrom)) else "logic")
    for statement in added:
        if isinstance(statement, (ast.Import, ast.ImportFrom)):
            kinds.append("imports")
        else:
            kinds.append("additive" if _is_additive(statement, old_names, in_class, typed_dict) else "logic")
    return _worst(kinds)


def _target_names(statement: ast.stmt) -> tuple[str, ...] | None:
    if isinstance(statement, ast.Assign) and all(isinstance(t, ast.Name) for t in statement.targets):
        return tuple(t.id for t in statement.targets)  # type: ignore[attr-defined]
    if isinstance(statement, ast.AnnAssign) and isinstance(statement.target, ast.Name) and statement.value is not None:
        return (statement.target.id,)
    return None


def _is_subsequence(old: list[str], new: list[str]) -> bool:
    remaining = iter(new)
    return all(any(item == candidate for candidate in remaining) for item in old)


def _collection_grew(old: ast.expr | None, new: ast.expr | None) -> bool:
    """Return True when a literal dict, set, list, or tuple keeps every old entry and only gains entries.

    A wrapping call such as ``frozenset({...})`` counts when the call itself is unchanged.
    """
    if old is None or new is None or type(old) is not type(new):
        return False
    if isinstance(old, ast.Call) and isinstance(new, ast.Call):
        same_call = ast.dump(old.func) == ast.dump(new.func) and [ast.dump(k) for k in old.keywords] == [
            ast.dump(k) for k in new.keywords
        ]
        return same_call and len(old.args) == len(new.args) == 1 and _collection_grew(old.args[0], new.args[0])
    if isinstance(old, ast.Dict) and isinstance(new, ast.Dict):
        old_pairs = [(ast.dump(k) if k else "**") + ast.dump(v) for k, v in zip(old.keys, old.values)]
        new_pairs = [(ast.dump(k) if k else "**") + ast.dump(v) for k, v in zip(new.keys, new.values)]
        return len(new_pairs) > len(old_pairs) and _is_subsequence(old_pairs, new_pairs)
    if isinstance(old, (ast.Set, ast.List, ast.Tuple)) and isinstance(new, (ast.Set, ast.List, ast.Tuple)):
        old_items = [ast.dump(e) for e in old.elts]
        new_items = [ast.dump(e) for e in new.elts]
        if isinstance(old, ast.Set):
            return len(new_items) > len(old_items) and set(old_items) <= set(new_items)
        return len(new_items) > len(old_items) and _is_subsequence(old_items, new_items)
    return False


class Hunk(NamedTuple):
    old_first: int
    old_count: int
    new_first: int
    new_count: int

    def side_range(self, side: str) -> tuple[int, int]:
        first, count = (self.old_first, self.old_count) if side == "base" else (self.new_first, self.new_count)
        return max(first, 1), max(first + max(count, 1) - 1, 1)


class ChangeClassifier:
    """Classify the changes in one file as text, imports, additive, or logic.

    For each hunk, the classifier finds the innermost function, class, or
    module that holds the removed lines (in the old file) and the added lines
    (in the new file). It then compares that scope's old and new versions. Any
    doubt, such as a file that does not parse or a definition defined twice, is
    classified as logic.
    """

    def __init__(self, old_source: str | None, new_source: str | None):
        self.old = self._parse(old_source)
        self.new = self._parse(new_source)
        self.scopes = {"base": self._scopes(self.old), "head": self._scopes(self.new)}
        self.ambiguous = self.scopes["base"][2] | self.scopes["head"][2]
        self._cache: dict[str, str] = {}

    @staticmethod
    def _parse(source: str | None) -> ast.Module | None:
        if source is None:
            return None
        try:
            return ast.parse(source)
        except (SyntaxError, ValueError):
            return None

    @staticmethod
    def _scopes(tree: ast.Module | None):
        scopes: dict[str, Any] = {}
        spans: list[tuple[int, int, str]] = []
        ambiguous: set[str] = set()
        if tree is None:
            return scopes, spans, ambiguous

        def walk(node, prefix):
            for child in ast.iter_child_nodes(node):
                if isinstance(child, DEF_TYPES):
                    name = f"{prefix}.{child.name}" if prefix else child.name
                    if name in scopes:
                        ambiguous.add(name)
                    scopes[name] = child
                    start = min([child.lineno] + [d.lineno for d in child.decorator_list])
                    spans.append((start, child.end_lineno or child.lineno, name))
                    walk(child, name)
                else:
                    walk(child, prefix)

        walk(tree, "")
        return scopes, spans, ambiguous

    def _innermost(self, side: str, line: int) -> str:
        best = ("", 0)
        for start, end, name in self.scopes[side][1]:
            if start <= line <= end and start >= best[1]:
                best = (name, start)
        return best[0]

    def _scope_kind(self, name: str) -> str:
        if name in self._cache:
            return self._cache[name]
        old_scopes, new_scopes = self.scopes["base"][0], self.scopes["head"][0]
        if self.old is None or self.new is None or name in self.ambiguous:
            kind = "logic"
        elif name == "":
            kind = _compare_container(self.old, self.new)
        elif name not in old_scopes:
            kind = "additive"
        elif name not in new_scopes:
            kind = "logic"
        else:
            old, new = old_scopes[name], new_scopes[name]
            if isinstance(old, ast.ClassDef):
                kind = _compare_container(old, new)
            elif type(old) is type(new) and ast.dump(_stripped(old)) == ast.dump(_stripped(new)):
                kind = "text"
            else:
                kind = "logic"
        self._cache[name] = kind
        return kind

    def hunk_scopes(self, hunk: Hunk) -> dict[str, str] | None:
        """Return {scope name: change kind} for a hunk, or None when either file does not parse."""
        if self.old is None or self.new is None:
            return None
        names = {self._innermost("base", line) for line in range(hunk.old_first, hunk.old_first + hunk.old_count)}
        names |= {self._innermost("head", line) for line in range(hunk.new_first, hunk.new_first + hunk.new_count)}
        return {name: self._scope_kind(name) for name in names}

    def anchor_lines(self, name: str, side: str) -> range | None:
        """Return the decorator-to-def lines of a scope on one side, climbing to its parent when it is missing.

        None means the scope is the module itself.
        """
        scopes = self.scopes[side][0]
        while name:
            node = scopes.get(name)
            if node is not None:
                start = min([node.lineno] + [d.lineno for d in node.decorator_list])
                return range(start, node.lineno + 1)
            name = name.rpartition(".")[0]
        return None


def nodes_for_hunk(graph: "CodeGraph", path: str, classifier: ChangeClassifier, hunk: Hunk, side: str) -> dict[str, str]:
    """Map one hunk to {graph node id: change kind}, using lines from the side the graph was built from."""
    first, last = hunk.side_range(side)
    scopes = classifier.hunk_scopes(hunk)
    if scopes is None:
        return {node_id: "logic" for node_id in graph.nodes_for_range(path, first, last)}
    found: dict[str, str] = {}
    for name, kind in scopes.items():
        anchor = classifier.anchor_lines(name, side)
        nodes = graph.file_nodes(path) if anchor is None else graph.nodes_starting_at(path, anchor)
        for node_id in nodes or graph.nodes_for_range(path, first, last):
            found[node_id] = _worst([found.get(node_id, "text"), kind])
    return found


def file_at(repo: Path, revision: str, path: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(repo), "show", f"{revision}:{path}"], capture_output=True, text=True
    )
    return result.stdout if result.returncode == 0 else None


def changed_ranges(repo: Path, base: str, head: str) -> dict[str, list[Hunk] | None]:
    """Map each changed base-side path to its hunks.

    A value of None marks a file that is new in the head revision.
    """
    diff = subprocess.run(
        ["git", "-C", str(repo), "diff", "-U0", "--no-color", "--no-renames", f"{base}...{head}"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    ranges: dict[str, list[Hunk] | None] = {}
    old_path = None
    for line in diff.splitlines():
        if line.startswith("--- "):
            old_path = None if line == "--- /dev/null" else line[6:]
        elif line.startswith("+++ "):
            if old_path is None:
                ranges[line[6:]] = None
            else:
                ranges.setdefault(old_path, [])
        elif old_path is not None:
            match = HUNK_HEADER.match(line)
            hunks = ranges.get(old_path)
            if match and hunks is not None:
                hunks.append(
                    Hunk(
                        int(match.group(1)),
                        1 if match.group(2) is None else int(match.group(2)),
                        int(match.group(3)),
                        1 if match.group(4) is None else int(match.group(4)),
                    )
                )
    return ranges


def graph_built_at(graph_path: Path) -> str | None:
    cost = graph_path.parent / "cost.json"
    try:
        runs = json.loads(cost.read_text()).get("runs") or []
    except (OSError, ValueError):
        return None
    return runs[-1].get("date") if runs else None


def graph_built_from(graph_path: Path) -> str | None:
    """Return the commit SHA recorded next to the graph's scope copy, if any."""
    marker = graph_path.parent.parent / "BUILT_FROM"
    try:
        return marker.read_text().strip() or None
    except OSError:
        return None


def commits_since(repo: Path, base: str, prefix: str, since: str | None, built_from: str | None) -> int | None:
    """Count target commits in scope since the build, by SHA when known, else by date."""
    if built_from:
        revision_args = [f"{built_from}..{base}"]
    elif since:
        revision_args = [f"--since={since}", base]
    else:
        return None
    output = subprocess.run(
        ["git", "-C", str(repo), "log", "--format=%H", *revision_args, "--", prefix or "."],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return len(output.split())


def percentile(value: int, sorted_values: list[int]) -> float:
    if not sorted_values:
        return 0.0
    return 100.0 * bisect.bisect_left(sorted_values, value) / len(sorted_values)


def changed_line_count(repo: Path, base: str, head: str) -> int:
    numstat = subprocess.run(
        ["git", "-C", str(repo), "diff", "--numstat", "--no-renames", f"{base}...{head}"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    total = 0
    for line in numstat.splitlines():
        added, deleted, _ = line.split("\t", 2)
        if added.isdigit() and deleted.isdigit():
            total += int(added) + int(deleted)
    return total


def sensitive_paths(paths: list[str]) -> list[dict[str, str]]:
    found = []
    for path in sorted(paths):
        for area, pattern in SENSITIVE_PATHS:
            if pattern.search(path):
                found.append({"path": path, "area": area})
                break
    return found


def _plural(count: int, word: str) -> str:
    return f"{count} {word}" if count == 1 else f"{count} {word}s"


def reach_reason(reports: list[dict], reach: str) -> str:
    """One plain sentence that says why the blast radius got its rating."""
    if reach == "unknown":
        return "No changed file is in the code graph."
    if not reports:
        return "Only adds new files, so no existing code depends on the change."
    logic = [r for r in reports if r["change"] == "logic"]
    if reach in ("high", "medium"):
        top = [r for r in logic if REACH_FOR_TIER[r["tier"]] == reach]
        first = top[0]
        dependents, tests = first["transitive_prod_dependents"], first["test_dependents"]
        reason = (
            f"Changes logic in {first['label']}, which {_plural(dependents, 'function')} "
            f"depend{'s' if dependents == 1 else ''} on. "
            f"{_plural(tests, 'test')} cover{'s' if tests == 1 else ''} it."
        )
        if len(top) > 1:
            reason += f" {_plural(len(top) - 1, 'more node')} at this level."
        return reason
    widest = max(reports, key=lambda r: r["transitive_prod_dependents"])
    if widest["change"] != "logic" and widest["reach_tier"] != "leaf":
        return (
            f"Only adds names, text, or imports to code that "
            f"{widest['transitive_prod_dependents']} functions depend on. Nothing that depends on it can break."
        )
    if not logic:
        return "Only adds names, text, or imports. Nothing that depends on the code can break."
    most = max(r["transitive_prod_dependents"] for r in logic)
    return f"Logic changes reach at most {most} other functions."


def tier_for(transitive: int, pct: float) -> str:
    if pct >= HUB_PERCENTILE and transitive >= HUB_MIN_DEPENDENTS:
        return "hub"
    if pct >= SHARED_PERCENTILE and transitive >= SHARED_MIN_DEPENDENTS:
        return "shared"
    return "leaf"


def analyze(graph_path: Path, repo: Path, base: str, head: str, prefix: str, depth: int = 3) -> dict:
    graph_path, repo = Path(graph_path), Path(repo)
    graph = CodeGraph(json.loads(graph_path.read_text()))
    prefix = prefix.strip("/")
    lead = f"{prefix}/" if prefix else ""

    merge_base = subprocess.run(
        ["git", "-C", str(repo), "merge-base", base, head], check=True, capture_output=True, text=True
    ).stdout.strip()
    head_sha = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", head], check=True, capture_output=True, text=True
    ).stdout.strip()
    changed: dict[str, str] = {}
    outside: list[str] = []
    new_files: list[str] = []
    diff_ranges = changed_ranges(repo, base, head)
    for path, ranges in sorted(diff_ranges.items()):
        relative = path[len(lead) :] if path.startswith(lead) else None
        if ranges is None:
            new_files.append(path)
        elif relative is None or not graph.has_file(relative):
            outside.append(path)
        else:
            classifier = ChangeClassifier(file_at(repo, merge_base, path), file_at(repo, head, path))
            for hunk in ranges or [Hunk(1, 1, 1, 1)]:
                for node_id, kind in nodes_for_hunk(graph, relative, classifier, hunk, "base").items():
                    changed[node_id] = _worst([changed.get(node_id, "text"), kind])

    distribution = sorted(len(graph.reach(n, depth)[1]) for n in graph.nodes)
    reports = []
    for node_id, change in sorted(changed.items()):
        direct, production, tests = graph.reach(node_id, depth)
        pct = percentile(len(production), distribution)
        reach_tier = tier_for(len(production), pct)
        n = graph.nodes[node_id]
        reports.append(
            {
                "id": node_id,
                "label": n.get("label", node_id),
                "file": f"{lead}{n['source_file']}",
                "line": start_line(n.get("source_location")),
                "direct_prod_dependents": len(direct),
                "transitive_prod_dependents": len(production),
                "test_dependents": len(tests),
                "communities_reached": len({graph.nodes[d].get("community") for d in production}),
                "packages_reached": sorted({graph.nodes[d]["source_file"].split("/")[0] for d in production}),
                "percentile": round(pct, 1),
                "change": change,
                "reach_tier": reach_tier,
                "tier": reach_tier if change == "logic" else "leaf",
            }
        )
    reports.sort(
        key=lambda r: (
            -TIER_ORDER.index(r["tier"]),
            -TIER_ORDER.index(r["reach_tier"]),
            -r["transitive_prod_dependents"],
            r["id"],
        )
    )

    if reports:
        overall = max((r["tier"] for r in reports), key=TIER_ORDER.index)
    else:
        overall = "unknown" if outside or not new_files else "leaf"
    reach = REACH_FOR_TIER.get(overall, "unknown")

    built_at = graph_built_at(graph_path)
    built_from = graph_built_from(graph_path)
    return {
        "revisions": {"base": base, "head": head_sha, "merge_base": merge_base},
        "reach": reach,
        "reason": reach_reason(reports, reach),
        "sensitive_paths": sensitive_paths(list(diff_ranges)),
        "changed_lines": changed_line_count(repo, base, head),
        "graph": {
            "path": str(graph_path),
            "built_at": built_at,
            "built_from": built_from,
            "target_commits_since_build": commits_since(repo, base, prefix, built_at, built_from),
            "depth": depth,
        },
        "overall": overall,
        "complete": not outside,
        "changed_nodes": reports,
        "files_outside_graph": outside,
        "new_files": new_files,
    }


def render_text(result: dict, limit: int) -> str:
    g = result["graph"]
    lines = [
        f"Blast radius: {result['reach']}. {result['reason']}"
        f"{'' if result['complete'] or result['reach'] == 'unknown' else ' Partial: some files are not in the graph.'}",
        f"Head {result['revisions']['head'][:12]} against {result['revisions']['base']} "
        f"(merge base {result['revisions']['merge_base'][:12]}); {result['changed_lines']} changed lines.",
    ]
    if result["sensitive_paths"]:
        lines.append(
            "Always needs a person: "
            + ", ".join(f"{s['path']} ({s['area']})" for s in result["sensitive_paths"])
        )
    lines += [
        f"Graph built {g['built_at'] or 'at an unknown time'} from {g['built_from'] or 'an unrecorded commit'};{g['target_commits_since_build']} target commits in scope since then; depth {g['depth']}.",
    ]
    for r in result["changed_nodes"][:limit]:
        lines.append(
            f"- {r['tier']:<6} {r['change']:<8} {r['label']} ({r['file']}:{r['line']}): "
            f"{'' if r['change'] == 'logic' or r['reach_tier'] == 'leaf' else 'reach ' + r['reach_tier'] + ', '}"
            f"{r['direct_prod_dependents']} direct / {r['transitive_prod_dependents']} transitive prod dependents, "
            f"{r['test_dependents']} test dependents, {r['communities_reached']} communities, p{r['percentile']:.0f}"
        )
    hidden = len(result["changed_nodes"]) - limit
    if hidden > 0:
        lines.append(f"- ... {hidden} more changed nodes")
    if result["files_outside_graph"]:
        lines.append(f"Not in graph: {', '.join(result['files_outside_graph'])}")
    if result["new_files"]:
        lines.append(f"New files: {', '.join(result['new_files'])}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Estimate how far a diff reaches through a graphify code graph.")
    parser.add_argument("--graph", required=True, type=Path, help="graphify-out/graph.json built from the target branch")
    parser.add_argument("--repo", required=True, type=Path, help="Git checkout that has both revisions")
    parser.add_argument("--base", required=True, help="Target branch or merge-base revision")
    parser.add_argument("--head", default="HEAD", help="Source revision")
    parser.add_argument("--prefix", default="", help="Repository path that the graph's file paths are relative to")
    parser.add_argument("--depth", type=int, default=3)
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--limit", type=int, default=15, help="Changed nodes to print in text mode")
    args = parser.parse_args()
    result = analyze(args.graph, args.repo, args.base, args.head, args.prefix, args.depth)
    print(json.dumps(result, indent=2) if args.format == "json" else render_text(result, args.limit))


if __name__ == "__main__":
    main()
