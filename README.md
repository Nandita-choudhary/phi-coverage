# More Members, Less Cover?

**Australian private health insurance membership is at a record high. So is the system healthy?**

This project rebuilds the answer from APRA's own published data — the regulator's quarterly
private health insurance statistics — and asks what the headline number hides: *who* is insured,
and *what* they are actually covered for.

> **Status: built.** Every figure below is generated from APRA's data by `etl/findings.py`, which
> also writes [`docs/findings.md`](docs/findings.md): every figure with its unit and its period.

**[→ Open the live dashboard]()** · *(link added after publishing)*

---

## The question

Membership has reached a record. Two things could still be going wrong underneath it, and neither
shows up in a headcount:

1. **Are people downgrading instead of leaving?** Under cost pressure people do not always
   cancel. They move to policies with reduced cover, exclusions and a higher excess. Same
   member, thinner product — and a headcount cannot see it.
2. **Is the pool getting older?** If the young thin out while the old keep joining, the risk
   pool worsens even as the total grows. Premiums follow the pool, not the headcount.

Either would mean the record membership figure is telling a flattering story about a market that
is getting worse.

## What is already known

This market is heavily analysed. The ACCC reports on it to the Senate every year; the Actuaries
Institute publishes on it; CHOICE and APRA publish regular statistics. **Nothing here is a
discovery, and the project does not claim one.** See [`docs/prior-work.md`](docs/prior-work.md)
for who has published what.

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

### What the raw data actually holds

APRA does **not** publish the Gold / Silver / Bronze / Basic tiers — the only "Gold" in the
files is the veterans' DVA Gold Card, which is something else entirely. What it does publish is
better for this question: **cover type and excess level, quarterly, by state, back to 2007**.
Tiers only exist from 2019, so this is nineteen years instead of seven, and it is the ACCC's own
pair of measures.

That series is what the project rebuilds; the figures are in the next section.

**Two caveats before any of that is published as a finding.** APRA splits *reduced cover* from
*lifetime exclusions* as separate categories, so "not full cover" is not necessarily the same
measure as the ACCC's "carried exclusions" — reconciling the two is part of the work, not an
afterthought. And the April 2019 reforms restructured these products, so the series may break
around then.

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

## What this project adds

**1. Verification.** Rebuild the published measures from APRA's raw files and put the result next
to the regulator's own figure. If they match, the pipeline is demonstrably correct — checked
against an authority rather than against itself.

**2. The breakdown nobody publishes.** The existing analysis is national and annual, in PDFs. This
adds *age* and *state*: is the shift young people buying cheap cover, or older people trading
down? Does Western Australia look like New South Wales?

That second part is the only genuinely open question here, and it is deliberately small.

**3. It runs itself.** APRA publishes quarterly. The pipeline discovers the new release, loads
it, checks it, reconciles it against published totals and refuses to proceed if anything is out
of tolerance — [automation](docs/automation.md), [governance](docs/governance.md).

**4. It was built for someone.** Requirements written as user stories for a named audience
before anything was built — [`docs/user-stories.md`](docs/user-stories.md). Built
independently, with no external reviewer, and the docs say so rather than implying otherwise.

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
                                               (free tier)                (scheduled refresh)

                        all of it on a schedule, in GitHub Actions
```

| Layer | What | Why this one |
| ----- | ---- | ------------ |
| `data/raw/` | APRA's spreadsheets, exactly as downloaded, never edited | Every figure has to trace back to a published cell |
| `etl/load_apra.py` | Raw spreadsheets → tidy tables | The messy part: multi-row headers, merged cells, footnotes in data rows |
| `etl/checks.py` | Quality checks that stop the load on failure | [governance](docs/governance.md) |
| `etl/validate.py` | Our figures vs published figures | The proof the pipeline is right |
| `sql/` | Azure SQL schema, T-SQL views and a stored procedure | Microsoft stack, which is what Australian job ads mostly ask for |
| `.github/workflows/` | Quarterly scheduled refresh | [automation](docs/automation.md) |
| `powerbi/` | The report, `.pbip`, connected to Azure SQL | Version-controlled as plain text |

Real public data, so there is no generator and nothing to simulate. The difficulty is APRA's
spreadsheet layout instead, which is closer to real analyst work than clean generated data ever is.

**Azure SQL is on the free offer** — 100,000 vCore-seconds and 32 GB per month, renewing for the
life of the subscription. Set "behaviour when free limit reached" to **auto-pause**, not
"continue for charges": on auto-pause the database simply stops until next month and cannot bill
you. That choice is one-way, so make it at creation.

## Running it

```bash
pip install -r requirements.txt
python etl/download.py         # fetch APRA's newest files into data/raw/
python etl/explore.py          # map the spreadsheets — run this first
python etl/load_apra.py        # raw → tidy tables
python etl/checks.py           # quality checks; non-zero exit stops the pipeline
python etl/validate.py         # reconcile against published figures
python etl/breaks.py           # map where the series break
python etl/findings.py         # write every headline figure once, with unit and period
python etl/to_azure.py         # load into Azure SQL (the first time, add --init)
```

Or let the schedule do it: [automation](docs/automation.md).

---

## Honesty rules

- **The data is real and public.** No simulation anywhere in this project.
- **Findings are stated as what the data shows**, with the APRA file and table they came from.
- **Prior work is credited.** Where a finding reproduces a published one, the README says so and
  links it. The contribution is the verification and the breakdown, not the finding.
- **Where the data cannot answer something, the README says so** rather than estimating.

## Sources

- [APRA — Quarterly private health insurance statistics](https://www.apra.gov.au/quarterly-private-health-insurance-statistics)
- [ACCC — private health insurance report to the Senate](https://www.accc.gov.au/media-release/australians-exiting-private-health-insurance-as-price-rises-bite)
- [CHOICE — private health insurance statistics](https://www.choice.com.au/money/insurance/health/articles/private-health-insurance-statistics-in-australia)
- [Actuaries Institute — Is the Gold Hospital category ill?](https://www.actuaries.asn.au/research-analysis/is-the-gold-hospital-private-health-insurance-category-ill)

---

Built by Nandita Choudhary · [DataValix](https://www.datavalix.com)
