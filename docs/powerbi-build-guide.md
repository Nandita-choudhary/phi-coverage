# Power BI build guide

Everything needed to build the report, written down **before** the Windows machine is switched
on. That machine bills by the hour; thinking is free on the Mac. Work through this top to
bottom and the session is mostly copy, paste and click.

The report answers the project's two questions, after a headline page that makes the
optimistic case first:

| Page | Question | Answer the data gives |
| ---- | -------- | --------------------- |
| 1 · The headline | Membership is at a record. Isn't everything fine? | A record 12.8 million people, but coverage (45.8%) is still below its 2015 peak (47.4%) |
| 2 · Downgrading | Are people downgrading instead of leaving? | Policies up 43.5% since 2007, but full cover fell from 63.6% to 26.8% |
| 3 · An older pool | Is the pool getting older? | Yes, faster than Australia: 65+ rose from 13.3% to 20.7% of the insured, against 13.1% to 17.4% of everyone |

All figures are APRA's, June 2007 to June 2026, and every one was checked against the Python
pipeline and the SQL views before this guide was written.

---

## 0. Before you start the machine

- [ ] The pipeline has loaded Azure SQL: `python etl/to_azure.py` ran, and `phi.load_log`'s
      latest row shows the June 2026 release (33,488 rows)
- [ ] You have the server name (ends in `.database.windows.net`), the database name, the SQL
      login and its password somewhere you can reach from Windows, **not** in the repo
- [ ] The repo is pushed to GitHub, so you can `git clone` it on Windows
- [ ] `powerbi/theme.json` is in the repo (project 1's colourblind-safe theme, renamed)

## 1. Session routine, every single time

**Start:** AWS → EC2 → Instances → your machine → Instance state → **Start instance** → wait
two minutes → copy the **new** Public IPv4 address → paste it into Windows App → connect.

**Then let the machine through Azure's firewall.** The EC2 machine gets a new address every
start, and Azure SQL refuses addresses it does not know. On the Windows machine, open
portal.azure.com → your SQL **server** → Networking → **Add your client IPv4 address** → Save.
Delete the previous session's rule while you are there.

**Finish:** save → `git add powerbi/` → commit → `git push` → close Windows App → AWS →
Instance state → **Stop instance**. Never Terminate.

The public IP changes on every restart. In Windows App, error **0x704** means the saved PC still
has the old IP: add the PC again with the new one, and tick **Clipboard** under Devices & Audio
as you add it, so you can paste. On the Windows side, paste with **Ctrl+V**.

## 2. Install, once

On the Windows machine: Power BI Desktop, Git, and VS Code with the Claude Code extension. Then:

```
git clone https://github.com/Nandita-choudhary/phi-coverage.git
```

Claude on Windows edits `powerbi/` only; the Mac edits everything else. Run `git pull` before
editing on either side.

No certificate step this time. Project 1's Supabase used its own certificate authority, which
Windows had to be told to trust; Azure SQL's certificate comes from a public authority that
Windows already trusts.

---

## 3. Connect Power BI to Azure SQL

Home → **Get data** → Azure → **Azure SQL database** → Connect.

| Field | Value |
| ----- | ----- |
| Server | your server, `….database.windows.net` |
| Database | your database name |
| Data connectivity mode | **Import** |

Then the sign-in box → **Database** tab (not Windows, not Microsoft account) → your SQL login
and password → Connect.

**"Database … is not currently available" (error 40613)** is the free database waking from its
pause. Wait a minute and try again; the pipeline's loader does the same automatically.

In the Navigator, tick these eleven **views**, and nothing else:

| View | What it is |
| ---- | ---------- |
| `phi.dim_date` | One row per day, 2007 to the end of the latest year |
| `phi.dim_state` | The eight states and territories |
| `phi.dim_age_band` | Twenty five-year bands, folded into six groups |
| `phi.dim_gender` | Female and Male |
| `phi.dim_cover` | APRA's four cover types, grouped as full or not full |
| `phi.dim_excess` | Nil, up to 500 dollars, over 500 dollars |
| `phi.fact_policies` | Hospital policies by quarter, state, cover type, excess |
| `phi.fact_insured` | Insured people by quarter, state, gender, age band |
| `phi.fact_population` | Population by quarter and state |
| `phi.fact_population_by_age` | Population by June, gender and age band |
| `phi.reconciliation_panel` | The five published figures against ours |

Not the `phi.` tables (the views are the stable interface), not `stage.`, and not the `v_`
views, which exist for checking numbers in SQL.

Load. Power BI names each table `phi dim_date` and so on: **rename** every one to drop `phi `.

## 4. Build the model, and avoid the classic trap

Model view. These thirteen relationships, all **many to one (\*:1)**, **single** direction,
**active**:

| From (many) | To (one) |
| ----------- | -------- |
| `fact_policies[quarter_end]` | `dim_date[date]` |
| `fact_insured[quarter_end]` | `dim_date[date]` |
| `fact_population[quarter_end]` | `dim_date[date]` |
| `fact_population_by_age[quarter_end]` | `dim_date[date]` |
| `fact_policies[state]` | `dim_state[state]` |
| `fact_insured[state]` | `dim_state[state]` |
| `fact_population[state]` | `dim_state[state]` |
| `fact_insured[age_band_start]` | `dim_age_band[age_band_start]` |
| `fact_population_by_age[age_band_start]` | `dim_age_band[age_band_start]` |
| `fact_insured[gender]` | `dim_gender[gender]` |
| `fact_population_by_age[gender]` | `dim_gender[gender]` |
| `fact_policies[policy_cover]` | `dim_cover[policy_cover]` |
| `fact_policies[excess]` | `dim_excess[excess]` |

`reconciliation_panel` joins nothing: it is a table to read, not a table to filter by.

**Delete every relationship Power BI guessed that is not in the table.** Views have no foreign
keys, so Power BI matches columns by name, and it will happily join two fact tables on
`quarter_end` or `state`. Open Manage relationships and delete any line that joins two facts or
two dimensions.

This is the point to explain in an interview: in a star schema the facts connect to the
dimensions and the dimensions do not connect to each other. Two routes between the same tables
make Power BI either refuse or quietly switch one off, and the numbers stop being trustworthy.
Exactly one path to every table keeps them honest.

**Mark the date table:** select `dim_date` → Table tools → **Mark as date table** → date column
`date`. Then turn off **Auto date/time**: File → Options and settings → Options → Current File →
Data Load.

**Sort by column** (select the column → Column tools → Sort by column):

| Column | Sort by |
| ------ | ------- |
| `dim_date[quarter_label]` | `dim_date[quarter_end]` |
| `dim_age_band[age_band]` | `dim_age_band[age_band_start]` |
| `dim_age_band[age_group]` | `dim_age_band[age_group_order]` |
| `dim_excess[excess]` | `dim_excess[sort_order]` |
| `dim_state[state_name]` | `dim_state[sort_order]` |

Every sort column comes from SQL, so none is a DAX column built from the column it sorts: that
was project 1's circular-dependency error, and it cannot happen here.

**Hide from report view** (right-click → Hide) every column in the four fact tables except the
numbers, and the dimensions' sort columns. Readers pick dates, states, ages and cover types from
the dimensions.

## 5. Apply the theme

Design → **Import theme** → `powerbi/theme.json` (older versions: View → Themes → Browse for
themes). It is project 1's validated colourblind-safe palette, so the two reports read as one
body of work.

**Colour rule:** one accent marks the problem, everything else is grey. Orange `#eb6834` for the
problem, blue `#2a78d6` for what holds up, grey `#9E9C95` for the rest. Set series colours by
hand per visual. Theme slots 3 to 5 sit below 3:1 contrast on the light background, so any chart
that uses them must carry data labels; with one or two series per chart, none here does.

---

## 6. The measures

Home → **Enter data** → name the table `_Measures` → Load. Create every measure below in it, then
delete its dummy column. Each has a description in the Properties pane, copied from the comment.

**The one idea behind most of them.** Policies, insured people and population are counted *at
the end* of each quarter. Adding up quarters would count the same people several times, so a
figure for any period is its **latest quarter**, never a sum of quarters.

### Counts and coverage

```dax
-- People with hospital cover at the end of the latest quarter in view.
Insured Persons =
VAR LastQuarter = MAX ( fact_insured[quarter_end] )
RETURN
    CALCULATE ( SUM ( fact_insured[insured_persons] ), fact_insured[quarter_end] = LastQuarter )

-- Hospital policies at the end of the latest quarter in view.
Hospital Policies =
VAR LastQuarter = MAX ( fact_policies[quarter_end] )
RETURN
    CALCULATE ( SUM ( fact_policies[policies] ), fact_policies[quarter_end] = LastQuarter )

-- State population at the end of the latest quarter in view. A helper: hide it.
Population =
VAR LastQuarter = MAX ( fact_population[quarter_end] )
RETURN
    CALCULATE ( SUM ( fact_population[population] ), fact_population[quarter_end] = LastQuarter )

-- The honest headline: the share of people with hospital cover. Population grows, so a record
-- headcount can hide a falling share.
Coverage Rate = DIVIDE ( [Insured Persons], [Population] )
```

### Change on a year earlier

Blank when there is no year earlier to compare with, rather than a misleading zero.

```dax
Insured Persons, Change on a Year Earlier =
VAR LastQuarter = MAX ( fact_insured[quarter_end] )
VAR YearEarlier = EDATE ( LastQuarter, -12 )
VAR Before =
    CALCULATE (
        SUM ( fact_insured[insured_persons] ),
        REMOVEFILTERS ( dim_date ),
        fact_insured[quarter_end] = YearEarlier
    )
RETURN
    IF ( NOT ISBLANK ( Before ), [Insured Persons] - Before )

Coverage Rate, Change on a Year Earlier =
VAR LastQuarter = MAX ( fact_insured[quarter_end] )
VAR YearEarlier = EDATE ( LastQuarter, -12 )
VAR Before =
    CALCULATE (
        [Coverage Rate],
        REMOVEFILTERS ( dim_date ),
        fact_insured[quarter_end] = YearEarlier,
        fact_population[quarter_end] = YearEarlier
    )
RETURN
    IF ( NOT ISBLANK ( Before ), [Coverage Rate] - Before )
```

`DATEADD` is the usual tool, but here it would compare June 2026 with December 2025: `dim_date`
runs to the end of 2026, so shifting all its dates back a year ends in December 2025. Naming
the exact quarter twelve months earlier avoids that.

### Question 1: downgrading

`KEEPFILTERS` keeps a chart's own filter on cover type or excess, instead of overriding it.

```dax
-- Share of hospital policies with full cover: no reduced cover, no lifetime exclusions.
Full Cover Share =
DIVIDE (
    CALCULATE ( [Hospital Policies], KEEPFILTERS ( dim_cover[cover_group] = "Full cover" ) ),
    CALCULATE ( [Hospital Policies], REMOVEFILTERS ( dim_cover ) )
)

-- Share of hospital policies whose excess is over 500 dollars (single).
Excess Over 500 Share =
DIVIDE (
    CALCULATE ( [Hospital Policies], KEEPFILTERS ( dim_excess[excess] = "Over $500 single" ) ),
    CALCULATE ( [Hospital Policies], REMOVEFILTERS ( dim_excess ) )
)
```

### Question 2: an older pool

Population by age is published once a year, for June. These measures anchor on the latest
June in view, so page 3's charts show only the Junes, and a card shows the latest one.

```dax
-- Share of insured people aged 65 or over, in the latest June with population data.
Share Aged 65+, Insured =
VAR LastJune = MAX ( fact_population_by_age[quarter_end] )
RETURN
    DIVIDE (
        CALCULATE ( SUM ( fact_insured[insured_persons] ), fact_insured[quarter_end] = LastJune,
                    KEEPFILTERS ( dim_age_band[is_65_plus] = TRUE () ) ),
        CALCULATE ( SUM ( fact_insured[insured_persons] ), fact_insured[quarter_end] = LastJune,
                    REMOVEFILTERS ( dim_age_band ) )
    )

-- The same share for all Australians: the comparison that matters.
Share Aged 65+, Australia =
VAR LastJune = MAX ( fact_population_by_age[quarter_end] )
RETURN
    DIVIDE (
        CALCULATE ( SUM ( fact_population_by_age[population] ),
                    fact_population_by_age[quarter_end] = LastJune,
                    KEEPFILTERS ( dim_age_band[is_65_plus] = TRUE () ) ),
        CALCULATE ( SUM ( fact_population_by_age[population] ),
                    fact_population_by_age[quarter_end] = LastJune,
                    REMOVEFILTERS ( dim_age_band ) )
    )

-- How far the insured pool's 65+ share runs ahead of the country's, in percentage points.
Age Gap (points) = ( [Share Aged 65+, Insured] - [Share Aged 65+, Australia] ) * 100

-- Hospital coverage within an age band or group, each June. National only: population by age
-- has no state, so it is blank under a state filter. Also blank where APRA's population table
-- lacks a gender and band that the insured count includes (women 95+, June 2018), rather than
-- a rate with a hole in its denominator.
Coverage Rate by Age =
VAR LastJune = MAX ( fact_population_by_age[quarter_end] )
VAR Insured =
    CALCULATE ( SUM ( fact_insured[insured_persons] ), fact_insured[quarter_end] = LastJune )
VAR People =
    CALCULATE ( SUM ( fact_population_by_age[population] ),
                fact_population_by_age[quarter_end] = LastJune )
VAR InsuredPairs =
    CALCULATE ( COUNTROWS ( SUMMARIZE ( fact_insured, fact_insured[gender], fact_insured[age_band_start] ) ),
                fact_insured[quarter_end] = LastJune )
VAR PeoplePairs =
    CALCULATE ( COUNTROWS ( SUMMARIZE ( fact_population_by_age, fact_population_by_age[gender],
                                        fact_population_by_age[age_band_start] ) ),
                fact_population_by_age[quarter_end] = LastJune )
RETURN
    IF ( NOT ISFILTERED ( dim_state ) && InsuredPairs = PeoplePairs, DIVIDE ( Insured, People ) )
```

### Labels

```dax
-- For every page's header: updates itself when a new release loads.
Data Period =
"APRA data · " & FORMAT ( MIN ( fact_insured[quarter_end] ), "mmmm yyyy" ) & " to "
    & FORMAT ( MAX ( fact_insured[quarter_end] ), "mmmm yyyy" )

-- The June that page 3's cards describe.
Population Year = FORMAT ( MAX ( fact_population_by_age[quarter_end] ), "mmmm yyyy" )
```

**Formats:** counts as whole numbers with separators; `Coverage Rate`, `Full Cover Share`,
`Excess Over 500 Share`, both 65+ shares and `Coverage Rate by Age` as percentages with one
decimal; `Coverage Rate, Change on a Year Earlier` as a percentage with one decimal and a sign
(custom format `+0.0%;-0.0%`); `Insured Persons, Change on a Year Earlier` as `+#,0;-#,0`;
`Age Gap (points)` with one decimal.

**Check them before building pages.** A card of each, with no filters, must show:

| Measure | Value |
| ------- | ----- |
| Insured Persons | 12,823,752 |
| Hospital Policies | 6,268,336 |
| Coverage Rate | 45.8% |
| Insured Persons, Change on a Year Earlier | +292,743 |
| Full Cover Share | 26.8% |
| Excess Over 500 Share | 29.4% |
| Share Aged 65+, Insured / Australia | 20.7% / 17.4% |
| Age Gap (points) | 3.3 |
| Data Period | APRA data · June 2007 to June 2026 |

These match `docs/reconciliation.md`, `docs/series-breaks.md` and the SQL views. If one does not,
fix the measure before going further.

---

## 7. The three pages

Page size 16:9, 1280 × 720. Every page has the same dark header band: a rectangle across the
top, filled `#0D366B` (the theme's darkest blue), with the page's question in white on the left,
and on the right a **page navigator** (Insert → Buttons → Navigator → Page navigator) and a card
showing `Data Period` in light text. Below the band, a row of KPI cards, then the charts.

Each chart title states its finding with the real number. Field names are renamed per visual
into plain English. Every visual has alt text, and every card a tooltip saying what its number
counts. KPI cards get **4px** top and bottom padding, or the label is cut off. No dual-axis
charts: two measures on different scales make two charts. A legend only when a chart has two
or more series. No AI visuals: project 1 replaced them all with plain charts that read faster.

The titles below quote the June 2026 release. If the report keeps refreshing, update them each
quarter, or drive them from measures with the title's **fx** button.

### Page 1 · The headline: *"Membership is at a record. Isn't everything fine?"*

Make the optimistic case honestly, then show the first crack.

| Visual | Title or label | Shows |
| ------ | -------------- | ----- |
| Card | People with hospital cover | `Insured Persons` |
| Card | Change on a year earlier | `Insured Persons, Change on a Year Earlier` |
| Card | Share of Australians covered | `Coverage Rate` |
| Card | Hospital policies | `Hospital Policies` |
| Line chart, blue | A record 12.8 million people now have hospital cover, up 40% since 2007 | `dim_date[quarter_end]` (continuous axis), `Insured Persons` |
| Line chart, orange | …but the share of Australians covered, 45.8%, is still below its 2015 peak of 47.4% | `dim_date[quarter_end]`, `Coverage Rate` |
| Table, small, bottom right | Checked against published figures: 5 of 5 match | `reconciliation_panel`: measure, published_display, ours_display, matches |

The validation panel is not decoration: it is the evidence that every other number on the
report can be trusted, and the first thing a sharp reader will look for.

### Page 2 · Downgrading: *"Are people downgrading instead of leaving?"*

| Visual | Title or label | Shows |
| ------ | -------------- | ----- |
| Card | Hospital policies | `Hospital Policies` |
| Card | With full cover | `Full Cover Share` |
| Card | With an excess over 500 dollars | `Excess Over 500 Share` |
| 100% stacked area | Policies grew 43.5% since 2007, but only 26.8% now give full cover, down from 63.6% | `dim_date[quarter_end]`, `Hospital Policies`, legend `dim_cover[cover_group]`: full cover grey, not full cover orange |
| Line chart, orange | Since the April 2019 rule change, policies with an excess over 500 dollars went from 0.5% to 29.4% | `dim_date[quarter_end]`, `Excess Over 500 Share`; visual filter `quarter_end` from 30 Sep 2010 |
| Bar chart | Full cover is rarest in WA (23.1%) and most common in Tasmania (38.7%) | `dim_state[state_name]`, `Full Cover Share`; visual filter latest quarter; WA orange, the rest grey |
| Text box | Before you renew, check | Three short points: whether the policy excludes treatments you may need; what your excess is per admission; what changed in your cover at renewal |

**Mark the 2019 rule on the excess chart:** Analytics pane → **X-axis constant line** at 1 April
2019, labelled "1 Apr 2019: maximum excess rises to 750 dollars single". If the option is missing
for that visual, put a small text box on the chart at that point instead. The climb after it is
real behaviour that the new rule allowed, and the chart must say so.

**Start the excess chart at September 2010.** "Over 500" drops 4.1 points in one quarter then,
which APRA's notes do not explain, so the earlier levels are not comparable. Say so in the
chart's subtitle. (`docs/series-breaks.md` has the evidence.)

**No ACCC reference line on the cover chart.** The ACCC's 44% measures lifetime exclusions, a
narrower thing than "not full cover", and the split between the two kinds of exclusion cannot be
trended. The ACCC check lives in page 1's validation panel instead.

**Why the state chart uses only the latest quarter:** until September 2009 the ACT is counted
inside NSW, so a 2007 state comparison is not like for like.

### Page 3 · An older pool: *"Is the pool getting older?"*

National figures, each June: population by age has no state split.

| Visual | Title or label | Shows |
| ------ | -------------- | ----- |
| Card | Insured people aged 65+, June 2025 | `Share Aged 65+, Insured`; card subtitle from `Population Year` |
| Card | All Australians aged 65+ | `Share Aged 65+, Australia` |
| Card | Gap, percentage points | `Age Gap (points)` |
| Line chart | Insured people are ageing faster than Australia: aged 65+ rose from 13.3% to 20.7% of the insured, against 13.1% to 17.4% of everyone | `dim_date[quarter_end]`, `Share Aged 65+, Insured` (orange) and `Share Aged 65+, Australia` (grey) |
| Clustered column chart | Coverage rose most among 80- to 89-year-olds, up 18 to 19 points since 2007, and fell among 25- to 34- and 50- to 64-year-olds | `dim_age_band[age_band]`, `Coverage Rate by Age`, legend `dim_date[year]`; visual filter years 2007 and 2025; 2007 grey, 2025 orange |
| Text box, small | About this page | National only. In June 2018 APRA's population table lacks women aged 95+, so that band is blank that year. |

Do not explain *why* the pool is ageing (for example a cohort effect from Lifetime Health Cover
in 2000) unless published work says so, and cite it if it does.

---

## 8. Save it as code

File → **Save as** → navigate into the cloned repo's `powerbi/` folder → save as a **Power BI
project (.pbip)** named `MoreMembersLessCover`. If Save as does not offer .pbip, enable it first:
File → Options and settings → Options → Preview features → **Power BI Project (.pbip) save
option** → restart Power BI Desktop.

That writes a folder of plain-text files (the model, every measure, every page's layout)
instead of one opaque binary. Commit it:

```
git add powerbi/
git commit -m "Add the Power BI report: model, measures and three pages"
git push
```

`.gitignore` already excludes `.pbi/localSettings.json` and `cache.abf`, machine-specific files
that would churn on every commit.

## 9. Export and images

**PDF.** File → Export → **Export to PDF**. Power BI asks for no file name: it builds the file
and opens it in Edge from its temp folder, `%TEMP%\2\Power BI Desktop\print-job-…\`. Copy it from
there to `docs/more-members-less-cover.pdf`, commit and push.

**README images** are rendered from that PDF on the Mac, never screenshotted from the remote
desktop, which scales the screen and blurs the text. The PDF holds real text, so rendered pages
stay sharp: `pip install pymupdf` in the venv, then render each page 1800 px wide into
`docs/img/`.

For LinkedIn, post the PDF itself as a document: it shows as a swipeable carousel.

## 10. Refresh and publishing (Nandita's call)

Publishing needs a work or school address (a Gmail address is rejected): an address on your own
datavalix.com domain works. Home → **Publish** → My workspace; for a public link, in the Power BI
service: the report → File → **Embed report** → *Publish to web (public)*.

Scheduled refresh reads Azure with the same SQL login. Every refresh wakes the free database and
uses its monthly allowance, so refresh once a day at most; if the first try of the day fails,
the database was waking. If Azure is retired later, the published report keeps its last data:
call it a snapshot in the README, not a live dashboard.

---

## If something does not work

| Symptom | Cause |
| ------- | ----- |
| "Database … is not currently available" | The free database is waking from its pause. Wait a minute and retry |
| "Cannot open server … Client with IP address … is not allowed" | The EC2 machine's new address is not in Azure's firewall. Add it, §1 |
| Tables are called `phi dim_date` | Power BI adds the schema. Rename them, §3 |
| A line chart's numbers are several times too big | Something sums quarters. Use the measures in §6, which take the latest quarter |
| "Can't determine relationships", or the same value on every bar | A fact-to-fact or dimension-to-dimension relationship crept in. Delete it, §4 |
| Changes on a year earlier are blank | Expected in the first year of data. Otherwise `dim_date` is not marked as the date table, §4 |
| Coverage by age is blank | Expected with a state selected, and for women 95+ in June 2018, §6 |
| Page 3's charts show every quarter but no values between Junes | Expected: population by age is yearly. The values sit on the Junes |
| An axis sorts alphabetically | Set the sort-by column, §4 |
| A card's label is cut off under the number | Set the card's top and bottom padding to 4px |
| A chart ignores a per-bar colour rule | Combo charts do. Use a plain bar chart, or two measures with fixed colours |
| Export to PDF seems to do nothing | It opened in Edge from Power BI's temp folder, §9 |
| Windows App error 0x704 | The saved PC has an old IP. Add it again with the new one |
| Copy and paste do not work in the remote desktop | Paste with Ctrl+V. If that fails, add the PC again with **Clipboard** ticked |
