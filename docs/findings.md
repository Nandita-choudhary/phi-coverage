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

Kind: *stock*: a quantity counted at the end of the quarter named, such as people or policies; *share*: one stock as a percentage of another at the same date; *gap*: the difference between two shares at the same date, in percentage points; *change*: the difference between the two dates named, in the unit shown; *growth*: the percentage change between the two dates named; *count*: a tally of items in one of this project's own tables, such as age bands or checked figures; *proportion*: one change as a percentage of another change; *difference*: the percentage by which one series exceeds another at the same date.

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
| Aged 65 and over, share of insured people, change | +7.4 points | 30 June 2007 to 30 June 2025 | change |
| Rise in the insured 65 and over share from Australia ageing, Kitagawa average of both orderings | +4.7 points | 30 June 2007 to 30 June 2025 | change |
| Rise in the insured 65 and over share from change in coverage within age groups, Kitagawa average | +2.7 points | 30 June 2007 to 30 June 2025 | change |
| Rise in the insured 65 and over share: interaction of the two, attributable to neither alone | +0.6 points | 30 June 2007 to 30 June 2025 | change |
| Australia ageing as a proportion of the rise, Kitagawa average | 63.4% | 30 June 2007 to 30 June 2025 | proportion |
| Coverage, under 65, change | -0.4 points | 30 June 2007 to 30 June 2025 | change |
| Coverage, 65 and over, change | +9.3 points | 30 June 2007 to 30 June 2025 | change |
| Coverage rise, largest age band (85-89) | +18.9 points | 30 June 2007 to 30 June 2025 | change |
| Age bands whose coverage fell | 6 of 20 bands | 30 June 2007 to 30 June 2025 | count |
| Population-by-age table against the quarterly series | +0.38% | as at 30 June 2025 | difference |

| Population, June | Under 25 | 25 to 49 | 50 to 64 | 65 and over |
| ---------------- | -------- | -------- | -------- | ----------- |
| Insured people, June 2007 | 29.7% | 34.5% | 22.5% | 13.3% |
| Insured people, June 2025 | 27.4% | 32.3% | 19.6% | 20.7% |
| All Australians, June 2007 | 33.4% | 35.8% | 17.7% | 13.1% |
| All Australians, June 2025 | 30.2% | 35.0% | 17.3% | 17.4% |

Why the pool aged, split two ways. The insured 65 and over share depends on Australia's age structure and on coverage within each age group; holding one at its first June value isolates the other, and the two orderings differ by the interaction.

| Method | Australia ageing | Change in coverage within age groups | Interaction |
| ------ | ---------------- | ------------------------------------ | ----------- |
| First June's coverage rates held, ageing first | ageing +4.4 points | coverage change +3.0 points |  |
| First June's population held, coverage change first | ageing +5.0 points | coverage change +2.4 points |  |
| Pure effects and their interaction | ageing +4.4 points | coverage change +2.4 points | interaction +0.6 points |
| Kitagawa average of the two orderings | ageing +4.7 points | coverage change +2.7 points |  |

Coverage by age group and by band uses APRA's annual population-by-age table as the denominator; the headline rate uses its quarterly population series, which differs by the amount in the last row of the figures above.

| Age group | Coverage, first to latest June |
| --------- | ------------------------------ |
| Children, 0 to 14 | 40.3% to 43.0% (+2.7 points) |
| 15 to 24 | 37.6% to 38.3% (+0.8 points) |
| 25 to 34 | 34.7% to 31.5% (-3.2 points) |
| 35 to 39 | 44.3% to 45.4% (+1.1 points) |
| 40s, 40 to 49 | 48.4% to 51.4% (+3.0 points) |
| 50 to 64 | 55.9% to 51.2% (-4.7 points) |
| 65 and over | 44.4% to 53.8% (+9.3 points) |
| Under 65 | 43.8% to 43.4% (-0.4 points) |

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

## Policy events and reporting changes on the timeline

Events are context for a chart, not a cause. Only an entry that says so is claimed to explain a
feature of a series. Source: `data/policy_events.json`.

| Date | Event | Explains a series feature? | Source |
| ---- | ----- | -------------------------- | ------ |
| 1 July 2000 | **Lifetime Health Cover introduced.** People taking out hospital cover after age 30 pay a 2% loading on the premium for each year over 30, up to 70%, removed after 10 years of continuous cover. Background: it predates the series, which starts in June 2007. | No: background, before the series starts | [Department of Health and Aged Care, privatehealth.gov.au, Lifetime Health Cover](https://www.privatehealth.gov.au/health_insurance/surcharges_incentives/lifetime_health_cover.htm) |
| 1 July 2008 | **Medicare Levy Surcharge thresholds raised.** The income threshold above which people without hospital cover pay the surcharge rose from $50,000 to $70,000 for singles and from $100,000 to $140,000 for families, from the 2008-09 income year. | No: context only | [Parliament of Australia, Tax Laws Amendment (Medicare Levy Surcharge Thresholds) Bill (No. 2) 2008](https://aph.gov.au/Parliamentary_Business/Bills_Legislation/Bills_Search_Results/Result?bId=r3094) |
| 1 July 2012 | **Private health insurance rebate means-tested.** The rebate fell in three income tiers from $84,001 for singles and $168,001 for families, and stopped at $130,001 and $260,001. | No: context only | [Parliamentary Library, FlagPost on the legislation to means test the rebate (2011); National Seniors fact sheet on the enacted thresholds](https://www.aph.gov.au/About_Parliament/Parliamentary_Departments/Parliamentary_Library/FlagPost/2011/July/Legislation_to_means_test_the_private_health_insurance_rebate_re-introduceddebate_continues) |
| 1 April 2014 | **Rebate tied to an indexed base premium.** The rebate applies to a base premium indexed by the lesser of CPI and the insurer's premium rise, so the rebate's share of the premium falls when premiums rise faster than CPI. | No: context only | [Parliamentary Library, Bills Digest no. 35 2013-14 (Private Health Insurance Legislation Amendment (Base Premium) Bill)](https://aph.gov.au/Parliamentary_Business/Bills_Legislation/bd/bd1314a/14bd035) |
| 1 April 2019 | **Private health insurance reforms.** The maximum voluntary excess rose from $500 to $750 for singles and from $1,000 to $1,500 for couples and families; hospital products were classified Gold, Silver, Bronze or Basic, mandatory from 1 April 2020; insurers could offer people aged 18 to 29 a discount of 2% of the hospital premium for each year under 30, up to 10%. | The climb in hospital policies with an excess over $500 from this date: the rule allowed excesses above $500 for the first time (docs/series-breaks.md). | [Department of Health and Aged Care, privatehealth.gov.au, Private Health Insurance Changes](https://www.privatehealth.gov.au/health_insurance/phichanges/index.htm) |
| 1 April 2020 | **COVID-19: the April premium increase deferred.** Private Healthcare Australia's member funds postponed the 1 April 2020 premium increase for at least six months. | No: context only | [Commonwealth Ombudsman, Private Health Insurance Quarterly Bulletin 94](https://www.ombudsman.gov.au/__data/assets/pdf_file/0010/111115/PHI-QB-94.pdf) |

| Quarter | Series | What | Kind |
| ------- | ------ | ---- | ---- |
| September 2009 | Every state series | ACT figures were included with NSW until 30/09/2009 (APRA, Notes on Statistics); the ACT's population shows zero until then and NSW includes it. | reporting change |
| September 2010 | Hospital policies with an excess over $500 (single) | A one-quarter step down with no note from APRA and no policy event found; the series is used from this quarter on. | unexplained step |
| September 2014 | Lifetime exclusions against reduced cover | An insurer reclassified its policies from non-exclusionary to exclusionary (APRA, Notes on Statistics). | reporting change |
| September 2018 | Lifetime exclusions against reduced cover | The largest one-quarter move in the split, with no note from APRA; the split is never trended. | unexplained step |

## Checked against published figures

| Measure | Published | Rebuilt | Source | Match |
| ------- | --------- | ------- | ------ | ----- |
| Hospital policies with exclusions, June 2018 | 44% | 43.84% | ACCC | Yes |
| Hospital policies with an excess or co-payment, June 2018 | 84% | 83.60% | ACCC | Yes |
| Hospital cover, share of population, June 2025 | 45.39% | 45.3923% | APRA | Yes |
| Hospital cover, share of population, December 2025 | 45.6% | 45.648% | CHOICE | Yes |
| Hospital cover at ages 25–29, June 2025 | 26.3% | 26.258% | CHOICE | Yes |
