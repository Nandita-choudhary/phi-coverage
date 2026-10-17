# More Members, Less Cover?

**Australian private health insurance membership is at a record high. So is the system healthy?**

This project rebuilds the answer from APRA's own published data — the regulator's quarterly
private health insurance statistics — and asks what the headline number hides: *who* is insured,
and *what* they are actually covered for.

> **Status: planning.** The data has not been analysed yet. Every figure below is quoted from a
> published source, not produced by this project. Results replace them as the work is done.

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

The short version of the published position:

| What the sources say | Who says it |
| --- | --- |
| Membership is at a record, roughly 12.7 million people | APRA, via industry reporting |
| Downgrading, exclusions and rising excesses are a sustained trend | ACCC, annual report to the Senate |
| 44% of hospital policies carried exclusions in June 2018, up from 40% a year earlier | ACCC |
| 84% carried an excess or co-payment, up from 83% | ACCC |
| 25–29 year olds are the least insured age group, at 26.3% | CHOICE, citing APRA |

So the expected answer is **more members, thinner cover**. The job of this project is not to
announce that. It is to verify it independently and add what the published work leaves out.

### What the raw data actually holds

APRA does **not** publish the Gold / Silver / Bronze / Basic tiers — the only "Gold" in the
files is the veterans' DVA Gold Card, which is something else entirely. What it does publish is
better for this question: **cover type and excess level, quarterly, by state, back to 2007**.
Tiers only exist from 2019, so this is nineteen years instead of seven, and it is the ACCC's own
pair of measures.

A first pass at it, June quarters, Australia-wide:

| | Hospital policies | Full cover | Not full cover |
| --- | --- | --- | --- |
| 2007 | 4,368,148 | 63.6% | 36.4% |
| 2015 | 5,481,115 | 46.0% | 54.0% |
| 2026 | 6,268,336 | 26.8% | 73.2% |

Policies up 43%; full cover down from two-thirds to a quarter.

**Two caveats before any of that is published as a finding.** APRA splits *reduced cover* from
*lifetime exclusions* as separate categories, so "not full cover" is not necessarily the same
measure as the ACCC's "carried exclusions" — reconciling the two is part of the work, not an
afterthought. And the April 2019 reforms restructured these products, so the series may break
around then.

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
python etl/to_azure.py         # load into Azure SQL
```

Or let the schedule do it. Step by step, including where to download the files and how to set up
Azure: [`docs/setup-steps.md`](docs/setup-steps.md).

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
