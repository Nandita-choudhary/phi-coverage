# Setup steps

Roughly six weeks part-time, in this order. The order matters in two places and is noted where
it does.

---

## Week 1 · Requirements, cloud, data

**Write the user stories first.** Four or five, for a named audience —
[`user-stories.md`](user-stories.md). They decide what the dashboard needs to show, so writing
them later means building the wrong thing and calling it a requirement afterwards.

**Set up Azure SQL.**

- [ ] portal.azure.com → create a free Azure account
- [ ] Create an **Azure SQL Database**, and on the way through apply the **free offer**
- [ ] Set **"behaviour when free limit reached"** to **auto-pause until next month**

That last setting is the whole safety story: on auto-pause the database stops when the monthly
allowance runs out and **cannot bill you**. The other option, "continue for additional charges",
is one-way — you cannot switch back. Given the AWS lesson, pick auto-pause and never think about
it again.

The allowance is 100,000 vCore-seconds and 32 GB per database per month, renewing for the life
of the subscription. This project's data is a few hundred thousand rows; it will not come close.

- [ ] Install Azure Data Studio (Mac-native, free) to write T-SQL against it
- [ ] Put the connection string in `.env` — never in a committed file

**Download the data.** APRA's files cannot be fetched by script from the Claude sandbox or the
desktop workspace; both are behind a network allowlist that blocks apra.gov.au. Download them in
your own browser, into `data/raw/`:

- [ ] [Quarterly Membership and Benefits](https://www.apra.gov.au/quarterly-private-health-insurance-statistics) (~16 MB)
- [ ] Quarterly Membership Trends (~12 MB), from the same page
- [ ] [Annual membership and benefits](https://www.apra.gov.au/news-and-publications/annual-private-health-insurance-statistics) (~17 MB)
- [ ] The glossary PDF, worth having open while you work

Never edit anything in `data/raw/`. It is the untouched source every number traces back to.

**Start on T-SQL.** It is close enough to the SQL you know that the gap is mostly syntax:
`TOP` not `LIMIT`, `GETDATE()`, `ISNULL`, square brackets around names with spaces — which
APRA's column names will have plenty of.

## Weeks 2–3 · Clean it, then prove it

**Map the files before writing any pipeline.**

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python etl/explore.py
```

This opens every sheet and writes a first draft of `docs/data-map.md`. Correct it by hand — the
header-row guesses are guesses. It answers the two questions that decide the project: **is there
an age breakdown, and is the Gold/Silver/Bronze split in there at all?**

Do not plan the dashboard until this is done. If tier is missing, page 3 changes.

**Then clean, check and reconcile** — `load_apra.py`, `checks.py`, `validate.py`. The design of
all three is in [`governance.md`](governance.md). The rules that matter:

- Read from `data/raw/`, never write to it
- One tidy table per measure, each carrying its source file and sheet as columns
- Checks **stop** the load on failure; they do not warn and continue
- Reconciliation compares against published figures with a tolerance, and fails outside it

**The reconciliation table is the single most valuable artefact here.** Finish it before moving
on, and put it in the README.

## Week 4 · T-SQL, dictionary, schedule

**Move the transformations into the database.** Python lands the tidy tables; T-SQL shapes them.
Views for the measures, a stored procedure for the load. This is the part that makes "SQL
Server / T-SQL" on the resume true rather than aspirational.

**Write the data dictionary** as you go — every field, its definition, its source file and sheet.

**Schedule the refresh** — GitHub Actions, see [`automation.md`](automation.md). Note the
obstacle described there: APRA's URLs change every quarter, so the job has to *discover* the new
link rather than have one hardcoded. Hardcode it and the job will quietly reload the same file
forever and report success.

Prove it works before calling it done: run it by hand, then break a check on purpose and watch
it stop. Screenshot both.

## Week 5 · The dashboard

Power BI connects to Azure SQL directly, with scheduled refresh, so the report updates when the
pipeline does. Three pages — see [`powerbi-plan.md`](powerbi-plan.md), which is provisional until
the data map exists.

Windows-only, so this runs on the rented EC2 machine: start it, work, **stop it**.

## Week 6 · Write up and publish

No external review — see [`user-stories.md`](user-stories.md). This week is the write-up.

- [ ] README: screenshots, the reconciliation table in full, a line crediting the prior work
- [ ] A short findings section: what the data shows, with the file and sheet each number
      came from
- [ ] Repo public, report published, links in the README
- [ ] Resume bullets rewritten with the real numbers

Lighter than the other weeks. If weeks 2–4 overran, which they usually do, this is where the
slack is.

---

## Folder layout

```
phi-coverage/
  README.md                      question, prior work, what this adds
  CLAUDE.md                      context and rules for Claude Code
  data/raw/                      APRA spreadsheets, untouched, gitignored
  data/clean/                    tidy CSVs, rebuilt each run, gitignored
  etl/explore.py                 maps the spreadsheets      ← run first
  etl/load_apra.py               raw → tidy
  etl/checks.py                  quality checks; stops on failure
  etl/validate.py                reconciliation vs published figures
  etl/to_azure.py                tidy → Azure SQL
  sql/schema.sql                 tables
  sql/views.sql                  T-SQL measure views
  sql/sp_load_quarter.sql        stored procedure
  .github/workflows/             quarterly refresh
  powerbi/                       the .pbip report
  docs/                          prior work, governance, automation, user stories, data map
```

## What it becomes on your resume

Two bullets, not one — five concepts crammed into a single sentence reads as keyword stuffing:

> Built a self-refreshing quarterly pipeline loading APRA private health insurance data into
> Azure SQL (Python, T-SQL, GitHub Actions), with automated quality checks that reconcile to the
> regulator's published totals and halt the load on mismatch.

> Gathered requirements as user stories for [audience] and analysed coverage and policy-tier
> shifts by age and state in Power BI, reproducing the regulator's published figures.
