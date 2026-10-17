"""
Reconciliation: rebuild figures that others have published, and compare.

    python etl/validate.py

Each figure below was published by the ACCC, by APRA itself or by CHOICE. It is rebuilt here
from the tidy tables and must match at the precision it was published: a figure published as
44% matches anything from 43.5% to 44.5%. Any miss ends with an error code, which stops the
pipeline. The finished table is written to docs/reconciliation.md for the README.

A miss is not automatically a bug: two sources can define a measure differently. When that
happens, work out which it is and write it down in the figure's note.
"""

from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
CLEAN = ROOT / "data" / "clean"
OUT = ROOT / "docs" / "reconciliation.md"
TABLES = {name: pd.read_csv(CLEAN / f"{name}.csv", parse_dates=["quarter_end"])
          for name in ["policies_by_cover", "insured_by_age", "population", "population_by_age"]}
LIFETIME_EXCLUSIONS = ["Reduced cover and some lifetime exclusions",
                       "Some lifetime exclusions but no reduced cover"]


def at(table: str, quarter: str) -> pd.DataFrame:
    rows = TABLES[table][TABLES[table].quarter_end == pd.Timestamp(quarter)]
    if rows.empty:
        sys.exit(f"VALIDATION STOPPED: {table} has no rows for {quarter}.")
    return rows


def with_lifetime_exclusions(quarter: str) -> float:
    c = at("policies_by_cover", quarter)
    return 100 * c[c.policy_cover.isin(LIFETIME_EXCLUSIONS)].policies.sum() / c.policies.sum()


def with_an_excess(quarter: str) -> float:
    c = at("policies_by_cover", quarter)
    return 100 * c[c.excess != "Nil"].policies.sum() / c.policies.sum()


def hospital_cover(quarter: str) -> float:
    return 100 * (at("insured_by_age", quarter).insured_persons.sum()
                  / at("population", quarter).population.sum())


def hospital_cover_at_age(quarter: str, band_start: int) -> float:
    insured, people = at("insured_by_age", quarter), at("population_by_age", quarter)
    return 100 * (insured[insured.age_band_start == band_start].insured_persons.sum()
                  / people[people.age_band_start == band_start].population.sum())


# measure, published value, decimals it was published to, source, our figure, note
FIGURES = [
    ("Hospital policies with exclusions, June 2018", 44, 0,
     "ACCC, report to the Senate on private health insurance, 2017–18",
     lambda: with_lifetime_exclusions("2018-06-30"),
     "Ours counts APRA's two lifetime-exclusion categories. \"Not full cover\" (58.3%) is a wider "
     "measure: it also counts reduced cover without exclusions."),
    ("Hospital policies with an excess or co-payment, June 2018", 84, 0,
     "ACCC, report to the Senate on private health insurance, 2017–18",
     lambda: with_an_excess("2018-06-30"),
     "APRA records excess levels only, so co-payments are not in ours."),
    ("Hospital cover, share of population, June 2025", 45.39, 2,
     "APRA, Quarterly Membership Coverage, June 2026 release, table T1",
     lambda: hospital_cover("2025-06-30"),
     "The regulator's own figure, rebuilt from its raw tables."),
    ("Hospital cover, share of population, December 2025", 45.6, 1,
     "CHOICE, private health insurance statistics, citing APRA",
     lambda: hospital_cover("2025-12-31"),
     "CHOICE does not name the quarter; December 2025 is the quarter of its other figures."),
    ("Hospital cover at ages 25–29, June 2025", 26.3, 1,
     "CHOICE, private health insurance statistics, citing APRA",
     lambda: hospital_cover_at_age("2025-06-30", 25),
     "Insured people aged 25–29 over the population aged 25–29."),
]


def main() -> None:
    rows, misses = [], 0
    for measure, published, decimals, source, ours_fn, note in FIGURES:
        ours = ours_fn()
        match = abs(ours - published) <= 0.5 * 10 ** -decimals + 1e-9
        misses += not match
        rows.append((measure, f"{published:.{decimals}f}%", source, f"{ours:.{decimals + 2}f}%",
                     f"{ours - published:+.{decimals + 2}f}", "Yes" if match else "**No**", note))
        print(f"{'MATCH' if match else 'MISS '}  {measure:<58} published {published:.{decimals}f}%"
              f"  ours {ours:.{decimals + 2}f}%")

    release = TABLES["policies_by_cover"].source_file.iat[0]
    lines = ["# Reconciliation", "",
             f"Written by `etl/validate.py` on {date.today():%d %B %Y}, from APRA's files starting "
             f"with \"{release}\".", "",
             "Every figure here was published by someone else, then rebuilt from APRA's raw "
             "spreadsheets. A figure matches when ours rounds to it at the precision it was "
             "published.", "",
             "| Measure | Published | Source | Ours | Difference | Match |",
             "| ------- | --------- | ------ | ---- | ---------- | ----- |"]
    lines += [f"| {m} | {p} | {s} | {o} | {d} | {ok} |" for m, p, s, o, d, ok, _ in rows]
    lines += ["", "## Notes", ""] + [f"- **{m}:** {n}" for m, *_, n in rows] + [""]
    OUT.write_text("\n".join(lines))
    print(f"\nWrote {OUT.relative_to(ROOT) if ROOT in OUT.parents else OUT}")

    if misses:
        print(f"{misses} OF {len(rows)} FIGURES DID NOT MATCH: nothing should be loaded")
        sys.exit(1)
    print(f"ALL {len(rows)} PUBLISHED FIGURES MATCH")


if __name__ == "__main__":
    main()
