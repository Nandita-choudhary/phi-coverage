"""
Quality checks on the tidy tables: run after load_apra.py, before anything is loaded anywhere.

    python etl/checks.py

Each check prints PASS or FAIL with the number behind it. Any failure ends with an error code,
which stops the pipeline: a pipeline that carries on with bad data is worse than none. When
every check passes, the row counts are saved to data/last_load.json, so the next load can be
compared with this one.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
CLEAN = ROOT / "data" / "clean"
LAST_LOAD = ROOT / "data" / "last_load.json"   # committed, so the scheduled run can read it

COUNTS = {                          # the columns that hold counts, per table
    "policies_by_cover": ["policies"],
    "insured_by_age": ["insured_persons"],
    "published_totals": ["hospital_policies", "hospital_insured_persons"],
    "population": ["population"],
}
STATES = 8
# APRA's notes: "ACT figures were included with NSW until 30/09/2009". Until then the
# membership tables have seven states and NSW includes the ACT. Population lists ACT throughout.
ACT_IN_NSW_UNTIL = pd.Timestamp(2009, 9, 30)
MEMBERSHIP_TABLES = {"policies_by_cover", "insured_by_age", "published_totals"}
# APRA's own tables disagree slightly in a few quarters: at most 12 policies (Tasmania, Sep 2012,
# about 0.01%) and 6 people. The check allows 0.05%, which still catches a missing category.
TOLERANCE = 0.0005


def main() -> None:
    parser = argparse.ArgumentParser(description="Quality checks on the tidy tables.")
    parser.add_argument("--clean-dir", type=Path, default=CLEAN,
                        help="where the tidy tables are; tests point this at a broken copy")
    parser.add_argument("--no-record", action="store_true",
                        help="check only; do not update data/last_load.json")
    args = parser.parse_args()

    tables = {name: pd.read_csv(args.clean_dir / f"{name}.csv", parse_dates=["quarter_end"])
              for name in COUNTS}
    results: list[bool] = []

    def report(check: str, ok: bool, detail: str) -> None:
        results.append(ok)
        print(f"{'PASS' if ok else 'FAIL'}  {check:<26}{detail}")

    # 1. Totals add up: our two tables must match APRA's own count from different tables.
    totals = tables["published_totals"].set_index(["quarter_end", "state"])
    for label, table, column, theirs in [
            ("cover types add up", "policies_by_cover", "policies", "hospital_policies"),
            ("age bands add up", "insured_by_age", "insured_persons", "hospital_insured_persons")]:
        ours = tables[table].groupby(["quarter_end", "state"])[column].sum()
        both = pd.concat([ours.rename("ours"), totals[theirs].rename("apra")], axis=1)
        unmatched = both[both.isna().any(axis=1)]
        gaps = (both.ours - both.apra).abs()
        share = (gaps / both.apra).max()
        ok = unmatched.empty and share <= TOLERANCE
        detail = (f"{len(both):,} state-quarters; {int((gaps > 0).sum())} differ, by at most "
                  f"{gaps.max():,.0f} ({share:.3%}; allowed {TOLERANCE:.2%})")
        if not unmatched.empty:
            where = ", ".join(f"{q:%b %Y} {s}" for q, s in unmatched.index[:4])
            detail += f"; {len(unmatched)} not in both tables (e.g. {where})"
        report(label, ok, detail)

    # 2. No empty cells anywhere.
    empty = {name: int(t.isna().sum().sum()) for name, t in tables.items()}
    report("no empty cells", sum(empty.values()) == 0,
           f"{sum(empty.values())} empty cells across {len(tables)} tables")

    # 3. No missing quarter, and every state in every quarter.
    problems = []
    for name, t in tables.items():
        have = pd.DatetimeIndex(sorted(t.quarter_end.unique()))
        missing = pd.date_range(have[0], have[-1], freq="QE").difference(have)
        present = t.groupby("quarter_end").state.apply(set)
        expected = {q: STATES - (1 if name in MEMBERSHIP_TABLES and q <= ACT_IN_NSW_UNTIL else 0)
                    for q in present.index}
        thin = present[[len(s) < expected[q] for q, s in present.items()]]
        if name in MEMBERSHIP_TABLES:
            act_too_early = [q for q, s in present.items() if q <= ACT_IN_NSW_UNTIL and "ACT" in s]
            if act_too_early:
                problems.append(f"{name}: ACT listed separately before Dec 2009, where APRA's notes "
                                f"say it sits inside NSW")
        if len(missing):
            problems.append(f"{name}: {len(missing)} quarters missing")
        if len(thin):
            problems.append(f"{name}: {len(thin)} quarters without all {STATES} states "
                            f"(e.g. {thin.index[0]:%b %Y})")
    first, last = tables["policies_by_cover"].quarter_end.agg(["min", "max"])
    report("no missing quarter", not problems,
           "; ".join(problems) or f"every table runs {first:%b %Y} to {last:%b %Y}, all "
                                   f"{STATES} states (ACT inside NSW until Sep 2009)")

    # 4. No negative counts.
    negative = sum(int((tables[n][c] < 0).sum()) for n, cols in COUNTS.items() for c in cols)
    report("no negative counts", negative == 0, f"{negative} negative values")

    # 5. No table shrank since the last load that passed.
    rows = {name: len(t) for name, t in tables.items()}
    if LAST_LOAD.exists():
        before = json.loads(LAST_LOAD.read_text())["rows"]
        shrank = [f"{n} {before[n]:,} to {rows[n]:,}" for n in rows if rows[n] < before.get(n, 0)]
        report("no table shrank", not shrank,
               "; ".join(shrank) or "every table is at least as long as at the last load")
    else:
        report("no table shrank", True, "first load: nothing to compare with yet")

    if all(results):
        if not args.no_record:
            LAST_LOAD.write_text(json.dumps({"checked_on": date.today().isoformat(),
                                             "latest_quarter": f"{last:%Y-%m-%d}",
                                             "rows": rows}, indent=2) + "\n")
        print(f"\nALL {len(results)} CHECKS PASSED")
    else:
        print(f"\n{results.count(False)} OF {len(results)} CHECKS FAILED: nothing should be loaded")
        sys.exit(1)


if __name__ == "__main__":
    main()
