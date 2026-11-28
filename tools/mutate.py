#!/usr/bin/env python3
"""Deterministic mutation testing for moonbit-sparse-math.

The catalog below intentionally targets the core sparse algorithms. Every mutant
is injected into the real source tree, checked with a full `moon test` run, and
restored in a `finally` block. Results are never inferred or fabricated.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = "tools/mutation-report.json"

CATALOG: list[dict[str, Any]] = [
    {
        "id": "arith-01",
        "operator": "arithmetic",
        "mutation": "+ -> -",
        "file": "src/ops/spgemm.mbt",
        "line": 46,
        "original": "acc[b_col] = acc[b_col] + a_value * b.values[b_pos]",
        "mutated": "acc[b_col] = acc[b_col] - a_value * b.values[b_pos]",
    },
    {
        "id": "arith-02",
        "operator": "arithmetic",
        "mutation": "* -> /",
        "file": "src/ops/spgemm.mbt",
        "line": 46,
        "original": "acc[b_col] = acc[b_col] + a_value * b.values[b_pos]",
        "mutated": "acc[b_col] = acc[b_col] + a_value / b.values[b_pos]",
    },
    {
        "id": "arith-03",
        "operator": "arithmetic",
        "mutation": "+ -> -",
        "file": "src/core/csr.mbt",
        "line": 81,
        "original": "sum = sum + csr.values[k] * x[col]",
        "mutated": "sum = sum - csr.values[k] * x[col]",
    },
    {
        "id": "arith-04",
        "operator": "arithmetic",
        "mutation": "* -> /",
        "file": "src/core/csr.mbt",
        "line": 129,
        "original": "sum = sum + csr.values[k] * x[csr.col_indices[k]]",
        "mutated": "sum = sum + csr.values[k] / x[csr.col_indices[k]]",
    },
    {
        "id": "arith-05",
        "operator": "arithmetic",
        "mutation": "+ -> -",
        "file": "src/core/ordering.mbt",
        "line": 157,
        "original": "value = value + entries[entry_index].1",
        "mutated": "value = value - entries[entry_index].1",
    },
    {
        "id": "arith-06",
        "operator": "arithmetic",
        "mutation": "* -> /",
        "file": "src/ops/basic_ops.mbt",
        "line": 138,
        "original": "let value = entry.1 * alpha",
        "mutated": "let value = entry.1 / alpha",
    },
    {
        "id": "rel-01",
        "operator": "relational",
        "mutation": "!= -> ==",
        "file": "src/ops/spgemm.mbt",
        "line": 53,
        "original": "if value != @luna_generic.Zero::zero() {",
        "mutated": "if value == @luna_generic.Zero::zero() {",
    },
    {
        "id": "rel-02",
        "operator": "relational",
        "mutation": "!= -> ==",
        "file": "src/core/csr.mbt",
        "line": 72,
        "original": "if x.length() != rows {",
        "mutated": "if x.length() == rows {",
    },
    {
        "id": "rel-03",
        "operator": "relational",
        "mutation": "!= -> ==",
        "file": "src/core/ordering.mbt",
        "line": 79,
        "original": "if left_degree != right_degree {",
        "mutated": "if left_degree == right_degree {",
    },
    {
        "id": "rel-04",
        "operator": "relational",
        "mutation": "== -> !=",
        "file": "src/ops/basic_ops.mbt",
        "line": 173,
        "original": "if left[left_index].0 == right[right_index].0 {",
        "mutated": "if left[left_index].0 != right[right_index].0 {",
    },
    {
        "id": "rel-05",
        "operator": "relational",
        "mutation": "> -> >=",
        "file": "src/algebra/diagnostics.mbt",
        "line": 77,
        "original": "if (value - mirror).abs() > tolerance {",
        "mutated": "if (value - mirror).abs() >= tolerance {",
    },
    {
        "id": "rel-06",
        "operator": "relational",
        "mutation": "< -> <=",
        "file": "src/core/ordering.mbt",
        "line": 53,
        "original": "if start < 0 || degree < start_degree {",
        "mutated": "if start < 0 || degree <= start_degree {",
    },
    {
        "id": "bound-01",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/ops/spgemm.mbt",
        "line": 8,
        "original": "for i = 0; i < b.col_indices.length(); i = i + 1 {",
        "mutated": "for i = 0; i <= b.col_indices.length(); i = i + 1 {",
    },
    {
        "id": "bound-02",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/core/csr.mbt",
        "line": 77,
        "original": "for i = 0; i < rows; i = i + 1 {",
        "mutated": "for i = 0; i <= rows; i = i + 1 {",
    },
    {
        "id": "bound-03",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/core/coo.mbt",
        "line": 23,
        "original": "for row = 0; row < rows; row = row + 1 {",
        "mutated": "for row = 0; row <= rows; row = row + 1 {",
    },
    {
        "id": "bound-04",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/core/ordering.mbt",
        "line": 50,
        "original": "for i = 0; i < nodes; i = i + 1 {",
        "mutated": "for i = 0; i <= nodes; i = i + 1 {",
    },
    {
        "id": "bound-05",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/ops/basic_ops.mbt",
        "line": 37,
        "original": "for k = a.row_ptr[row]; k < a.row_ptr[row + 1]; k = k + 1 {",
        "mutated": "for k = a.row_ptr[row]; k <= a.row_ptr[row + 1]; k = k + 1 {",
    },
    {
        "id": "bound-06",
        "operator": "boundary",
        "mutation": "< -> <=",
        "file": "src/algebra/diagnostics.mbt",
        "line": 118,
        "original": "for k = 0; k < j; k = k + 1 {",
        "mutated": "for k = 0; k <= j; k = k + 1 {",
    },
    {
        "id": "accum-01",
        "operator": "accumulation",
        "mutation": "acc = acc + x -> acc = x",
        "file": "src/ops/spgemm.mbt",
        "line": 46,
        "original": "acc[b_col] = acc[b_col] + a_value * b.values[b_pos]",
        "mutated": "acc[b_col] = a_value * b.values[b_pos]",
    },
    {
        "id": "accum-02",
        "operator": "accumulation",
        "mutation": "value = value + x -> value = x",
        "file": "src/core/coo.mbt",
        "line": 60,
        "original": "value = value + entries[entry_index].2",
        "mutated": "value = entries[entry_index].2",
    },
    {
        "id": "accum-03",
        "operator": "accumulation",
        "mutation": "value = value + x -> value = x",
        "file": "src/core/ordering.mbt",
        "line": 157,
        "original": "value = value + entries[entry_index].1",
        "mutated": "value = entries[entry_index].1",
    },
    {
        "id": "accum-04",
        "operator": "accumulation",
        "mutation": "sum = sum + x -> sum = x",
        "file": "src/core/csr.mbt",
        "line": 81,
        "original": "sum = sum + csr.values[k] * x[col]",
        "mutated": "sum = csr.values[k] * x[col]",
    },
    {
        "id": "accum-05",
        "operator": "accumulation",
        "mutation": "left + right -> right",
        "file": "src/ops/basic_ops.mbt",
        "line": 94,
        "original": "let value = left[left_index].1 + right[right_index].1",
        "mutated": "let value = right[right_index].1",
    },
    {
        "id": "accum-06",
        "operator": "accumulation",
        "mutation": "value = value + x -> value = x",
        "file": "src/algebra/diagnostics.mbt",
        "line": 28,
        "original": "value = value + csr.values[k]",
        "mutated": "value = csr.values[k]",
    },
    {
        "id": "logic-01",
        "operator": "logical",
        "mutation": "!x -> x",
        "file": "src/core/ordering.mbt",
        "line": 51,
        "original": "if !visited[i] {",
        "mutated": "if visited[i] {",
    },
    {
        "id": "logic-02",
        "operator": "logical",
        "mutation": "!x -> x",
        "file": "src/algebra/diagnostics.mbt",
        "line": 93,
        "original": "if !is_symmetric(csr) {",
        "mutated": "if is_symmetric(csr) {",
    },
    {
        "id": "logic-03",
        "operator": "logical",
        "mutation": "!x -> x",
        "file": "src/core/ordering.mbt",
        "line": 19,
        "original": "if !adjacency[i].contains(j) {",
        "mutated": "if adjacency[i].contains(j) {",
    },
    {
        "id": "logic-04",
        "operator": "logical",
        "mutation": "|| -> &&",
        "file": "src/core/ordering.mbt",
        "line": 53,
        "original": "if start < 0 || degree < start_degree {",
        "mutated": "if start < 0 && degree < start_degree {",
    },
    {
        "id": "logic-05",
        "operator": "logical",
        "mutation": "&& -> ||",
        "file": "src/core/ordering.mbt",
        "line": 156,
        "original": "while entry_index < entries.length() && entries[entry_index].0 == new_col {",
        "mutated": "while entry_index < entries.length() || entries[entry_index].0 == new_col {",
    },
    {
        "id": "logic-06",
        "operator": "logical",
        "mutation": "|| -> &&",
        "file": "src/ops/basic_ops.mbt",
        "line": 82,
        "original": "while left_index < left.length() || right_index < right.length() {",
        "mutated": "while left_index < left.length() && right_index < right.length() {",
    },
    {
        "id": "data-01",
        "operator": "data",
        "mutation": "row index -> column index",
        "file": "src/core/coo.mbt",
        "line": 26,
        "original": "row_indices.push(row)",
        "mutated": "row_indices.push(csr.col_indices[pos])",
    },
    {
        "id": "data-02",
        "operator": "data",
        "mutation": "column index -> row index",
        "file": "src/core/coo.mbt",
        "line": 27,
        "original": "col_indices.push(csr.col_indices[pos])",
        "mutated": "col_indices.push(row)",
    },
    {
        "id": "data-03",
        "operator": "data",
        "mutation": "row/column coordinate swap",
        "file": "src/core/coo.mbt",
        "line": 38,
        "original": "entries.push((coo.row_indices[i], coo.col_indices[i], coo.values[i]))",
        "mutated": "entries.push((coo.col_indices[i], coo.row_indices[i], coo.values[i]))",
    },
    {
        "id": "data-04",
        "operator": "data",
        "mutation": "row-major sort -> column-major sort",
        "file": "src/core/coo.mbt",
        "line": 42,
        "original": "left.0.compare(right.0)",
        "mutated": "left.1.compare(right.1)",
    },
    {
        "id": "data-05",
        "operator": "data",
        "mutation": "transpose row index -> column index",
        "file": "src/core/csr.mbt",
        "line": 169,
        "original": "t_col_indices[pos] = i",
        "mutated": "t_col_indices[pos] = col",
    },
    {
        "id": "data-06",
        "operator": "data",
        "mutation": "transpose scatter uses row instead of column",
        "file": "src/core/csr.mbt",
        "line": 167,
        "original": "let pos = t_row_ptr[col] + next[col]",
        "mutated": "let pos = t_row_ptr[i] + next[i]",
    },
]

OPERATOR_LABELS = {
    "arithmetic": "算术",
    "relational": "关系",
    "boundary": "边界",
    "accumulation": "累加",
    "logical": "逻辑",
    "data": "数据",
}


def read_raw(path: Path) -> str:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return handle.read()


def write_raw(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def validate_catalog(selected: list[dict[str, Any]]) -> None:
    for mutant in selected:
        path = ROOT / mutant["file"]
        if not path.is_file():
            raise RuntimeError(f"{mutant['id']}: missing file {mutant['file']}")
        lines = read_raw(path).splitlines(keepends=True)
        line_number = int(mutant["line"])
        if line_number < 1 or line_number > len(lines):
            raise RuntimeError(
                f"{mutant['id']}: line {line_number} outside {mutant['file']}"
            )
        actual = lines[line_number - 1].rstrip("\r\n").strip()
        expected = mutant["original"].strip()
        if actual != expected:
            raise RuntimeError(
                f"{mutant['id']}: source anchor changed at {mutant['file']}:{line_number}\n"
                f"expected: {expected}\nactual:   {actual}"
            )


def classify_failure(returncode: int | None, output: str) -> str:
    if returncode is None:
        return "timeout"
    if returncode == 0:
        return "none"
    if re.search(r"failed:\s*[1-9][0-9]*", output):
        return "test_failure"
    if "Total tests:" in output:
        return "test_failure"
    if "error" in output.lower() or "failed to build" in output.lower():
        return "build_failure"
    return "non_zero_exit"


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="",
    )
    temporary.replace(path)


def summarize(
    label: str,
    start_time: str,
    baseline: dict[str, Any],
    mutants: list[dict[str, Any]],
    command: str,
) -> dict[str, Any]:
    total = len(mutants)
    killed = sum(1 for mutant in mutants if mutant["status"] == "killed")
    survived = total - killed
    by_operator: dict[str, dict[str, int]] = {}
    by_file: dict[str, dict[str, int]] = {}
    for mutant in mutants:
        operator = mutant["operator"]
        operator_entry = by_operator.setdefault(
            operator, {"total": 0, "killed": 0, "survived": 0}
        )
        operator_entry["total"] += 1
        operator_entry["killed" if mutant["status"] == "killed" else "survived"] += 1

        file_name = mutant["file"]
        file_entry = by_file.setdefault(
            file_name, {"total": 0, "killed": 0, "survived": 0}
        )
        file_entry["total"] += 1
        file_entry["killed" if mutant["status"] == "killed" else "survived"] += 1

    return {
        "label": label,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "started_at": start_time,
        "command": command,
        "baseline": baseline,
        "total": total,
        "killed": killed,
        "survived": survived,
        "mutation_score": round(killed / total, 6) if total else 0.0,
        "mutation_percent": round(100.0 * killed / total, 2) if total else 0.0,
        "by_operator": by_operator,
        "by_file": by_file,
        "mutants": mutants,
    }


def run_tests(timeout: int) -> tuple[int | None, str, str]:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            ["moon", "test"],
            cwd=ROOT,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            timeout=timeout,
        )
        elapsed_ms = round((time.monotonic() - started) * 1000)
        output = (completed.stdout or "") + (completed.stderr or "")
        return completed.returncode, output, f"{elapsed_ms}ms"
    except subprocess.TimeoutExpired as error:
        elapsed_ms = round((time.monotonic() - started) * 1000)
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        return None, str(stdout) + str(stderr), f"{elapsed_ms}ms"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--label", default="final")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--skip-baseline", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    selected = CATALOG
    if args.only:
        selected_ids = set(args.only)
        selected = [mutant for mutant in CATALOG if mutant["id"] in selected_ids]
        unknown = selected_ids - {mutant["id"] for mutant in selected}
        if unknown:
            parser.error(f"unknown mutant ids: {', '.join(sorted(unknown))}")

    try:
        validate_catalog(selected)
    except RuntimeError as error:
        print(f"catalog validation failed: {error}", file=sys.stderr)
        return 2

    operator_counts: dict[str, int] = {}
    for mutant in selected:
        operator_counts[mutant["operator"]] = operator_counts.get(mutant["operator"], 0) + 1
    print(
        "validated mutations: "
        + ", ".join(
            f"{name}={operator_counts[name]}"
            for name in sorted(operator_counts)
        )
    )
    if args.dry_run:
        print("dry run only; no source was modified")
        return 0

    output_path = (ROOT / args.output).resolve()
    start_time = datetime.now(timezone.utc).isoformat()
    baseline: dict[str, Any] = {"skipped": True}
    if not args.skip_baseline:
        returncode, output, elapsed = run_tests(args.timeout)
        baseline = {
            "skipped": False,
            "exit_code": returncode,
            "duration": elapsed,
            "passed": returncode == 0,
            "output_tail": output[-2000:],
        }
        if returncode != 0:
            print("baseline moon test failed; refusing to run mutation tests", file=sys.stderr)
            return 2
        print(f"baseline moon test passed ({elapsed})")

    results: list[dict[str, Any]] = []
    for index, mutant in enumerate(selected, start=1):
        path = ROOT / mutant["file"]
        original_text = read_raw(path)
        lines = original_text.splitlines(keepends=True)
        line_index = int(mutant["line"]) - 1
        original_line = lines[line_index]
        eol = "\r\n" if original_line.endswith("\r\n") else "\n"
        stripped_line = original_line.rstrip("\r\n")
        indentation = stripped_line[: len(stripped_line) - len(stripped_line.lstrip())]
        lines[line_index] = indentation + mutant["mutated"] + eol

        returncode: int | None = None
        test_output = ""
        duration = "0ms"
        try:
            write_raw(path, "".join(lines))
            returncode, test_output, duration = run_tests(args.timeout)
        finally:
            write_raw(path, original_text)

        status = "killed" if returncode != 0 else "survived"
        result = {
            "id": mutant["id"],
            "file": mutant["file"],
            "operator": mutant["operator"],
            "operator_label": OPERATOR_LABELS.get(mutant["operator"], mutant["operator"]),
            "mutation": mutant["mutation"],
            "line": mutant["line"],
            "original": mutant["original"],
            "mutated": mutant["mutated"],
            "status": status,
            "failure_kind": classify_failure(returncode, test_output),
            "exit_code": returncode,
            "duration": duration,
            "output_tail": test_output[-1200:] if status == "killed" else "",
        }
        results.append(result)
        report = summarize(
            args.label,
            start_time,
            baseline,
            results,
            "moon test",
        )
        write_report(output_path, report)
        print(
            f"[{index:02d}/{len(selected):02d}] {status:8s} "
            f"{mutant['operator']:12s} {mutant['file']}:{mutant['line']} "
            f"({mutant['mutation']})"
        )

    final_report = summarize(args.label, start_time, baseline, results, "moon test")
    write_report(output_path, final_report)
    print(
        f"mutation score: {final_report['killed']}/{final_report['total']} "
        f"= {final_report['mutation_percent']:.2f}% "
        f"(survived {final_report['survived']})"
    )
    print(f"report: {output_path}")
    for mutant in results:
        if mutant["status"] == "survived":
            print(
                f"survived: {mutant['id']} {mutant['file']}:{mutant['line']} "
                f"{mutant['mutation']}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
