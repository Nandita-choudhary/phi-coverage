# Reconciliation

Written by `etl/validate.py` on 17 October 2026, from APRA's files starting with "Quarterly Private Health Insurance Membership and Benefits June 2026.xlsx".

Every figure here was published by someone else, then rebuilt from APRA's raw spreadsheets. A figure matches when ours rounds to it at the precision it was published.

| Measure | Published | Source | Ours | Difference | Match |
| ------- | --------- | ------ | ---- | ---------- | ----- |
| Hospital policies with exclusions, June 2018 | 44% | ACCC, report to the Senate on private health insurance, 2017–18 | 43.84% | -0.16 | Yes |
| Hospital policies with an excess or co-payment, June 2018 | 84% | ACCC, report to the Senate on private health insurance, 2017–18 | 83.60% | -0.40 | Yes |
| Hospital cover, share of population, June 2025 | 45.39% | APRA, Quarterly Membership Coverage, June 2026 release, table T1 | 45.3923% | +0.0023 | Yes |
| Hospital cover, share of population, December 2025 | 45.6% | CHOICE, private health insurance statistics, citing APRA | 45.648% | +0.048 | Yes |
| Hospital cover at ages 25–29, June 2025 | 26.3% | CHOICE, private health insurance statistics, citing APRA | 26.258% | -0.042 | Yes |

## Notes

- **Hospital policies with exclusions, June 2018:** Ours counts APRA's two lifetime-exclusion categories. "Not full cover" (58.3%) is a wider measure: it also counts reduced cover without exclusions.
- **Hospital policies with an excess or co-payment, June 2018:** APRA records excess levels only, so co-payments are not in ours.
- **Hospital cover, share of population, June 2025:** The regulator's own figure, rebuilt from its raw tables.
- **Hospital cover, share of population, December 2025:** CHOICE does not name the quarter; December 2025 is the quarter of its other figures.
- **Hospital cover at ages 25–29, June 2025:** Insured people aged 25–29 over the population aged 25–29.
