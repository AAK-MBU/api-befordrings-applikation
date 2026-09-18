#!/usr/bin/env python3
"""Compare two SQL Server schemas by diffing their generated creation scripts.

    python3 compare_schemas.py seed/dev_db_full_creation.sql seed/prod_db_full_creation.sql

Produce the inputs from SSMS: right-click the database -> Tasks -> Generate
Scripts -> select the `befordring` schema -> script to file. Do both databases
with the same options, or the noise will drown the signal.

Why this exists rather than `diff`: SSMS scripts objects in creation order
(object_id), so two databases that are schema-identical still produce files
that differ on hundreds of lines purely because their objects were created in a
different sequence. `diff` cannot see past that. This compares object by
object, so a reordering reports as a reordering and a real difference reports
as a real difference.

Two kinds of ordering are treated as cosmetic and reported separately rather
than as differences:

  * the order objects are scripted in
  * the order columns are declared within a table — same columns, same types,
    different physical position. Changing it requires rebuilding the table, and
    it only matters to `SELECT *` read positionally or `INSERT` without a
    column list, neither of which this codebase does.

Also normalised away: the generation timestamp SSMS stamps into every object
header, and its `CREATE   VIEW` / `CREATE VIEW` spacing, which varies depending
on whether the object was last written by CREATE or CREATE OR ALTER.

Exit code is 0 when the two schemas match (ordering aside) and 1 when they do
not, so it can gate a deploy.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from collections import OrderedDict


OBJECT_HEADER = re.compile(r"/\*+ Object:\s+(\w+)\s+\[([^\]]+)\]\.\[([^\]]+)\]")

# [column_name] [type](len) ... NULL | NOT NULL
COLUMN = re.compile(
    r"^\s*\[(\w+)\]\s+\[(\w+)\](\(([^)]*)\))?"
    r"(\s+IDENTITY\(\d+,\s*\d+\))?"
    r"(.*?)(NOT NULL|NULL)\s*,?\s*$"
)


def normalise(line: str) -> str:
    """Strip the differences that say nothing about the schema."""
    line = line.rstrip()
    line = re.sub(r"Script Date: [0-9/]+ [0-9:]+", "Script Date: <ts>", line)
    # CREATE   VIEW vs CREATE VIEW — an artefact of CREATE OR ALTER, not a change.
    line = re.sub(r"\bCREATE\s+(VIEW|PROCEDURE|TABLE|FUNCTION)\b", r"CREATE \1", line)
    return line


def parse(path: str) -> tuple[OrderedDict, list]:
    """Split a creation script into {(kind, name): [body lines]} plus script order."""
    try:
        with open(path, encoding="utf-8-sig", errors="replace") as handle:
            lines = handle.read().split("\n")
    except OSError as exc:
        sys.exit(f"cannot read {path}: {exc}")

    objects: OrderedDict = OrderedDict()
    order: list = []
    current = None

    for line in lines:
        header = OBJECT_HEADER.search(line)
        if header:
            key = (header.group(1), f"{header.group(2)}.{header.group(3)}")
            current = objects.setdefault(key, [])
            order.append(key)
            continue
        if current is not None:
            current.append(normalise(line))

    if not objects:
        sys.exit(
            f"{path}: no '/****** Object: ... ******/' headers found — is this an "
            "SSMS-generated creation script?"
        )

    return objects, order


def columns(body: list) -> OrderedDict:
    """Column name -> normalised definition, for a CREATE TABLE body."""
    found: OrderedDict = OrderedDict()
    started = False

    for line in body:
        stripped = line.strip()

        if stripped.upper().startswith("CREATE TABLE"):
            started = True
            continue
        if not started:
            continue
        # The column list ends at the first constraint or the closing paren.
        if stripped.upper().startswith(("CONSTRAINT", "PRIMARY KEY", "UNIQUE")) \
                or stripped.startswith(")"):
            break

        match = COLUMN.match(line)
        if match:
            name, sqltype, _, length, identity, extra, nullable = match.groups()
            parts = [sqltype]
            if length:
                parts.append(f"({length})")
            if identity:
                parts.append("IDENTITY")
            parts.append(nullable)
            found[name] = " ".join(parts) + re.sub(r"\s+", " ", extra or "").rstrip()

    return found


def heading(text: str) -> None:
    print()
    print("=" * 74)
    print(text)
    print("=" * 74)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare two SSMS-generated schema creation scripts.",
    )
    parser.add_argument("left", help="first creation script (e.g. dev)")
    parser.add_argument("right", help="second creation script (e.g. prod)")
    parser.add_argument("--left-label", default=None)
    parser.add_argument("--right-label", default=None)
    parser.add_argument(
        "--show-bodies",
        action="store_true",
        help="print a unified diff for every object whose body differs",
    )
    args = parser.parse_args()

    lname = args.left_label or args.left.split("/")[-1].replace("_db_full_creation.sql", "")
    rname = args.right_label or args.right.split("/")[-1].replace("_db_full_creation.sql", "")

    left, lorder = parse(args.left)
    right, rorder = parse(args.right)

    problems = 0

    # ---------------------------------------------------------------- objects
    heading("OBJECT INVENTORY")
    for kind in sorted({k for k, _ in set(left) | set(right)}):
        lset = {n for k, n in left if k == kind}
        rset = {n for k, n in right if k == kind}
        print(f"\n{kind}:  {lname}={len(lset)}  {rname}={len(rset)}")
        for name in sorted(lset - rset):
            problems += 1
            print(f"   only in {lname}: {name}")
        for name in sorted(rset - lset):
            problems += 1
            print(f"   only in {rname}: {name}")
    if problems == 0:
        print("\n   (both scripts contain the same objects)")

    # ---------------------------------------------------------------- columns
    heading("TABLE COLUMNS")
    column_issues = 0
    reordered = []
    for kind, name in sorted(set(left) & set(right)):
        if kind != "Table":
            continue
        lcols, rcols = columns(left[(kind, name)]), columns(right[(kind, name)])

        missing_r = [c for c in lcols if c not in rcols]
        missing_l = [c for c in rcols if c not in lcols]
        changed = [(c, lcols[c], rcols[c]) for c in lcols if c in rcols and lcols[c] != rcols[c]]

        if missing_r or missing_l or changed:
            column_issues += 1
            problems += 1
            print(f"\n{name}")
            for c in missing_r:
                print(f"   only in {lname}: {c}  {lcols[c]}")
            for c in missing_l:
                print(f"   only in {rname}: {c}  {rcols[c]}")
            for c, a, b in changed:
                print(f"   type differs: {c}\n        {lname}: {a}\n        {rname}: {b}")
        elif list(lcols) != list(rcols):
            reordered.append(name)

    if column_issues == 0:
        print("\n   (no column differences)")

    # ------------------------------------------------------------ view / proc
    heading("VIEW AND PROCEDURE BODIES")
    body_issues = 0
    for kind, name in sorted(set(left) & set(right)):
        if kind == "Table":
            continue
        a = [x for x in left[(kind, name)] if x.strip()]
        b = [x for x in right[(kind, name)] if x.strip()]
        if a == b:
            continue
        body_issues += 1
        problems += 1
        print(f"\n{kind} {name}")
        if sorted(a) == sorted(b):
            print("   same statements, different order")
            continue
        diff = list(difflib.unified_diff(a, b, lname, rname, lineterm="", n=1))
        limit = len(diff) if args.show_bodies else 30
        for line in diff[:limit]:
            print("   " + line)
        if len(diff) > limit:
            print(f"   ... {len(diff) - limit} more lines (--show-bodies for all)")

    if body_issues == 0:
        print("\n   (all view and procedure bodies identical)")

    # ---------------------------------------------------------------- summary
    heading("SUMMARY")
    if reordered:
        print(f"\nColumn order differs (cosmetic) in: {', '.join(reordered)}")
        print("   Same columns and types, declared in a different physical order —")
        print("   the result of ALTER TABLE ADD running in a different sequence.")
    if lorder != rorder:
        moved = sum(1 for k in lorder if k in rorder and lorder.index(k) != rorder.index(k))
        print(f"\nScripting order differs (cosmetic): {moved} of {len(lorder)} objects.")
        print("   SSMS scripts by object_id, i.e. creation order.")

    if problems:
        print(f"\nRESULT: {problems} difference(s) that need attention.")
        return 1

    print("\nRESULT: schemas match. Any remaining textual difference is ordering only.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
