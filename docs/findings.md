# Findings

Written by `etl/findings.py` from the June 2026 release. APRA data from June 2007 to June 2026; population by age is annual, to June 2025.
Every figure carries its unit and its period; nothing on this page is typed by hand, and the
same file feeds the README. The source of every number is `data/findings.json`.

## The headline

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

## Downgrading

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

## An older pool

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

## Checked against published figures

| Measure | Published | Rebuilt | Source | Match |
| ------- | --------- | ------- | ------ | ----- |
| Hospital policies with exclusions, June 2018 | 44% | 43.84% | ACCC | Yes |
| Hospital policies with an excess or co-payment, June 2018 | 84% | 83.60% | ACCC | Yes |
| Hospital cover, share of population, June 2025 | 45.39% | 45.3923% | APRA | Yes |
| Hospital cover, share of population, December 2025 | 45.6% | 45.648% | CHOICE | Yes |
| Hospital cover at ages 25–29, June 2025 | 26.3% | 26.258% | CHOICE | Yes |
