# More Members, Less Cover?

**Australian private health insurance membership is at a record high. So is the system healthy?**

This project rebuilds the answer from APRA's own published data, the regulator's quarterly
private health insurance statistics, and asks what the headline number hides: *who* is insured,
and *what* they are actually covered for.

> **Status: built.** Every figure below is generated from APRA's data by `etl/findings.py`, which
> also writes [`docs/findings.md`](docs/findings.md): every figure with its unit and its period.
> A check fails the build if a number anywhere in this repo was typed instead.

---

## The question

Membership has reached a record. Two things could still be going wrong underneath it, and neither
shows up in a headcount:

1. **Are people downgrading instead of leaving?** Under cost pressure people do not always
   cancel. They move to policies with reduced cover, exclusions and a higher excess: the same
   member, a thinner product, and a headcount cannot see it.
2. **Is the pool getting older?** If the young thin out while the old keep joining, the risk
   pool worsens even as the total grows.

Either would mean the record membership figure tells a flattering story about a market that is
getting worse. The report is written for the general public, the complete story behind a
headline number. [`docs/user-stories.md`](docs/user-stories.md) names the professional audience
the same measures serve, and which questions the data cannot answer for them.

## What is already known

This market is heavily analysed. The ACCC reports on it to the Senate every year; the Actuaries
Institute publishes on it; CHOICE and APRA publish regular statistics. **Nothing here is a
discovery, and the project does not claim one.** [`docs/prior-work.md`](docs/prior-work.md)
lists who has published what, and exactly what this project claims.

The published figures this project set out to reproduce, against what it got when it rebuilt
them from APRA's raw files:

<!-- findings:reconciliation -->
| Measure | Published | Rebuilt | Source | Match |
| ------- | --------- | ------- | ------ | ----- |
| Hospital policies with exclusions, June 2018 | 44% | 43.84% | ACCC | Yes |
| Hospital policies with an excess or co-payment, June 2018 | 84% | 83.60% | ACCC | Yes |
| Hospital cover, share of population, June 2025 | 45.39% | 45.3923% | APRA | Yes |
| Hospital cover, share of population, December 2025 | 45.6% | 45.648% | CHOICE | Yes |
| Hospital cover at ages 25–29, June 2025 | 26.3% | 26.258% | CHOICE | Yes |
<!-- /findings:reconciliation -->

So the expected answer is **more members, thinner cover**. The job of this project is not to
announce that. It is to verify it independently and add what the published work leaves out.

### What the raw data holds

APRA does **not** publish the Gold, Silver, Bronze and Basic tiers; the only "Gold" in the files
is the veterans' DVA Gold Card, which is something else entirely. What it does publish is better
for this question: **cover type and excess level, quarterly, by state, back to 2007**. Tiers only
exist from 2019, so this is nineteen years instead of seven, and it is the ACCC's own pair of
measures. For the second question it publishes insured people by five-year age band each quarter,
and Australia's population by age each June.

## What the data shows

<!-- findings:release -->
APRA data from June 2007 to June 2026; population by age is annual, to June 2025.
<!-- /findings:release -->

### The headline

<!-- findings:headline -->
| Figure | Value | Period | Kind |
| ------ | ----- | ------ | ---- |
| People with hospital cover | 12,823,752 people | as at 30 June 2026 | stock |
| People with hospital cover | 9,144,641 people | as at 30 June 2007 | stock |
| People with hospital cover, growth | +40.2% | 30 June 2007 to 30 June 2026 | growth |
| People with hospital cover, change on a year earlier | +292,743 people | year to 30 June 2026 | change |
| Australia's population, growth | +34.4% | 30 June 2007 to 30 June 2026 | growth |
| Share of Australians with hospital cover | 45.8% | as at 30 June 2026 | share |
| Share of Australians with hospital cover, peak | 47.4% | as at 30 June 2015 | share |
| Share of Australians with hospital cover, low since the peak | 43.7% | as at 30 June 2020 | share |
| Hospital policies | 6,268,336 policies | as at 30 June 2026 | stock |
| Hospital policies, growth | +43.5% | 30 June 2007 to 30 June 2026 | growth |

Kind: *stock*: a quantity counted at the end of the quarter named, such as people or policies; *share*: one stock as a percentage of another at the same date; *gap*: the difference between two shares at the same date, in percentage points; *change*: the difference between the two dates named, in the unit shown; *growth*: the percentage change between the two dates named; *count*: a tally of items in one of this project's own tables, such as age bands or checked figures.
<!-- /findings:headline -->

### Downgrading

<!-- findings:downgrading -->
| Figure | Value | Period | Kind |
| ------ | ----- | ------ | ---- |
| Hospital policies with full cover | 63.6% | as at 30 June 2007 | share |
| Hospital policies with full cover | 26.8% | as at 30 June 2026 | share |
| Hospital policies with full cover, change | -36.8 points | 30 June 2007 to 30 June 2026 | change |
| Hospital policies with an excess over $500 (single) | 0.5% | as at 31 March 2019 | share |
| Hospital policies with an excess over $500 (single) | 29.4% | as at 30 June 2026 | share |
| Hospital policies with full cover, lowest state (WA) | 23.1% | as at 30 June 2026 | share |
| Hospital policies with full cover, highest state (TAS) | 38.7% | as at 30 June 2026 | share |

| State | Full cover | Against Australia |
| ----- | ---------- | ----------------- |
| WA | 23.1% | -3.7 points |
| VIC | 23.7% | -3.1 points |
| ACT | 24.1% | -2.8 points |
| QLD | 27.0% | +0.2 points |
| NSW | 28.1% | +1.3 points |
| NT | 32.0% | +5.2 points |
| SA | 34.8% | +8.0 points |
| TAS | 38.7% | +11.9 points |
<!-- /findings:downgrading -->

### An older pool

<!-- findings:ageing -->
| Figure | Value | Period | Kind |
| ------ | ----- | ------ | ---- |
| Aged 65 and over, share of insured people | 13.3% | as at 30 June 2007 | share |
| Aged 65 and over, share of insured people | 20.7% | as at 30 June 2025 | share |
| Aged 65 and over, share of all Australians | 13.1% | as at 30 June 2007 | share |
| Aged 65 and over, share of all Australians | 17.4% | as at 30 June 2025 | share |
| Aged 65 and over: insured share minus Australia's share | 0.2 points | as at 30 June 2007 | gap |
| Aged 65 and over: insured share minus Australia's share | 3.3 points | as at 30 June 2025 | gap |
| Coverage rise, largest age band (85-89) | +18.9 points | 30 June 2007 to 30 June 2025 | change |
| Age bands whose coverage fell | 6 of 20 bands | 30 June 2007 to 30 June 2025 | count |

| Population, June | Under 25 | 25 to 49 | 50 to 64 | 65 and over |
| ---------------- | -------- | -------- | -------- | ----------- |
| Insured people, June 2007 | 29.7% | 34.5% | 22.5% | 13.3% |
| Insured people, June 2025 | 27.4% | 32.3% | 19.6% | 20.7% |
| All Australians, June 2007 | 33.4% | 35.8% | 17.7% | 13.1% |
| All Australians, June 2025 | 30.2% | 35.0% | 17.3% | 17.4% |

| Age band | Coverage, first to latest June |
| -------- | ------------------------------ |
| 0-4 | 38.3% to 36.7% (-1.7 points) |
| 5-9 | 40.3% to 44.8% (+4.4 points) |
| 10-14 | 42.1% to 47.0% (+4.9 points) |
| 15-19 | 43.9% to 45.4% (+1.5 points) |
| 20-24 | 31.5% to 31.7% (+0.2 points) |
| 25-29 | 29.0% to 26.3% (-2.7 points) |
| 30-34 | 40.3% to 36.7% (-3.6 points) |
| 35-39 | 44.3% to 45.4% (+1.1 points) |
| 40-44 | 46.4% to 50.1% (+3.7 points) |
| 45-49 | 50.5% to 52.9% (+2.4 points) |
| 50-54 | 54.6% to 50.6% (-3.9 points) |
| 55-59 | 57.5% to 52.2% (-5.3 points) |
| 60-64 | 55.7% to 50.7% (-4.9 points) |
| 65-69 | 50.8% to 53.2% (+2.3 points) |
| 70-74 | 46.1% to 55.1% (+9.0 points) |
| 75-79 | 44.8% to 54.0% (+9.2 points) |
| 80-84 | 38.0% to 55.9% (+17.9 points) |
| 85-89 | 33.0% to 52.0% (+18.9 points) |
| 90-94 | 34.7% to 48.9% (+14.2 points) |
| 95+ | 34.4% to 40.8% (+6.4 points) |
<!-- /findings:ageing -->

Every figure above, with its unit and period, is in [`docs/findings.md`](docs/findings.md). The
source is `data/findings.json`, written by `etl/findings.py`; nothing in these tables is typed.

## What the data cannot say

- **Who downgraded.** APRA counts the mix of policies at each quarter end, not who moved. Thinner
  cover in aggregate can come from existing members trading down or from new members buying
  less, and the data cannot separate the two.
- **"Exclusions" and "not full cover" are different measures.** The ACCC's share of policies
  with exclusions is APRA's two lifetime-exclusion categories; "not full cover" also counts
  reduced cover without exclusions, and is never called "exclusions" here.
- **Two series breaks, both marked on every chart.** The share of policies with an excess over
  500 dollars steps down in September 2010 for no reason APRA's notes give, so that series is
  used from then on; and from 1 April 2019 the maximum excess rose from 500 to 750 dollars, which
  is what the later climb reflects. The split between lifetime exclusions and reduced cover moves
  in unexplained one-quarter steps and is never trended. [`docs/series-breaks.md`](docs/series-breaks.md)
  holds the evidence.
- **Age is national and annual.** Population by age has no state breakdown and is published for
  each June only, so the ageing figures stop at the latest June and are never split by state. In
  June 2018 APRA's table lacks women aged 95 and over; that cell is left blank, not estimated.
- **Why** the pool is ageing is not claimed. Published work would have to support any cause.

## What this project adds

**1. Verification.** The published measures, rebuilt from APRA's raw files and put next to the
publisher's own figure. They match, so the pipeline is demonstrably right, checked against an
authority rather than against itself.

**2. The breakdown nobody publishes.** The existing analysis is national and annual, in PDFs.
This adds *state* and *five-year age band*, quarterly, and is deliberately small.

**3. It runs itself.** APRA publishes quarterly. The pipeline discovers the new release, loads it,
checks it, reconciles it against published figures and refuses to proceed if anything fails:
[automation](docs/automation.md), [governance](docs/governance.md). It has run green on `main`
and stopped red on a deliberately wrong figure; it has not yet caught a new APRA release
unattended, and the change log will say when it does.

**4. It was built for someone.** Requirements written as user stories for a named audience before
anything was built, with the stories the data cannot support struck and the reason given:
[`docs/user-stories.md`](docs/user-stories.md). Built independently, with no external reviewer,
and the docs say so rather than implying otherwise.

## The report

Three Power BI pages: a headline page that makes the optimistic case first, then one page per
question. Each page states its answer, shows the headline figures with what they are compared
against, and carries its sources and caveats on the page. The titles, takeaways and labels are
measures, so they move with each release. The report is saved as a Power BI project
(`powerbi/MoreMembersLessCover.pbip`), plain text under version control, and reads only the
`phi` views in Azure SQL.

---

## How it is built

A pipeline that refreshes itself every quarter, checks its own work, and refuses to load bad
data.

```
APRA page  →  discover new release  →  download  →  clean  →  CHECK  →  RECONCILE
 (public)        (links change                                  ↓          ↓
                  every quarter)                          fail = stop, nothing loads
                                                                ↓
                                              Azure SQL  →  T-SQL views  →  Power BI
                                              (free offer)                (scheduled refresh)

                        all of it on a schedule, in GitHub Actions
```

| Layer | What | Why this one |
| ----- | ---- | ------------ |
| `data/raw/` | APRA's spreadsheets, exactly as downloaded, never edited | Every figure has to trace back to a published cell |
| `etl/load_apra.py` | Raw spreadsheets to tidy tables | The messy part: multi-row headers, merged cells, footnotes in data rows |
| `etl/checks.py` | Quality checks that stop the load on failure | [governance](docs/governance.md) |
| `etl/validate.py` | Our figures against published figures | The proof the pipeline is right |
| `etl/findings.py`, `etl/check_docs.py` | Every headline figure written once; the docs checked against it | No number is typed twice, or typed at all |
| `sql/` | Azure SQL schema, T-SQL views and a stored procedure | The stack most Australian employers run |
| `.github/workflows/` | Quarterly scheduled refresh | [automation](docs/automation.md) |
| `powerbi/` | The report, `.pbip`, connected to Azure SQL | Version-controlled as plain text |

Real public data, so there is no generator and nothing to simulate. The difficulty is APRA's
spreadsheet layout instead, which is closer to real analyst work than clean generated data ever is.

Azure SQL runs on the free offer (100,000 vCore-seconds and 32 GB a month) set to pause when the
limit is reached, so it cannot bill; the loader waits for the database to wake. If the database
is retired later, the published report keeps its last data and this README will call it a
snapshot.

## Running it

From a clean clone, with Python 3.9 or later:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python etl/download.py         # pick up a new APRA release, if there is one
python etl/download.py --restore   # fetch the recorded files missing from data/raw/
python etl/explore.py          # optional: map the spreadsheets
python etl/load_apra.py        # raw spreadsheets to tidy tables
python etl/checks.py           # quality checks; non-zero exit stops the pipeline
python etl/validate.py         # reconcile against published figures
python etl/breaks.py           # map where the series break
python etl/findings.py         # write every headline figure once, with unit and period
python etl/check_docs.py       # fail if any number in the docs was typed
python etl/to_azure.py --init  # load Azure SQL; needs AZURE_SQL_URL in .env (see .env.example)
```

Or let the schedule do it: [automation](docs/automation.md).

---

## Honesty rules

- **The data is real and public.** No simulation anywhere in this project.
- **Findings are stated as what the data shows**, with the APRA file and table they came from.
- **No number is typed.** Every figure is generated from the data, and a check fails the build
  if one is not.
- **Prior work is credited.** Where a finding reproduces a published one, the README says so and
  links it. The contribution is the verification and the breakdown, not the finding.
- **Where the data cannot answer something, the README says so** rather than estimating.

## Sources

- [APRA, quarterly private health insurance statistics](https://www.apra.gov.au/quarterly-private-health-insurance-statistics)
- [ACCC, private health insurance report to the Senate](https://www.accc.gov.au/media-release/australians-exiting-private-health-insurance-as-price-rises-bite)
- [CHOICE, private health insurance statistics](https://www.choice.com.au/money/insurance/health/articles/private-health-insurance-statistics-in-australia)
- [Actuaries Institute, Is the Gold Hospital category ill?](https://www.actuaries.asn.au/research-analysis/is-the-gold-hospital-private-health-insurance-category-ill)

---

Built by Nandita Choudhary · [DataValix](https://www.datavalix.com)
