# Who this is for

The report and the README are written for the general public: the complete story behind a
headline number. This page names the professional audience whose decisions the same measures
support, and writes their requirements as user stories. Each story is tied to a measure in the
report and checked against a SQL view, so "done" is testable. Stories the data cannot support
are struck, with the reason.

## The audience

**A health insurer's product team**: the people who decide which hospital products to offer,
how to set the excess options, and which age groups a product is designed for. They hold their
own book's data. What they lack is the market-wide picture, quarterly, by state and by age band,
that sits in APRA's spreadsheets and is published nowhere in a usable form.

## The stories

"Matches the view" means the Power BI measure returns the same figure as the named view in
`sql/views.sql`, which is the check that was run before the report was built.

> **As a** product manager at a health insurer
> **I want** the share of hospital policies with full cover, each quarter since 2007, nationally
> and by state
> **so that** I can benchmark our book's cover mix against the market and see where thin cover
> is already the norm.
> **Done when:** `Full Cover Share` matches `phi.v_cover_mix` in every quarter, the state
> comparison uses the latest quarter, and the lifetime-exclusions share from the same table
> reproduces the ACCC's published June 2018 figure ([reconciliation](reconciliation.md)).

> **As a** pricing analyst
> **I want** the share of hospital policies carrying an excess over 500 dollars (single), each
> quarter, with the 1 April 2019 rule change marked
> **so that** I can see how quickly the market moved to the higher excess the rules allowed, and
> set our excess options against it.
> **Done when:** `Excess Over 500 Share` matches `phi.v_cover_mix` in every quarter from
> September 2010 (earlier quarters are excluded: [series breaks](series-breaks.md) records the
> unexplained break), every chart of it marks 1 April 2019, and the June 2018 share with any
> excess reproduces the ACCC's published figure.

> **As an** actuary on the product team
> **I want** the share of insured people aged 65 and over each June, beside the same share of
> all Australians
> **so that** I can separate the pool's own ageing from Australia's.
> **Done when:** `Share Aged 65+, Insured` and `Share Aged 65+, Australia` match `phi.v_age_mix`
> for every June, and the one gap in APRA's population table (women aged 95 and over, June 2018)
> is documented rather than filled.

> **As a** product manager
> **I want** the share of each five-year age band holding hospital cover, June 2007 against the
> latest June
> **so that** I can see which ages are joining and which are leaving, and design for them.
> **Done when:** `Coverage Rate by Age` matches `phi.v_coverage_by_age` for every band and
> June, and the 25 to 29 figure for June 2025 reproduces CHOICE's published figure
> ([reconciliation](reconciliation.md)).

> **As the** team's analytics lead
> **I want** every published figure the report relies on rebuilt from APRA's raw files and
> compared on the report itself, and the data refreshed each quarter without anyone touching it
> **so that** the team can act on the numbers without re-checking them.
> **Done when:** the reconciliation panel shows every published figure matched at its published
> precision, the quarterly GitHub Actions run loads a new APRA release unattended and stops on
> any failed check ([automation](automation.md)), and the report's data period updates by itself.

## Struck stories

| Story | Why the data cannot support it |
| ----- | ------------------------------ |
| Which product tiers (Gold, Silver, Bronze, Basic) are losing members, by age and state | APRA's spreadsheets carry no tier field. The only "Gold" in them is the DVA Gold Card, a veterans' entitlement. Cover type and excess level stand in, and reach back to 2007 where tiers begin in 2019. |
| Whether our members downgraded, or new members bought thinner cover | APRA counts the mix of policies at each quarter end, not who moved. Aggregate data cannot separate downgrading by existing members from new entrants buying less. |
| Coverage by age within each state | APRA's population by age is national only, so a state's coverage rate by age has no denominator. |
| How our book compares with the market | APRA's public data is industry-wide; nothing in it identifies an insurer. The report supplies the market side of that comparison only. |

## No external review

This project was built independently. No insurer's product team reviewed it, and that is stated
here so the claim is exactly as large as the evidence: requirements written for a named audience
and built against them, not requirements validated by that audience.
