# Dashboard plan

> **Superseded on 18 Oct 2026 by [`powerbi-build-guide.md`](powerbi-build-guide.md).** The
> data map settled the open questions: there is no tier split, so the downgrading page uses
> cover type and excess; the pages follow the two main questions in order (downgrading, then
> the ageing pool); and the validation panel sits on page 1. This file is kept as the plan of
> record.

> **Provisional.** The exact visuals depend on what dimensions APRA's files actually carry, which
> step 2 of the setup decides. This is the intended shape; revise it once the data map exists.

Power BI Desktop is Windows-only. It runs on the rented EC2 machine, which bills by the hour:
decide everything here on the Mac first, then start the machine, build, and **stop it**.

---

## Three pages

Each answers one question, in order.

### Page 1 · The headline — *"Isn't everything fine?"*

Set the scene honestly: membership really is at a record. The page should make the optimistic
case before the next two pages undercut it.

- Stat tiles: total insured persons · coverage as % of population · change on last year
- Line: insured persons by quarter, full history
- Line: coverage rate (% of population) by quarter — the more honest measure, since population
  grows too

A rising headcount against a flat or falling coverage rate is itself the first crack. Two
separate line charts, never one chart with two y-axes.

### Page 2 · Who — *"Is the pool getting older?"*

- Bar: coverage rate by age band, most recent quarter
- Lines: coverage rate by age band over time, one line per band (cap at 6 bands; fold the rest)
- Stat tile: share of members aged 60+, then vs now

The thing to look for is whether young-adult coverage is recovering, flat, or still sliding, and
whether the overall record is being carried by older members joining.

### Page 3 · What — *"Is the cover itself shrinking?"*

Confirmed buildable. Source: `Membership and Benefits.xlsx` → `HTPoliciesXTypeofCover`, which
carries cover type and excess level by state, quarterly, from 2007.

- 100% stacked area: policy mix by cover type over time (full cover vs the reduced-cover and
  exclusion categories). Stacked is right because the categories sum to all hospital policies.
- Line: full-cover share by quarter, with the ACCC's published figure marked as a reference
- 100% stacked area: excess level over time (nil / up to $500 / over $500)
- Small multiples or a slicer: the same mix by state

**Mark the April 2019 reforms on the time axis.** If the series breaks there, show it as a break
rather than drawing one line through it — and say which it is in a caption. An interviewer who
knows this market will look for exactly that.

### Validation panel

Put the published-vs-ours comparison table on page 1, small, in the corner, or as its own
narrow page. It is not decoration — it is the evidence that the rest of the numbers can be
trusted, and it is the first thing a sharp interviewer will want.

---

## Rules carried over from the last project

- **Never a dual-axis chart.** Two measures on different scales means two charts.
- **Legend for two or more series**, no legend for one — the title names it.
- **Reuse `theme.json`** from the policy-lapse project. Same validated palette, so the two
  projects look like one body of work.
- **Save as `.pbip`**, not `.pbix`, so the model and measures are plain text in git.
- **Mark `dim_date` as the date table** before writing any time-intelligence measure.
- **Star schema discipline:** facts join to dimensions; dimensions do not join to each other.

## Measures

Cannot be written until the data map exists. The likely set is small — perhaps six to eight:

insured persons · coverage rate · change on prior year · share by age band · policies by tier ·
tier share · Gold share vs published.

Far fewer than the last project, because this data is already aggregated by APRA. That is worth
noticing rather than padding: a thin measure layer on well-structured public data is the honest
shape of this project.

## What goes in the README at the end

1. Two or three screenshots, page 2 leading
2. The validation table, in full
3. One paragraph on what the breakdown by age and state shows — stated as what the data shows,
   with the file and sheet named
4. A line crediting the prior work, linking the ACCC and Actuaries Institute pieces
