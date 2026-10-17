# Prior work

Read this before writing a single sentence of findings.

Australian private health insurance is one of the most heavily analysed markets in the country.
A regulator reports on it to Parliament annually. A professional actuarial body publishes papers
on it. A consumer organisation tracks it continuously. **Anything this project finds will already
be in someone's PDF.**

That is not a reason to abandon the project. It is a reason to be precise about what is being
claimed — and it is the thing that makes the honesty rules in the README enforceable rather than
decorative.

---

## Who publishes what

### ACCC — annual report to the Senate

The ACCC has reported on private health insurance to the Senate every year for more than two
decades, under a standing order. The reports cover exactly the downgrading question this project
asks: the share of hospital policies carrying exclusions, the share carrying an excess or
co-payment, movement between hospital and extras-only cover.

To give a sense of the granularity — from one such report, covering 2017-18:

- 45.1% of the population held hospital cover in June 2018, down 0.9 points on the year
- Extras-only cover rose from 8.9% to 9.2%
- 44% of hospital policies carried exclusions, up from 40%
- Policies with an excess or co-payment rose from 83% to 84%

That is the level of detail already in the public record, annually, going back years.

[ACCC media release and report](https://www.accc.gov.au/media-release/australians-exiting-private-health-insurance-as-price-rises-bite)

### CHOICE — continuously updated statistics

CHOICE maintains a public statistics page drawing on APRA data. It carries the tier mix over
time, membership by age band, and coverage rates. As at mid-2026 it reported:

- Gold hospital cover: 40.1% of policies (Dec 2020) → 29.3% (Dec 2025)
- Silver: 32.5% → 37.6% · Bronze: 16.5% → 21.9% · Basic: steady near 11%
- Hospital cover 45.6%, extras 55.3% of the population
- Coverage rises with age: lowest at 25–29 (26.3%), highest at 80–84 (55.9%)
- Gold premiums have risen faster than the average across all policies

[CHOICE — private health insurance statistics](https://www.choice.com.au/money/insurance/health/articles/private-health-insurance-statistics-in-australia)

### Actuaries Institute — the Gold tier

The obvious economic reading of the tier shift — that Gold cover is in an adverse-selection
spiral, where rising premiums drive out the healthy, which worsens the pool, which raises
premiums again — **has already been studied by actuaries**, who have better data and better
methods for it than this project will.

- [Is the Gold Hospital Private Health Insurance Category Ill?](https://www.actuaries.asn.au/research-analysis/is-the-gold-hospital-private-health-insurance-category-ill)
- [Time to Rethink Risk Equalisation to Save Gold Hospital](https://www.actuaries.asn.au/research-analysis/time-to-rethink-risk-equalisation-to-save-gold-hospital)

Do not reinvent this. Cite it.

### APRA — the source data

APRA is where the numbers above originate. It publishes quarterly and annual private health
insurance statistics as spreadsheets, free to download.

[APRA — Quarterly private health insurance statistics](https://www.apra.gov.au/quarterly-private-health-insurance-statistics)

### Press coverage

The downgrading story has reached general news — the ABC covered consumers discovering exclusions
after moving off Gold policies (February 2026), and CHOICE's analysis of Gold premium rises
(March 2026). It is not an obscure topic.

---

## What this means for the claims this project makes

| Claim | Allowed? |
| ----- | -------- |
| "I found that people are downgrading" | **No.** The ACCC has reported this for years |
| "Gold cover is in an adverse-selection spiral" | **No.** The Actuaries Institute got there, with better data |
| "I reproduced the published tier shift from APRA's raw files and it matches" | **Yes** — and this is the valuable part |
| "Here is that shift broken down by age and state, which the published work does not do" | **Yes**, if the data supports it |
| "Here it is as a live dashboard rather than an annual PDF" | **Yes** — a real contribution of form, not of finding |

## The interview answer this produces

> "Private health insurance is well covered — the ACCC reports on it annually and the Actuaries
> Institute has published on the Gold tier specifically. I wasn't trying to find something new.
> I rebuilt their measures from APRA's raw spreadsheets to prove my pipeline was right, then
> added the age and state breakdown that the published work doesn't carry."

That is a stronger thing to be able to say than any invented discovery, and it is true.
