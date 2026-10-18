# Data dictionary

**In Azure SQL** the five tidy tables below become tables of the same name and columns in the
`phi` schema, with keys and checks (`sql/schema.sql`). Power BI reads views only
(`sql/views.sql`): `dim_date`, `dim_state`, `dim_age_band`, `dim_cover`, `dim_excess`, the
`fact_*` views, and the measure views `v_cover_mix`, `v_hospital_coverage`, `v_coverage_by_age`
and `v_age_mix`. `dim_gender` (F, M) lets one slicer filter insured people and population by age
together, and `reconciliation_panel` feeds the report's validation panel.

## reconciliation · the five published figures, checked

Written by `etl/validate.py` to `data/clean/reconciliation.csv` and loaded as
`phi.reconciliation`. One row per published figure; 5 rows.

| Column | Type | Definition |
| ------ | ---- | ---------- |
| `measure` | text | What was published, and for when |
| `published_pct`, `published_display` | number, text | The published figure, and as published (44%) |
| `ours_pct`, `ours_display` | number, text | Ours, rebuilt from APRA's raw files |
| `matches` | true/false | Ours rounds to the published figure at its published precision |
| `source` | text | Who published it |
| `note` | text | How the two measures relate |
| `checked_on` | date | When `validate.py` last ran |

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

## published_totals · APRA's own count, used by checks.py

One row per quarter and state. 606 rows: 77 quarters, June 2007 to June 2026. The ACT is
missing until September 2009 because APRA counted it inside NSW until then.

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |
| `quarter_end` | date | Last day of the quarter | Quarterly Private Health Insurance Membership Trends [quarter].xlsx | `MembershipData`, tables `HTOnly` and `HTandGTCombined` |
| `state` | text | NSW, VIC, QLD, WA, SA, TAS, ACT or NT | as above | as above |
| `hospital_policies` | integer | Hospital policies sold on their own plus those combined with extras (Coverage = Policies) | as above | as above |
| `hospital_insured_persons` | integer | People covered by those policies (Coverage = Insured persons) | as above | as above |
| `source_file`, `source_sheet` | text | Where the row came from | — | — |

## population · for coverage rates

One row per quarter and state. 606 rows: 77 quarters, June 2007 to June 2026. As in the
membership tables, NSW includes the ACT until September 2009: APRA's population table shows the
ACT as 0 until then, and the loader drops those rows.

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |
| `quarter_end` | date | Last day of the quarter | Quarterly Private Health Insurance Membership Trends [quarter].xlsx | `MembershipData`, table `PopulationState` |
| `state` | text | APRA's StateShortName: NSW, VIC, QLD, WA, SA, TAS, ACT or NT | as above | as above |
| `population` | integer | State population, from ABS figures as APRA publishes them | as above | as above |
| `source_file`, `source_sheet` | text | Where the row came from | — | — |

## population_by_age · for coverage by age

One row per June, gender and five-year age band. 759 rows: every June from 2007 to 2025, 2
genders, 20 bands. One row is missing in APRA's own table: women aged 95 and over in June 2018.
It is left unfilled.

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |
| `quarter_end` | date | 30 June of the year | Annual private health insurance membership and benefits statistics - [year].xlsx | `Australian population`, table `PopulationAge` |
| `gender` | text | M or F | as above | as above |
| `age_band_start` | integer | First age in the band: 0, 5 … 95 | as above | as above |
| `age_band` | text | 0-4 … 90-94, then 95+ | derived | from `age_band_start` |
| `population` | integer | Australia's population in that band (its Value column) | as above | as above |
| `source_file`, `source_sheet` | text | Where the row came from | — | — |
