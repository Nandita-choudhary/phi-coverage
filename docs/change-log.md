# Change log

One entry per load, newest first. The interesting entries are the failures and the deliberate
changes: they show the checks catch real things.

```
2026-10-18  Loaded into Azure SQL: 33,483 rows in 5 tables, latest quarter 2026-06-30.
2026-10-18  Loaded into Azure SQL: 33,483 rows in 5 tables, latest quarter 2026-06-30.
2026-10-17  Recorded files already in data/raw (downloaded by hand): Quarterly Private
            Health Insurance Membership and Benefits June 2026.xlsx; Quarterly Private
            Health Insurance Membership Trends June 2026_0.xlsx; Quarterly Private Health
            Insurance Membership Coverage June 2026.xlsx; Annual private health insurance
            membership and benefits statistics - 2024-2025 (2).xlsx.
2026-10-17  Reloaded Jun 2026 quarter.  33,483 rows in 5 tables.  All 7 checks passed.
            Reconciliation: all 5 published figures matched (docs/reconciliation.md).
            Row-count baseline reset on purpose: population now drops APRA's zero ACT rows
            before Dec 2009 (the ACT is counted inside NSW then), and population by age was
            added. The shrink check caught the change first (population 616 to 606).
2026-10-17  First load, Jun 2026 quarter.  32,734 rows in 4 tables.  All 6 checks passed.
            The first runs failed until two things in APRA's data were understood: the ACT is
            counted inside NSW until Sep 2009, and APRA's own tables differ by up to 0.011%.
```
