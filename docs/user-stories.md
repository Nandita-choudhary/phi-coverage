# Who this is for

The weakest thing about a portfolio project is that nobody asked for it. This page fixes that,
and it is the cheapest high-value part of the whole build.

**Do this in week 1, not at the end.** It is the only step that depends on another human saying
yes, so it needs the longest lead time. Write the stories today, send the email today, build
while you wait for a reply.

---

## The audience

Pick one and name them. The dashboard is built for *them*, which decides what goes on it.

| Candidate | What they would want to know |
| --------- | ---------------------------- |
| A health insurer's product team | Which tiers are losing members, in which age bands and states — where to reprice or redesign |
| A consumer advocacy group | Whether people are ending up with less cover than they think they bought |
| A health policy researcher | Whether the risk pool is ageing, and how fast |

**Chosen audience:** *(fill this in — one line on who they are and what decision they face)*

## The stories

Four or five, in the form you already use at Gyaanam. Each one has to be answerable by
something on the dashboard, and each one needs an acceptance criterion, or it is a wish rather
than a requirement.

> **As a** product analyst at a health insurer
> **I want to** see policy mix by tier for each quarter over the last five years
> **so that** I can tell whether the shift out of Gold is accelerating or levelling off.
> **Done when:** the tier mix chart covers every quarter available and the Gold share for the
> most recent quarter matches APRA's published figure.

> **As a** product analyst
> **I want to** break coverage down by age band
> **so that** I can see whether the risk pool is ageing beneath a stable headcount.
> **Done when:** coverage rate by age band is shown for the latest quarter and as a trend.

*(write three more — one on state, one on the validation table, one on refresh currency)*

Keep them honest: if the data turns out not to support a story, strike it and write down why.
A struck story with a reason is better evidence of judgement than five that were never tested.

## No external review — a deliberate choice

This project is built independently, and no outside reviewer is involved. That is recorded here
rather than left vague, because the alternative is a resume line nobody can verify.

**What is claimed:** requirements written as user stories for a named audience, and built
against them.

**What is not claimed:** that anyone reviewed the findings. If someone does later — a LinkedIn
reply, an email that lands — add `docs/review-notes.md` with who, when, what they said and what
changed, and update the README then.

> "I wrote the requirements as user stories for an insurer's product team and built against
> them."

That is true, it is the part that needs nobody's permission, and it still puts the project ahead
of most — because most portfolio projects were built for nobody at all.
