# Governance

Four things that make the pipeline trustworthy: a data dictionary, automated checks,
reconciliation against published figures, and a change log. Each section says what exists in
the repo and where.

---

## 1 · Data dictionary

Every field in every tidy table, defined once in `docs/data-dictionary.md`:

| Column | Type | Definition | Source file | Source sheet |
| ------ | ---- | ---------- | ----------- | ------------ |

The last two columns are the point. Any number in the dashboard can be traced back to a cell in
a spreadsheet APRA published. That is lineage, and it is what governance actually means in
practice.

## 2 · Automated quality checks

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

## 3 · Reconciliation

`etl/validate.py` takes figures somebody else has already published, computes them from the
raw files and compares. The finished table is generated into
[`docs/reconciliation.md`](reconciliation.md) and loaded into the database for the report's
reconciliation panel. It is not typed anywhere else, so it cannot go stale.

**The matching rule:** a figure matches when ours rounds to the published value at the precision
it was published. A mismatch fails the refresh, and the fix is to the understanding of the
measure, never to the tolerance.

Definitions need care. APRA's `PolicyCover` field splits *reduced cover* from *lifetime
exclusions*, and the ACCC's "carried exclusions" turned out to mean APRA's two lifetime-exclusion
categories; "not full cover" is a wider measure and is never called "exclusions" here. APRA and
CHOICE can also count different populations or quarters. The notes column of the reconciliation
table records each such decision.

This is independent proof the pipeline is right, checked against a regulator rather than
against itself, which is why the README carries the table.

## 4 · Change log

[`docs/change-log.md`](change-log.md), newest first: one entry per load, written by the
downloader and the loader, with failures and deliberate baseline changes written in by hand.
The entries that matter are the failures. They are evidence that the checks catch real things,
such as the row-count baseline reset when the handling of the ACT changed.
