# Data dictionary

Every column in every tidy table that `etl/load_apra.py` writes to `data/clean/`. The last two
columns are the lineage: any number in the dashboard traces back to a cell APRA published.
APRA names its files for the quarter, so the source file changes with each release; the loader
records the exact file in every row.

## policies_by_cover · question 1: are people downgrading instead of leaving?

One row per quarter, state, cover type and excess level. 7,272 rows: 77 quarters from June 2007
to June 2026, 8 states.

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |
| `quarter_end` | date | Last day of the quarter, from APRA's Year and MonthEnd | Quarterly Private Health Insurance Membership and Benefits [quarter].xlsx | `HTPoliciesXTypeofCover` |
| `state` | text | NSW, VIC, QLD, WA, SA, TAS, ACT or NT | as above | as above |
| `policy_cover` | text | APRA's PolicyCover: Full cover · Reduced cover and some lifetime exclusions · Reduced cover but no lifetime exclusions · Some lifetime exclusions but no reduced cover | as above | as above |
| `excess` | text | APRA's ExcessAmount: Nil · Up to 500 dollars single · Over 500 dollars single. From 1 April 2019 insurers could offer up to 750 dollars single, so "over 500" means something new from then | as above | as above |
| `policies` | integer | Hospital treatment policies at the end of the quarter, as APRA reports them (its Value column) | as above | as above |
| `source_file` | text | The APRA file the row came from | — | — |
| `source_sheet` | text | The sheet the row came from | — | — |

**Known quirk:** in the December 2021 quarter, every state's "Full cover, Nil" count ends in .1
in APRA's file (197,506.1 in NSW). The loader rounds those eight values and says so on every
run; any other fractional count stops the load.

## insured_by_age · question 2: is the pool getting older?

One row per quarter, state, gender and five-year age band. 24,240 rows: 77 quarters from June
2007 to June 2026, 8 states, 2 genders, 20 age bands.

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |
| `quarter_end` | date | Last day of the quarter, from APRA's Year and MonthEnd | Quarterly Private Health Insurance Membership Trends [quarter].xlsx | `MembershipByAgeData`, table `AgeCohort_HT` |
| `state` | text | NSW, VIC, QLD, WA, SA, TAS, ACT or NT | as above | as above |
| `gender` | text | M or F, as APRA codes it | as above | as above |
| `age_band_start` | integer | First age in the band: 0, 5, 10 … 95 | as above | as above |
| `age_band` | text | 0-4, 5-9 … 90-94, then 95+, as in APRA's glossary | derived | from `age_band_start` |
| `insured_persons` | integer | People covered by a hospital treatment policy at the end of the quarter (its InsuredPersons column) | as above | as above |
| `source_file` | text | The APRA file the row came from | — | — |
| `source_sheet` | text | The sheet and table the row came from | — | — |
