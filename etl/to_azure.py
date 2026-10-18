"""
The checked tidy tables into Azure SQL.

    python etl/to_azure.py --init       # first time: create schemas, tables, procedure, views
    python etl/to_azure.py              # each load: fill stage, then swap it into phi
    python etl/to_azure.py --dry-run    # check the tidy tables are ready, without connecting

Run it only after checks.py and validate.py have passed. It empties and fills the stage
tables, then calls phi.sp_load_quarter, which replaces the phi tables in one transaction: if
anything fails, the database is left exactly as it was and Power BI keeps the last good load.

The connection string is AZURE_SQL_URL: in .env on the Mac and a repository secret on GitHub,
never in a committed file.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

from download import log_change

ROOT = Path(__file__).resolve().parent.parent
CLEAN = ROOT / "data" / "clean"
SQL = ROOT / "sql"
INIT_FILES = ["schema.sql", "sp_load_quarter.sql", "views.sql"]    # in this order
COLUMNS = {   # each tidy table, with its columns in the order the database expects
    "policies_by_cover": ["quarter_end", "state", "policy_cover", "excess", "policies",
                          "source_file", "source_sheet"],
    "insured_by_age": ["quarter_end", "state", "gender", "age_band_start", "age_band",
                       "insured_persons", "source_file", "source_sheet"],
    "published_totals": ["quarter_end", "state", "hospital_policies", "hospital_insured_persons",
                         "source_file", "source_sheet"],
    "population": ["quarter_end", "state", "population", "source_file", "source_sheet"],
    "population_by_age": ["quarter_end", "gender", "age_band_start", "age_band", "population",
                          "source_file", "source_sheet"],
}
MAX_PARAMETERS = 2100     # SQL Server's limit on parameters in a single statement
WAKE_TRIES, WAKE_WAIT = 8, 20   # a paused free database takes a minute or two to resume


def tidy_tables() -> dict[str, pd.DataFrame]:
    """Read every tidy table, or stop if one is missing, empty or short of a column."""
    tables = {}
    for name, columns in COLUMNS.items():
        path = CLEAN / f"{name}.csv"
        if not path.exists():
            sys.exit(f"LOAD STOPPED: data/clean/{name}.csv is missing. Run load_apra.py, "
                     f"checks.py and validate.py first.")
        df = pd.read_csv(path)
        missing = sorted(set(columns) - set(df.columns))
        if df.empty or missing:
            sys.exit(f"LOAD STOPPED: {name} is empty or lacks {missing}.")
        tables[name] = df[columns]
    return tables


def connect():
    load_dotenv(ROOT / ".env")
    url = os.environ.get("AZURE_SQL_URL")
    if not url:
        sys.exit("LOAD STOPPED: no AZURE_SQL_URL. Put it in .env (see .env.example) on the Mac, "
                 "or in the repository secret on GitHub.")
    from sqlalchemy import create_engine
    return create_engine(url)


def wake(engine) -> None:
    """The free database pauses when idle, and refuses the first connection with error 40613
    while it resumes. Knock, wait and try again before doing any real work."""
    for attempt in range(1, WAKE_TRIES + 1):
        try:
            with engine.connect() as conn:
                conn.exec_driver_sql("SELECT 1")
            return
        except Exception as problem:
            if "40613" not in str(problem) or attempt == WAKE_TRIES:
                raise
            print(f"the database is waking up (try {attempt} of {WAKE_TRIES}); "
                  f"trying again in {WAKE_WAIT} seconds")
            time.sleep(WAKE_WAIT)


def batches(sql_text: str) -> list[str]:
    """Split a .sql file on its GO lines, the way SQL Server's own tools do."""
    parts = re.split(r"^\s*GO\s*$", sql_text, flags=re.MULTILINE | re.IGNORECASE)
    return [part.strip() for part in parts if part.strip()]


def init(engine) -> None:
    with engine.begin() as conn:
        for name in INIT_FILES:
            for batch in batches((SQL / name).read_text()):
                conn.exec_driver_sql(batch)
            print(f"ran sql/{name}")


def load(engine, tables: dict[str, pd.DataFrame]) -> int:
    """Empty stage, fill it, then let the procedure swap it into phi in one transaction."""
    with engine.begin() as conn:
        for name in COLUMNS:
            conn.exec_driver_sql(f"TRUNCATE TABLE stage.{name}")
    for name, df in tables.items():
        rows_per_insert = MAX_PARAMETERS // len(df.columns) - 1
        df.to_sql(name, engine, schema="stage", if_exists="append", index=False,
                  method="multi", chunksize=rows_per_insert)
        print(f"staged  {name:<20}{len(df):>8,} rows")
    note = f"Loaded by to_azure.py from {tables['policies_by_cover'].source_file.iat[0]}"
    with engine.begin() as conn:
        conn.exec_driver_sql("EXEC phi.sp_load_quarter @note = %s", (note[:400],))
    return sum(len(df) for df in tables.values())


def main() -> None:
    parser = argparse.ArgumentParser(description="Load the checked tidy tables into Azure SQL.")
    parser.add_argument("--init", action="store_true",
                        help="first create the schemas, tables, procedure and views (drops tables)")
    parser.add_argument("--dry-run", action="store_true",
                        help="check the tidy tables are ready; do not connect")
    args = parser.parse_args()

    tables = tidy_tables()
    if args.dry_run:
        for name, df in tables.items():
            print(f"ready   {name:<20}{len(df):>8,} rows")
        print("DRY RUN: nothing sent to Azure")
        return

    engine = connect()
    try:
        wake(engine)
        if args.init:
            init(engine)
        total = load(engine, tables)
    except Exception as problem:     # any database error: phi is untouched
        sys.exit(f"LOAD STOPPED: {type(problem).__name__}: {problem}")
    latest = tables["policies_by_cover"].quarter_end.max()
    log_change(f"Loaded into Azure SQL: {total:,} rows in {len(tables)} tables, latest quarter "
               f"{latest}.")
    print(f"LOADED {total:,} rows; phi now holds the release to {latest}")


if __name__ == "__main__":
    main()
