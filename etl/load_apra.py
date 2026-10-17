"""
APRA's raw spreadsheets into tidy tables, one per measure.

    python etl/load_apra.py

Reads data/raw/ and never writes there. Writes data/clean/*.csv, rebuilt on every run. Each
table answers one of the project's two questions:

    policies_by_cover.csv   1. Are people downgrading instead of leaving?
                               Hospital policies by cover type and excess, state and quarter.
    insured_by_age.csv      2. Is the pool getting older?
                               People with hospital cover by age band, gender, state, quarter.

Three more tables support them: published_totals.csv, APRA's own totals of hospital policies
and insured persons, which checks.py compares the first two against; population.csv, by state
and quarter; and population_by_age.csv, by age band each June, for coverage rates by age.

APRA builds these sheets for people to read, not machines. So the loader finds every header by
its names, never by a fixed row number, and it stops with an error rather than skip a row it
cannot read. Every row carries the file and sheet it came from, so any number can be traced
back to a cell APRA published.
"""

from __future__ import annotations

import re
import sys
from datetime import date
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
CLEAN = ROOT / "data" / "clean"

# APRA's file names change every quarter ("... June 2026_0.xlsx"), so files are found by pattern.
COVER_FILE = "Quarterly Private Health Insurance Membership and Benefits *.xlsx"
COVER_SHEET = "HTPoliciesXTypeofCover"
AGE_FILE = "Quarterly Private Health Insurance Membership Trends *.xlsx"
AGE_SHEET = "MembershipByAgeData"
AGE_TABLE = "AgeCohort_HT"          # hospital cover; the sheet holds five tables side by side
TOTALS_SHEET = "MembershipData"     # also in the Membership Trends file
# APRA's own count of hospital cover, from tables other than the two above: hospital cover sold
# on its own, and combined with extras. checks.py compares totals against these. (The sheet's
# "HistoricalPolicies&Persons" table looks like the obvious source, but it stops in 2007.)
TOTALS_TABLES = ("HTOnly", "HTandGTCombined")
POPULATION_TABLE = "PopulationState"          # state population, for coverage rates
FIRST_QUARTER = date(2007, 6, 30)   # the cover-type and age series start here, so all tables do
ACT_IN_NSW_UNTIL = date(2009, 9, 30)  # APRA's notes: the ACT is counted inside NSW until then
ANNUAL_FILE = "Annual private health insurance membership and benefits statistics - *.xlsx"
POP_AGE_SHEET = "Australian population"
POP_AGE_TABLE = "PopulationAge"     # population by gender and five-year age band, each June

# The categories APRA uses today. Anything new means APRA changed the file: stop and look.
POLICY_COVER = {"Full cover", "Reduced cover and some lifetime exclusions",
                "Reduced cover but no lifetime exclusions",
                "Some lifetime exclusions but no reduced cover"}
EXCESS = {"Nil", "Up to $500 single", "Over $500 single"}
STATES = {"NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"}
GENDERS = {"M", "F"}
QUARTER_MONTHS = {"Mar": 3, "Jun": 6, "Sep": 9, "Dec": 12}
AGE_STARTS = set(range(0, 100, 5))  # APRA glossary: 0-4, 5-9 ... 90-94, then 95+

# Known quirks in APRA's own files. Each is fixed narrowly and announced on every run; any
# other oddity still stops the load. Found 17 Oct 2026: in the Dec 2021 quarter, every
# state's "Full cover, Nil" policy count ends in .1 (197,506.1 in NSW). A count of policies
# cannot be a fraction, so those eight cells are rounded.
FRACTIONAL_QUIRK = {"Year": 2021, "MonthEnd": "Dec", "PolicyCover": "Full cover",
                    "ExcessAmount": "Nil"}


class LoadError(Exception):
    """The file is not shaped the way the loader expects. Stop rather than guess."""


def period_of(name: str) -> tuple[int, int]:
    """The (year, month) a file covers, read from its name: "... June 2026_0.xlsx" is a quarter,
    "... - 2024-2025 (2).xlsx" a financial year ending in June. download.py uses this too."""
    quarter = re.search(r"(March|June|September|December) (\d{4})", name)
    if quarter:
        months = {"March": 3, "June": 6, "September": 9, "December": 12}
        return int(quarter.group(2)), months[quarter.group(1)]
    year = re.search(r"\d{4}-(\d{4})", name)
    if year:
        return int(year.group(1)), 6
    raise LoadError(f"Cannot read the period from the file name '{name}'.")


def latest_file(pattern: str) -> Path:
    """The newest file for this pattern, judged by the period in its name, because APRA's names
    change every release and old ones may still be in data/raw."""
    files = list(RAW.glob(pattern))
    if not files:
        raise LoadError(f"No file in data/raw matches '{pattern}'. Download it first.")
    return max(files, key=lambda path: period_of(path.name))


def find_header(block: pd.DataFrame, names: list[str]) -> int:
    """The first row whose cells are exactly these column names, in order."""
    for i in range(min(30, len(block))):
        if [str(v).strip() for v in block.iloc[i, :len(names)]] == names:
            return i
    raise LoadError(f"No header row {names} in the first 30 rows.")


def rows_under(block: pd.DataFrame, header_row: int) -> pd.DataFrame:
    """The data rows under a header. APRA repeats the header straight after it (display names
    under internal names), so those rows are skipped; empty rows are allowed only at the end.
    Any other row that is not data stops the load."""
    rows = block.iloc[header_row + 1:]
    while len(rows) and str(rows.iloc[0, 0]).strip() == "Year":
        rows = rows.iloc[1:]
    empty = rows.isna().all(axis=1).to_numpy()
    if empty.any():
        first = int(empty.argmax())
        if not empty[first:].all():
            raise LoadError(f"An empty row sits inside the data at Excel row {rows.index[first] + 1}.")
        rows = rows.iloc[:first]
    years = pd.to_numeric(rows.iloc[:, 0], errors="coerce")
    if years.isna().any():
        bad = [i + 1 for i in rows.index[years.isna()][:5]]
        raise LoadError(f"Rows that are not data, at Excel rows {bad}.")
    return rows


def table_in_sheet(raw: pd.DataFrame, table: str, names: list[str]) -> pd.DataFrame:
    """One table out of a sheet that holds several side by side, found by the name above it."""
    spots = [c for c in range(raw.shape[1]) for r in range(5) if str(raw.iat[r, c]).strip() == table]
    if len(spots) != 1:
        raise LoadError(f"Expected one '{table}' table, found {len(spots)}.")
    block = raw.iloc[:, spots[0]:spots[0] + len(names)]
    body = rows_under(block, find_header(block, names))
    body.columns = names
    return body


def only(values: pd.Series, allowed: set, what: str) -> pd.Series:
    unknown = set(values.unique()) - allowed
    if unknown:
        raise LoadError(f"New {what} values {sorted(map(str, unknown))}: APRA changed the file.")
    return values


def counts(values: pd.Series, what: str) -> pd.Series:
    """Whole numbers, or stop. Negative numbers are kept: checks.py is where they get caught."""
    numbers = pd.to_numeric(values, errors="coerce")
    if numbers.isna().any() or (numbers % 1 != 0).any():
        raise LoadError(f"{what} has empty or fractional values.")
    return numbers.astype("int64")


def quarter_end(years: pd.Series, months: pd.Series) -> list[date]:
    return [(pd.Timestamp(int(y), QUARTER_MONTHS[m], 1) + pd.offsets.MonthEnd(0)).date()
            for y, m in zip(years, months)]


def load_cover() -> pd.DataFrame:
    """Question 1: hospital policies by cover type and excess level."""
    path = latest_file(COVER_FILE)
    raw = pd.read_excel(path, sheet_name=COVER_SHEET, header=None)
    names = ["Year", "MonthEnd", "State", "PolicyCover", "ExcessAmount", "Value"]
    body = rows_under(raw.iloc[:, :len(names)], find_header(raw, names))
    body.columns = names
    value = pd.to_numeric(body.Value, errors="coerce")
    quirk = (value % 1 != 0) & pd.concat(
        [pd.to_numeric(body[k], errors="coerce") == v if k == "Year" else body[k] == v
         for k, v in FRACTIONAL_QUIRK.items()], axis=1).all(axis=1)
    if quirk.any():
        print(f"Note: {quirk.sum()} policy counts in APRA's Dec 2021 'Full cover, Nil' rows end "
              f"in .1; rounded to whole policies (a known quirk in the source file).")
        value = value.where(~quirk, value.round())
    return pd.DataFrame({
        "quarter_end": quarter_end(body.Year, only(body.MonthEnd, set(QUARTER_MONTHS), "MonthEnd")),
        "state": only(body.State, STATES, "State"),
        "policy_cover": only(body.PolicyCover, POLICY_COVER, "PolicyCover"),
        "excess": only(body.ExcessAmount, EXCESS, "ExcessAmount"),
        "policies": counts(value, "Value"),
        "source_file": path.name,
        "source_sheet": COVER_SHEET,
    })


def load_age() -> pd.DataFrame:
    """Question 2: people with hospital cover by five-year age band and gender."""
    path = latest_file(AGE_FILE)
    raw = pd.read_excel(path, sheet_name=AGE_SHEET, header=None)
    body = table_in_sheet(raw, AGE_TABLE, ["Year", "MonthEnd", "State", "Gender", "Age",
                                           "InsuredPersons"])
    ages = only(counts(body.Age, "Age"), AGE_STARTS, "Age")
    return pd.DataFrame({
        "quarter_end": quarter_end(body.Year, only(body.MonthEnd, set(QUARTER_MONTHS), "MonthEnd")),
        "state": only(body.State, STATES, "State"),
        "gender": only(body.Gender, GENDERS, "Gender"),
        "age_band_start": ages,
        "age_band": ["95+" if a == 95 else f"{a}-{a + 4}" for a in ages],
        "insured_persons": counts(body.InsuredPersons, "InsuredPersons"),
        "source_file": path.name,
        "source_sheet": f"{AGE_SHEET} ({AGE_TABLE})",
    })


def from_first_quarter(body: pd.DataFrame) -> pd.DataFrame:
    """Add quarter_end and keep June 2007 on. These tables pad MonthEnd with spaces ('Mar   ')."""
    months = only(body.MonthEnd.astype(str).str.strip(), set(QUARTER_MONTHS), "MonthEnd")
    body = body.assign(quarter_end=quarter_end(body.Year, months))
    return body[body.quarter_end >= FIRST_QUARTER]


def load_totals_and_population() -> tuple[pd.DataFrame, pd.DataFrame]:
    """APRA's own published totals, for checks.py to compare against, and state population."""
    path = latest_file(AGE_FILE)
    raw = pd.read_excel(path, sheet_name=TOTALS_SHEET, header=None)
    names = ["Year", "MonthEnd", "State", "Coverage", "ExclusionaryPolicy", "ExcessPolicy",
             "PolicyCategory", "Value"]
    parts = []
    for table in TOTALS_TABLES:
        b = from_first_quarter(table_in_sheet(raw, table, names))
        parts.append(pd.DataFrame({
            "quarter_end": b.quarter_end,
            "state": only(b.State, STATES, "State"),
            "coverage": only(b.Coverage.astype(str).str.strip(), {"Policies", "Insured persons"},
                             "Coverage"),
            "value": counts(b.Value, f"{table} Value"),
        }))
    wide = pd.concat(parts).pivot_table(index=["quarter_end", "state"], columns="coverage",
                                        values="value", aggfunc="sum").reset_index()
    totals = pd.DataFrame({
        "quarter_end": wide.quarter_end,
        "state": wide.state,
        "hospital_policies": wide["Policies"].astype("int64"),
        "hospital_insured_persons": wide["Insured persons"].astype("int64"),
        "source_file": path.name,
        "source_sheet": f"{TOTALS_SHEET} ({' + '.join(TOTALS_TABLES)})",
    })
    p = from_first_quarter(table_in_sheet(raw, POPULATION_TABLE,
                                          ["Year", "MonthEnd", "StateShortName", "Population"]))
    # Like the membership tables, APRA's population counts the ACT inside NSW until Sep 2009:
    # the ACT shows 0 and NSW includes it. Those zero rows are dropped; any other zero stops.
    p = p.assign(Population=counts(p.Population, "Population"))
    act_in_nsw = (p.StateShortName == "ACT") & (p.quarter_end <= ACT_IN_NSW_UNTIL) & (p.Population == 0)
    if ((p.Population == 0) & ~act_in_nsw).any():
        raise LoadError("A population of zero outside the ACT-inside-NSW years.")
    p = p[~act_in_nsw]
    population = pd.DataFrame({
        "quarter_end": p.quarter_end,
        "state": only(p.StateShortName, STATES, "StateShortName"),
        "population": p.Population,
        "source_file": path.name,
        "source_sheet": f"{TOTALS_SHEET} ({POPULATION_TABLE})",
    })
    return totals, population


def load_population_by_age() -> pd.DataFrame:
    """Australia's population by gender and five-year age band each June, from APRA's annual
    file. Same shape as insured_by_age, so coverage can be worked out by age and gender. (The
    sheet also holds an unnamed table of fractional estimates by age; this is not that one.)"""
    path = latest_file(ANNUAL_FILE)
    raw = pd.read_excel(path, sheet_name=POP_AGE_SHEET, header=None)
    b = from_first_quarter(table_in_sheet(raw, POP_AGE_TABLE,
                                          ["Year", "MonthEnd", "Gender", "Age", "Value"]))
    starts = only(counts(b.Age, "Age"), AGE_STARTS, "Age")
    return pd.DataFrame({
        "quarter_end": b.quarter_end,
        "gender": only(b.Gender, GENDERS, "Gender"),
        "age_band_start": starts,
        "age_band": ["95+" if a == 95 else f"{a}-{a + 4}" for a in starts],
        "population": counts(b.Value, "Value"),
        "source_file": path.name,
        "source_sheet": f"{POP_AGE_SHEET} ({POP_AGE_TABLE})",
    })


def main() -> None:
    try:
        totals, population = load_totals_and_population()
        tables = {"policies_by_cover": load_cover(), "insured_by_age": load_age(),
                  "published_totals": totals, "population": population,
                  "population_by_age": load_population_by_age()}
    except LoadError as problem:
        sys.exit(f"LOAD STOPPED: {problem}")

    empty = [name for name, df in tables.items() if df.empty]
    if empty:
        sys.exit(f"LOAD STOPPED: {', '.join(empty)} came out empty. Check the sheet and FIRST_QUARTER.")

    CLEAN.mkdir(parents=True, exist_ok=True)
    for name, df in tables.items():
        df.to_csv(CLEAN / f"{name}.csv", index=False)
        quarters = sorted(df.quarter_end.unique())
        print(f"{name + '.csv':<24}{len(df):>8,} rows · {len(quarters)} quarters, "
              f"{quarters[0]:%b %Y} to {quarters[-1]:%b %Y} · {df.source_file.iat[0]} → "
              f"{df.source_sheet.iat[0]}")

    # Two figures per table, to compare by eye with the numbers already checked by hand.
    cover, age = tables["policies_by_cover"], tables["insured_by_age"]
    print("\nCheck figures, June quarters, Australia:")
    for year in (2007, 2026):
        june = date(year, 6, 30)
        c = cover[cover.quarter_end == june]
        a = age[age.quarter_end == june]
        print(f"  {year}: {c.policies.sum():>10,} hospital policies, "
              f"{c[c.policy_cover == 'Full cover'].policies.sum() / c.policies.sum():.1%} full cover · "
              f"{a.insured_persons.sum():>11,} insured persons, "
              f"{a[a.age_band_start >= 65].insured_persons.sum() / a.insured_persons.sum():.1%} aged 65+")


if __name__ == "__main__":
    main()
