#!/usr/bin/env python3
"""Run every file in queries/ against telco.db and save the output to results/.

For each query it prints the business question, the row count, and checks the count
against the "-- Expected rows: N" line in the query's header. Exits with code 1 if any
query errors or any count differs. FICTIONAL data only.

Usage:  python run_queries.py            (run build_db.py first)
"""
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "telco.db"
QUERY_DIR = ROOT / "queries"
RESULT_DIR = ROOT / "results"
SHOW_ROWS = 15                      # rows printed per query; the row count is always exact

sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # Turkish letters on Windows


def split_statements(text):
    """Split a .sql file into statements; comments stay attached to the statement below them."""
    statements, buffer = [], ""
    for line in text.splitlines(keepends=True):
        buffer += line
        if sqlite3.complete_statement(buffer):
            statements.append(buffer.strip())
            buffer = ""
    return statements


def fmt(value):
    if value is None:
        return "NULL"
    return str(value)


def render_table(columns, rows, limit=None):
    shown = rows if limit is None else rows[:limit]
    cells = [[fmt(v) for v in row] for row in shown]
    widths = [max(len(c), *(len(r[i]) for r in cells)) if cells else len(c) for i, c in enumerate(columns)]
    lines = ["  ".join(c.ljust(w) for c, w in zip(columns, widths)).rstrip(),
             "  ".join("-" * w for w in widths)]
    lines += ["  ".join(v.ljust(w) for v, w in zip(row, widths)).rstrip() for row in cells]
    if limit is not None and len(rows) > limit:
        lines.append(f"... ({len(rows) - limit} more rows; all rows are in results/)")
    return "\n".join(lines)


def main():
    if not DB_PATH.exists():
        sys.exit("telco.db not found. Run:  python build_db.py")

    conn = sqlite3.connect(f"{DB_PATH.as_uri()}?mode=ro", uri=True)
    conn.execute("PRAGMA foreign_keys = ON")
    RESULT_DIR.mkdir(exist_ok=True)

    problems = 0
    total = 0
    for path in sorted(QUERY_DIR.glob("*.sql")):
        out = [f"=== {path.name} ===", ""]       # full output, saved to results/
        shown = list(out)                         # shortened output, printed to the console
        for number, statement in enumerate(split_statements(path.read_text(encoding="utf-8")), start=1):
            question = re.search(r"--\s*Q:\s*(.+)", statement)
            expected = re.search(r"--\s*Expected rows:\s*(\d+)", statement)
            label = question.group(1).strip() if question else "(no question comment)"
            try:
                cursor = conn.execute(statement)
                rows = cursor.fetchall()
                columns = [d[0] for d in cursor.description] if cursor.description else []
            except sqlite3.Error as exc:
                problems += 1
                for target in (out, shown):
                    target += [f"[{number}] {label}", f"ERROR: {exc}", ""]
                continue

            total += 1
            if expected is None:
                status = "no expected count in header"
                problems += 1
            elif int(expected.group(1)) == len(rows):
                status = f"{len(rows)} rows, matches expected"
            else:
                status = f"{len(rows)} rows, EXPECTED {expected.group(1)}  <-- MISMATCH"
                problems += 1
            for target in (out, shown):
                target += [f"[{number}] {label}", f"    {status}", ""]
            if rows and columns:
                out += [render_table(columns, rows), ""]
                shown += [render_table(columns, rows, SHOW_ROWS), ""]

        print("\n".join(shown))
        (RESULT_DIR / f"{path.stem}.txt").write_text("\n".join(out) + "\n", encoding="utf-8")

    print(f"Ran {total} queries; problems: {problems}")
    conn.close()
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
