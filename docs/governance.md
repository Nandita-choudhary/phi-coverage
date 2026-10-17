# Governance

Four things that turn a script into something an employer would let near their data. None of
them is hard; all of them are the difference between "I made a chart" and "I ran a pipeline".

Each one has a job-ad word attached, and that is not a coincidence — the words only mean
something if the thing underneath actually exists, so build the thing.

---

## 1 · Data dictionary → *"documentation", "data governance"*

Every field in every tidy table, defined once in `docs/data-dictionary.md`:

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |

The last two columns are the point. Any number in the dashboard can be traced back to a cell in
a spreadsheet APRA published. That is lineage, and it is what governance actually means in
practice.

Write it as the pipeline is built, not afterwards. Written afterwards it is always wrong.

## 2 · Automated quality checks → *"data quality"*

`etl/checks.py`, run on every load, before anything is written to the database:

| Check | Fails when |
| ----- | ---------- |
| Row count | A quarter's load has fewer rows than the previous one |
| Nulls | A column that should never be empty is empty |
| Totals add up | Cover types do not sum to APRA's own count of hospital policies, or age bands to its count of insured persons, in any state-quarter (beyond 0.05%) |
| Date continuity | A quarter is missing from the series |
| Range sanity | A coverage rate outside 0–100%, a negative count |

Each check prints pass or fail with the number. **A failure stops the load** — it does not warn
and carry on. That distinction is the whole point: a pipeline that keeps going when the data is
wrong is worse than no pipeline.

## 3 · Reconciliation → *"reconciliation", "controls"*

`etl/validate.py`. Take figures somebody else has already published, compute them from the raw
files, compare:

| Measure | Published | Source | Ours | Diff | Pass? |
| ------- | --------- | ------ | ---- | ---- | ----- |
| Hospital policies with exclusions, Jun 2018 | 44% | ACCC | ? | ? | ? |
| Hospital policies with an excess or co-payment, Jun 2018 | 84% | ACCC | ? | ? | ? |
| Hospital cover, % of population | 45.6% | CHOICE (APRA) | ? | ? | ? |
| Coverage rate, 25–29 | 26.3% | CHOICE (APRA) | ? | ? | ? |

The first row is the interesting one. APRA's `PolicyCover` field splits *reduced cover* from
*lifetime exclusions* as separate categories, so "not full cover" may be a wider measure than
the ACCC's "carried exclusions". Work out which categories the ACCC is counting before
declaring a mismatch a bug.

Set a tolerance — say 0.1 percentage points — and **fail the refresh outside it**.

This is the most valuable single artefact in the project. It is independent proof the pipeline is
right, checked against a regulator rather than against itself. Put the finished table in the
README.

A mismatch is not automatically a bug in your code: APRA and CHOICE may define a measure
differently, or count a different population. Work out which it is and write the answer down.
"I found a definitional difference and documented it" is a better story than a clean match.

## 4 · Change log → *"auditability"*

`docs/change-log.md`, one line per load:

```
2026-11-02  Loaded Sep 2026 quarter.  412,880 rows.  All checks passed.
            Reconciliation: all published figures within tolerance.
2026-08-14  Loaded Jun 2026 quarter.  410,114 rows.  Age-band check FAILED —
            APRA split the 85+ band into 85-89 and 90+. Loader updated, reloaded.
```

Append to it on every run, by hand or from the script. The interesting entries are the failures —
they are evidence that the checks catch real things, and that one above is the kind of thing that
genuinely happens.

---

## What this gives you to say

> "Every quarter the pipeline pulls APRA's new release, runs quality checks, reconciles the
> figures against published totals, and refuses to load if anything is out of tolerance. Each
> load is logged, and every field traces back to a source file and sheet."

That one sentence covers data quality, reconciliation, lineage, controls and auditability —
and unlike a keyword list, it is all true and all demonstrable in the repo.
