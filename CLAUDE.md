# Project context for Claude Code

Read this before changing anything in this repo.

## What this is

A portfolio project for data / reporting analyst roles in Australia, aimed especially at health
insurers and health departments. It analyses Australian private health insurance using **real
public data** from APRA, the regulator.

**The two main questions,** equal in weight. Membership is at a record high, so:

1. **Are people downgrading instead of leaving?** Answered from cover type and excess.
2. **Is the pool getting older?** Answered from insured persons by age.

**Written for the general public:** the complete story the headline numbers leave out, with a
twist. The twist must come from APRA's numbers, and anyone who published it first is credited.

**The expected answer, from published sources:** more members, less cover. Verifying that
independently is the point.

## The single most important rule

**This project does not claim discoveries.**

Australian private health insurance is heavily analysed: the ACCC reports on it to the Senate
annually, the Actuaries Institute publishes on the Gold tier, CHOICE tracks the statistics
continuously. Anything found here is already in someone's PDF.

What the project legitimately claims:

1. **Verification** — the published measures, rebuilt from APRA's raw spreadsheets, with a table
   showing ours against theirs
2. **A breakdown nobody publishes** — the same measures split by age and state
3. **Form** — a live dashboard where the existing work is an annual PDF

Read [`docs/prior-work.md`](docs/prior-work.md) before writing any finding. It lists who has
published what, and a table of which claims are allowed.

## Hard rules

- **The data is real.** There is no generator and nothing simulated in this project. If a number
  is needed and the data cannot produce it, say so — never estimate and never fill a gap.
- **`data/raw/` is read-only.** APRA's spreadsheets stay exactly as downloaded. Every figure must
  trace back to a file and sheet in there.
- **Validate before building.** `etl/validate.py` compares computed numbers against published
  ones. It runs before the dashboard, not after.
- **Credit prior work.** Where a result reproduces a published finding, say so and link it.
- **Never commit secrets.** `.env` is gitignored, and the Azure connection string lives in
  GitHub repository secrets for the workflow — never in the YAML, never in a committed file.
- **Checks stop the pipeline.** `etl/checks.py` and `etl/validate.py` exit non-zero on failure
  and nothing loads. A pipeline that carries on with bad data is worse than none.
- **Don't commit the raw spreadsheets** (~45 MB). The README carries the download links so anyone
  can reproduce it.

## Where things stand

| Week | What | Status |
| ---- | ---- | ------ |
| 0 | Questions chosen, prior work surveyed, docs written | Done; questions revised 17 Oct |
| 1 | Files downloaded · Azure SQL created | Files downloaded 17 Oct; Azure SQL not yet |
| 2–3 | Map the spreadsheets · clean · quality checks · reconciliation | Done 17 Oct: loaded, checked, reconciled, series breaks mapped |
| 4 | T-SQL views and stored proc · data dictionary · GitHub Actions schedule | Pending |
| 5 | Power BI report against Azure SQL (EC2) | Pending |
| 6 | Write up findings · README (publishing is Nandita's) | Pending |

**No user stories for an insurer team.** The audience is the public, so the README tells the
story for a general reader.

**No external reviewer.** This is built independently, by choice. Never write that findings were
"presented to a stakeholder" — an unverifiable line undermines the reconciliation table, which
is this project's whole argument.

## The data behind the two questions (checked 17 Oct 2026)

- **Question 1, cover type and excess:** Membership and Benefits → `HTPoliciesXTypeofCover`:
  Year, MonthEnd, State, PolicyCover, ExcessAmount, Value, with two header rows. PolicyCover is
  Full cover · Reduced cover and some lifetime exclusions · Reduced cover but no lifetime
  exclusions · Some lifetime exclusions but no reduced cover. ExcessAmount is Nil · Up to $500
  single · Over $500 single. By state, quarterly, June 2007 to June 2026. It is the ACCC's own
  pair of measures, so it can be reconciled against their published figures.
- **Question 2, age:** Membership Trends → `MembershipByAgeData`. Five tables sit side by side,
  each starting on a different row; hospital cover is the first, `AgeCohort_HT`: Year,
  MonthEnd, State, Gender, Age, InsuredPersons. Age is the start of a five-year band, 0 to 95
  (20 bands). 8 states, both genders, 77 quarters from June 2007 to June 2026.

- **Population by age:** annual file → `Australian population`, table `PopulationAge`: each
  June from 1990, by gender and five-year band. One gap in APRA's table: women 95+, June 2018.
- **Reconciliation:** all five published figures match (`docs/reconciliation.md`). The ACCC's
  "exclusions" means APRA's two lifetime-exclusion categories: 43.84% in June 2018 against the
  ACCC's 44%. "Not full cover" (58.3%) is a wider measure, so never call it "with exclusions".

First look, June quarters, Australia-wide, recomputed from the raw sheets on 17 Oct:

| June | Hospital policies | Full cover | Excess over 500 dollars | Insured persons | Aged 65+ |
| ---- | ----------------- | ---------- | ----------------------- | --------------- | -------- |
| 2007 | 4,368,148 | 63.6% | 5.2% | 9,144,641 | 13.3% |
| 2026 | 6,268,336 | 26.8% | 29.4% | 12,823,752 | 20.9% |

## What the series can claim (checked 17 Oct 2026; evidence in `docs/series-breaks.md`)

- **Full cover is the downgrading measure.** 63.6% of hospital policies in June 2007, 26.8% in
  June 2026: a gradual fall, not broken by the April 2019 reforms. Re-check the latest
  quarter's 1.7-point drop when the next release lands.
- **Never trend the split between lifetime exclusions and reduced cover without exclusions.**
  Policies move between them in one-quarter steps of up to 11.9 points (September 2018), mostly
  unexplained by APRA. Use the split only at a single point in time.
- **Excess:** the nil-excess share is continuous. "Over 500" breaks in September 2010
  (unexplained), then climbs after the 1 April 2019 rule change raised the maximum excess to 750
  dollars single. Mark the rule change on every chart.
- **The pool is ageing faster than Australia:** the 65+ share of insured people went from 13.3%
  to 20.7% (June 2007 to June 2025), against 13.1% to 17.4% for the whole population. Do not
  claim why without published support.
- **Re-run `etl/breaks.py` each release.** A new jump needs an explanation, or it is treated as
  a break and no trend is drawn through it.

## Things that are easy to get wrong

- **Coverage rate, not headcount.** Australia's population grows, so insured persons can rise
  while the share of people covered falls. The honest headline measure is the rate.
- **APRA spreadsheets are built for humans** — multi-row headers, merged cells, footnotes inside
  data rows. Expect the loader to be fiddly, and make it fail loudly rather than drop rows.
- **Definitions change over long series.** Check whether a break in a trend is real or a
  reporting change; APRA notes these, and the glossary PDF is worth having open.
- **apra.gov.au is reachable from Nandita's Mac** (tested 17 Oct 2026), though some cloud
  sandboxes block it. GitHub Actions runners can reach it too, which is why the scheduled
  refresh works there.
- **The ACT sits inside NSW until September 2009** (APRA's notes). NSW's series breaks then.
  For long state comparisons, combine NSW and ACT or start in December 2009. APRA's population
  table does the same (the ACT shows 0 until then), so NSW's coverage rate stays consistent.
- **APRA's sheets have different header depths.** `HTPoliciesXTypeofCover` has two header rows;
  each table inside `MembershipByAgeData` starts on its own row. Find the header by its names,
  never by a fixed row number.
- **APRA's download URLs change every quarter** — both the folder (publication month) and the
  filename (quarter), sometimes with a `_0` suffix. The downloader must discover the current
  link from the page. A hardcoded URL will silently reload the same file forever and report
  success, which is worse than no automation at all.

## The stack, and why

| Piece | Choice | Reason |
| ----- | ------ | ------ |
| Database | **Azure SQL** (free offer, auto-pause) | Microsoft stack is what Australian job ads ask for, and one choice gives both "Azure" and "T-SQL" honestly |
| Transformations | Python lands tidy tables, **T-SQL views** shape them | Makes the T-SQL claim real rather than decorative |
| Schedule | **GitHub Actions** | Free on public repos, and its runners can reach apra.gov.au |
| Dashboard | Power BI against Azure SQL, scheduled refresh | Report updates when the pipeline does |

**Azure billing safety:** the free offer is set to *auto-pause when the free limit is reached*.
The database stops until the next month and cannot bill. Do not switch it to "continue for
additional charges" — that choice cannot be reversed.

## Related

The previous project, `policy-lapse-analytics`, used *simulated* insurance data to demonstrate a
pipeline. This one uses *real* data. They are deliberately a pair: one shows the mechanism, the
other shows it holds up against published reality. Reuse its `powerbi/theme.json` so both look
like one body of work.
