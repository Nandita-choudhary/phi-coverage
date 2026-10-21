"""
Write every headline figure once, from the tidy tables, each with its unit and period.

    .venv/bin/python etl/findings.py

Outputs:
  data/findings.json   every figure: id, label, value, display, unit, period, kind, note;
                       plus the tables the report draws (full cover by state, age mix,
                       coverage by age band, reconciliation)
  docs/findings.md     the same figures as tables, generated whole
  README.md            only the blocks between <!-- findings:NAME --> and
                       <!-- /findings:NAME --> markers are rewritten; a README without
                       markers is left alone

The rule this enforces: a number that is not in findings.json does not belong in a sentence
anywhere in the repo. Every figure says what it counts (unit), when (period) and what kind of
number it is: a stock counted at a quarter end, a share of such a stock, a change between two
dates, or a growth rate between two dates. The quarterly workflow runs this after the checks,
so the README moves with each APRA release.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date, datetime
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
CLEAN = ROOT / "data" / "clean"
JSON_OUT = ROOT / "data" / "findings.json"
MD_OUT = ROOT / "docs" / "findings.md"
README = ROOT / "README.md"
EVENTS = ROOT / "data" / "policy_events.json"

FULL_COVER = "Full cover"
OVER_500 = "Over $500 single"
RULE_CHANGE_QUARTER = "2019-03-31"      # the last quarter before the 1 April 2019 excess rule
EXCESS_BREAK = ("2010-06-30", "2010-09-30")   # the unexplained step in the over-500 series
AGE_GROUPS = [("Under 25", 0, 24), ("25 to 49", 25, 49), ("50 to 64", 50, 64), ("65 and over", 65, 200)]
KINDS = {
    "stock": "a quantity counted at the end of the quarter named, such as people or policies",
    "share": "one stock as a percentage of another at the same date",
    "gap": "the difference between two shares at the same date, in percentage points",
    "change": "the difference between the two dates named, in the unit shown",
    "growth": "the percentage change between the two dates named",
    "count": "a tally of items in one of this project's own tables, such as age bands or checked figures",
    "proportion": "one change as a percentage of another change",
    "difference": "the percentage by which one series exceeds another at the same date",
}


# ------------------------------------------------------------------ formatting helpers
def _d(q: str) -> date:
    return datetime.strptime(q, "%Y-%m-%d").date()


def month_year(q: str) -> str:
    return _d(q).strftime("%B %Y")


def as_at(q: str) -> str:
    d = _d(q)
    return f"{d.day} {d.strftime('%B %Y')}"


def fmt(value: float, unit: str, kind: str) -> str:
    if kind == "difference":
        return f"{value:+.2f}%"
    if unit in ("people", "policies"):
        return f"{value:+,.0f} {unit}" if kind == "change" else f"{value:,.0f} {unit}"
    if unit == "points":
        return f"{value:+.1f} points" if kind == "change" else f"{value:.1f} points"
    if kind == "count":
        return f"{value:,.0f} {unit}"
    if unit.startswith("%"):
        return f"{value:+.1f}%" if kind in ("change", "growth") else f"{value:.1f}%"
    return f"{value}"


def table(rows: list[dict], columns: list[str]) -> str:
    head = "| " + " | ".join(columns) + " |"
    rule = "| " + " | ".join("-" * max(3, len(c)) for c in columns) + " |"
    body = ["| " + " | ".join(str(r[c]) for c in columns) + " |" for r in rows]
    return "\n".join([head, rule, *body])


# ------------------------------------------------------------------ the figures
class Findings:
    def __init__(self) -> None:
        self.figures: list[dict] = []
        self.tables: dict[str, list[dict]] = {}

    def add(self, fid: str, label: str, value: float, unit: str, period: str, kind: str,
            note: str = "") -> dict:
        row = {"id": fid, "label": label, "value": float(value), "display": fmt(value, unit, kind),
               "unit": unit, "period": period, "kind": kind, "note": note}
        self.figures.append(row)
        return row

    def get(self, fid: str) -> dict:
        return next(f for f in self.figures if f["id"] == fid)


def build() -> tuple[Findings, dict]:
    insured = pd.read_csv(CLEAN / "insured_by_age.csv")
    population = pd.read_csv(CLEAN / "population.csv")
    policies = pd.read_csv(CLEAN / "policies_by_cover.csv")
    pop_age = pd.read_csv(CLEAN / "population_by_age.csv")
    recon = pd.read_csv(CLEAN / "reconciliation.csv")

    f = Findings()

    # ---- the quarters the figures stand on
    first_q = min(insured.quarter_end)
    latest_q = max(insured.quarter_end)
    year_earlier = f"{int(latest_q[:4]) - 1}{latest_q[4:]}"
    latest_june_age = max(pop_age.quarter_end)           # population by age is annual, each June
    first_june_age = min(pop_age.quarter_end)
    if latest_june_age not in set(insured.quarter_end):
        sys.exit(f"insured persons has no {latest_june_age} quarter to set against population by age")
    release = {"latest_quarter": latest_q, "latest_quarter_label": month_year(latest_q),
               "first_quarter": first_q, "first_quarter_label": month_year(first_q),
               "latest_june_with_population_by_age": latest_june_age,
               "latest_june_with_population_by_age_label": month_year(latest_june_age)}

    at = lambda q: f"as at {as_at(q)}"                      # noqa: E731
    span = lambda a, b: f"{as_at(a)} to {as_at(b)}"         # noqa: E731

    # ---- headline: people, population, coverage, policies
    ins_q = insured.groupby("quarter_end")["insured_persons"].sum()
    pop_q = population.groupby("quarter_end")["population"].sum()
    rate_q = (ins_q / pop_q * 100).dropna()
    pol_q = policies.groupby("quarter_end")["policies"].sum()

    f.add("insured_latest", "People with hospital cover", ins_q[latest_q], "people", at(latest_q), "stock",
          "The highest in the series" if ins_q[latest_q] == ins_q.max() else "")
    f.add("insured_first", "People with hospital cover", ins_q[first_q], "people", at(first_q), "stock")
    f.add("insured_growth", "People with hospital cover, growth",
          (ins_q[latest_q] / ins_q[first_q] - 1) * 100, "%", span(first_q, latest_q), "growth")
    f.add("insured_change_year", "People with hospital cover, change on a year earlier",
          ins_q[latest_q] - ins_q[year_earlier], "people", f"year to {as_at(latest_q)}", "change")
    f.add("insured_change_year_pct", "People with hospital cover, change on a year earlier",
          (ins_q[latest_q] / ins_q[year_earlier] - 1) * 100, "%", f"year to {as_at(latest_q)}", "growth")
    f.add("population_latest", "Australia's population", pop_q[latest_q], "people", at(latest_q), "stock",
          "ABS figures as APRA publishes them")
    f.add("population_first", "Australia's population", pop_q[first_q], "people", at(first_q), "stock")
    f.add("population_growth", "Australia's population, growth",
          (pop_q[latest_q] / pop_q[first_q] - 1) * 100, "%", span(first_q, latest_q), "growth")
    f.add("coverage_latest", "Share of Australians with hospital cover", rate_q[latest_q],
          "% of population", at(latest_q), "share")
    f.add("coverage_first", "Share of Australians with hospital cover", rate_q[first_q],
          "% of population", at(first_q), "share")
    peak_q = rate_q.idxmax()
    f.add("coverage_peak", "Share of Australians with hospital cover, peak", rate_q[peak_q],
          "% of population", at(peak_q), "share", "The highest quarter in the series")
    low_q = rate_q[rate_q.index > peak_q].idxmin()
    f.add("coverage_low_since_peak", "Share of Australians with hospital cover, low since the peak",
          rate_q[low_q], "% of population", at(low_q), "share")
    f.add("coverage_change_since_peak", "Share of Australians with hospital cover, change since the peak",
          rate_q[latest_q] - rate_q[peak_q], "points", span(peak_q, latest_q), "change")
    f.add("policies_latest", "Hospital policies", pol_q[latest_q], "policies", at(latest_q), "stock",
          "One policy can cover several people")
    f.add("policies_first", "Hospital policies", pol_q[first_q], "policies", at(first_q), "stock")
    f.add("policies_growth", "Hospital policies, growth", (pol_q[latest_q] / pol_q[first_q] - 1) * 100,
          "%", span(first_q, latest_q), "growth")

    # ---- downgrading: full cover and excess
    full_q = policies[policies.policy_cover == FULL_COVER].groupby("quarter_end")["policies"].sum() / pol_q * 100
    over_q = policies[policies.excess == OVER_500].groupby("quarter_end")["policies"].sum() / pol_q * 100
    f.add("full_cover_first", "Hospital policies with full cover", full_q[first_q],
          "% of hospital policies", at(first_q), "share", "No reduced cover and no lifetime exclusions")
    f.add("full_cover_latest", "Hospital policies with full cover", full_q[latest_q],
          "% of hospital policies", at(latest_q), "share")
    f.add("full_cover_change", "Hospital policies with full cover, change", full_q[latest_q] - full_q[first_q],
          "points", span(first_q, latest_q), "change")
    f.add("excess_over_500_before_rule", "Hospital policies with an excess over $500 (single)",
          over_q[RULE_CHANGE_QUARTER], "% of hospital policies", at(RULE_CHANGE_QUARTER), "share",
          "The last quarter before the 1 April 2019 rule change raised the maximum excess to $750 single")
    f.add("excess_over_500_latest", "Hospital policies with an excess over $500 (single)", over_q[latest_q],
          "% of hospital policies", at(latest_q), "share")
    f.add("excess_over_500_step_2010", "Hospital policies with an excess over $500 (single), unexplained step",
          over_q[EXCESS_BREAK[1]] - over_q[EXCESS_BREAK[0]], "points", span(*EXCESS_BREAK), "change",
          "APRA's notes do not explain it; the series is used from this quarter on (docs/series-breaks.md)")

    nil_q = policies[policies.excess == "Nil"].groupby("quarter_end")["policies"].sum() / pol_q * 100
    f.add("nil_excess_first", "Hospital policies with no excess", nil_q[first_q],
          "% of hospital policies", at(first_q), "share")
    f.add("nil_excess_latest", "Hospital policies with no excess", nil_q[latest_q],
          "% of hospital policies", at(latest_q), "share")
    after_rule = next(q for q in sorted(full_q.index) if q > RULE_CHANGE_QUARTER)
    f.add("full_cover_before_rule", "Hospital policies with full cover", full_q[RULE_CHANGE_QUARTER],
          "% of hospital policies", at(RULE_CHANGE_QUARTER), "share", "The last quarter before the April 2019 reforms")
    f.add("full_cover_after_rule", "Hospital policies with full cover", full_q[after_rule],
          "% of hospital policies", at(after_rule), "share", "The first quarter after the April 2019 reforms")
    previous_q = sorted(full_q.index)[-2]
    f.add("full_cover_change_latest_quarter", "Hospital policies with full cover, change in the latest quarter",
          full_q[latest_q] - full_q[previous_q], "points", span(previous_q, latest_q), "change")

    latest_pol = policies[policies.quarter_end == latest_q]
    by_state = (latest_pol[latest_pol.policy_cover == FULL_COVER].groupby("state")["policies"].sum()
                / latest_pol.groupby("state")["policies"].sum() * 100).sort_values()
    f.tables["full_cover_by_state"] = [
        {"state": s, "full_cover_share": round(v, 2), "display": f"{v:.1f}%",
         "gap_to_australia_points": round(v - full_q[latest_q], 2),
         "gap_display": f"{v - full_q[latest_q]:+.1f} points",
         "unit": "% of hospital policies", "period": at(latest_q), "kind": "share"}
        for s, v in by_state.items()]
    f.add("full_cover_lowest_state", f"Hospital policies with full cover, lowest state ({by_state.index[0]})",
          by_state.iloc[0], "% of hospital policies", at(latest_q), "share")
    f.add("full_cover_highest_state", f"Hospital policies with full cover, highest state ({by_state.index[-1]})",
          by_state.iloc[-1], "% of hospital policies", at(latest_q), "share")

    # ---- ageing: 65 and over, the age mix, coverage by band
    def share_65(df: pd.DataFrame, col: str, q: str) -> float:
        d = df[df.quarter_end == q]
        return d[d.age_band_start >= 65][col].sum() / d[col].sum() * 100

    ages = {"insured": (insured, "insured_persons"), "australia": (pop_age, "population")}
    for who, (df, col) in ages.items():
        label = "insured people" if who == "insured" else "all Australians"
        unit = "% of insured people" if who == "insured" else "% of Australians"
        for tag, q in (("first", first_june_age), ("latest", latest_june_age)):
            f.add(f"share_65_plus_{who}_{tag}", f"Aged 65 and over, share of {label}", share_65(df, col, q),
                  unit, at(q), "share")
    for tag, q in (("first", first_june_age), ("latest", latest_june_age)):
        f.add(f"age_gap_{tag}", "Aged 65 and over: insured share minus Australia's share",
              share_65(insured, "insured_persons", q) - share_65(pop_age, "population", q),
              "points", at(q), "gap")

    for who, (df, col) in ages.items():
        label = "insured people" if who == "insured" else "all Australians"
        f.add(f"share_65_plus_{who}_change", f"Aged 65 and over, share of {label}, change",
              share_65(df, col, latest_june_age) - share_65(df, col, first_june_age), "points",
              span(first_june_age, latest_june_age), "change")
    f.add("share_65_plus_insured_latest_quarter", "Aged 65 and over, share of insured people",
          share_65(insured, "insured_persons", latest_q), "% of insured people", at(latest_q), "share",
          "The latest quarter; the comparison with Australia stops at the latest June with population by age")

    mix_rows = []
    for who, (df, col) in ages.items():
        for q in (first_june_age, latest_june_age):
            d = df[df.quarter_end == q]
            total = d[col].sum()
            for group, lo, hi in AGE_GROUPS:
                v = d[(d.age_band_start >= lo) & (d.age_band_start <= hi)][col].sum() / total * 100
                mix_rows.append({"population": "Insured people" if who == "insured" else "All Australians",
                                 "june": month_year(q), "age_group": group, "share": round(v, 2),
                                 "display": f"{v:.1f}%", "unit": "% of that population", "period": at(q),
                                 "kind": "share"})
    f.tables["age_mix"] = mix_rows

    band_rows = []
    label_of = insured.drop_duplicates("age_band_start").set_index("age_band_start")["age_band"]
    i0 = insured[insured.quarter_end == first_june_age].groupby("age_band_start")["insured_persons"].sum()
    i1 = insured[insured.quarter_end == latest_june_age].groupby("age_band_start")["insured_persons"].sum()
    p0 = pop_age[pop_age.quarter_end == first_june_age].groupby("age_band_start")["population"].sum()
    p1 = pop_age[pop_age.quarter_end == latest_june_age].groupby("age_band_start")["population"].sum()
    for band in sorted(i0.index):
        r0, r1 = i0[band] / p0[band] * 100, i1[band] / p1[band] * 100
        band_rows.append({"age_band": label_of[band], "coverage_first": round(r0, 2), "coverage_latest": round(r1, 2),
                          "change_points": round(r1 - r0, 2), "display": f"{r0:.1f}% to {r1:.1f}% ({r1 - r0:+.1f} points)",
                          "unit": "% of people in the band", "period": span(first_june_age, latest_june_age),
                          "kind": "share and change"})
    f.tables["coverage_by_band"] = band_rows
    top = max(band_rows, key=lambda r: r["change_points"])
    f.add("coverage_by_band_largest_rise", f"Coverage rise, largest age band ({top['age_band']})",
          top["change_points"], "points", span(first_june_age, latest_june_age), "change")
    fell = [r["age_band"] for r in band_rows if r["change_points"] < 0]
    f.add("coverage_by_band_bands_that_fell", "Age bands whose coverage fell", len(fell), "bands",
          span(first_june_age, latest_june_age), "count", ", ".join(fell))
    f.get("coverage_by_band_bands_that_fell")["display"] = f"{len(fell)} of {len(band_rows)} bands"

    # ---- why the pool aged: Australia ageing against change in coverage within age groups
    c0, c1 = i0 / p0, i1 / p1                      # coverage rate by band, first and latest June

    def share_65_implied(rates: pd.Series, pop: pd.Series) -> float:
        insured_by_band = rates * pop
        return insured_by_band[insured_by_band.index >= 65].sum() / insured_by_band.sum() * 100

    s0, s1 = share_65_implied(c0, p0), share_65_implied(c1, p1)
    ageing_first = share_65_implied(c0, p1) - s0        # first June's rates on the latest population
    coverage_after_ageing = s1 - share_65_implied(c0, p1)
    coverage_first = share_65_implied(c1, p0) - s0      # latest rates on the first June's population
    ageing_after_coverage = s1 - share_65_implied(c1, p0)
    interaction = (s1 - s0) - ageing_first - coverage_first
    kitagawa_ageing = (ageing_first + ageing_after_coverage) / 2
    kitagawa_coverage = (coverage_after_ageing + coverage_first) / 2
    period = span(first_june_age, latest_june_age)
    rise = "Rise in the insured 65 and over share"
    f.add("decomp_ageing_first", f"{rise} from Australia ageing, with the first June's coverage rates held",
          ageing_first, "points", period, "change")
    f.add("decomp_coverage_after_ageing", f"{rise} from change in coverage within age groups, after ageing",
          coverage_after_ageing, "points", period, "change")
    f.add("decomp_coverage_first", f"{rise} from change in coverage within age groups, with the first June's population held",
          coverage_first, "points", period, "change")
    f.add("decomp_ageing_after_coverage", f"{rise} from Australia ageing, after the coverage change",
          ageing_after_coverage, "points", period, "change")
    f.add("decomp_interaction", f"{rise}: interaction of the two, attributable to neither alone",
          interaction, "points", period, "change")
    f.add("decomp_kitagawa_ageing", f"{rise} from Australia ageing, Kitagawa average of both orderings",
          kitagawa_ageing, "points", period, "change")
    f.add("decomp_kitagawa_coverage", f"{rise} from change in coverage within age groups, Kitagawa average",
          kitagawa_coverage, "points", period, "change")
    f.add("decomp_kitagawa_ageing_proportion", "Australia ageing as a proportion of the rise, Kitagawa average",
          kitagawa_ageing / (s1 - s0) * 100, "% of the rise in the insured 65 and over share", period, "proportion")
    pt = lambda v, name: f"{name} {v:+.1f} points"   # noqa: E731
    f.tables["ageing_decomposition"] = [
        {"method": "First June's coverage rates held, ageing first", "ageing": pt(ageing_first, "ageing"),
         "coverage_change": pt(coverage_after_ageing, "coverage change"), "interaction": ""},
        {"method": "First June's population held, coverage change first", "ageing": pt(ageing_after_coverage, "ageing"),
         "coverage_change": pt(coverage_first, "coverage change"), "interaction": ""},
        {"method": "Pure effects and their interaction", "ageing": pt(ageing_first, "ageing"),
         "coverage_change": pt(coverage_first, "coverage change"), "interaction": pt(interaction, "interaction")},
        {"method": "Kitagawa average of the two orderings", "ageing": pt(kitagawa_ageing, "ageing"),
         "coverage_change": pt(kitagawa_coverage, "coverage change"), "interaction": ""},
    ]

    groups = [("Children, 0 to 14", 0, 14), ("15 to 24", 15, 24), ("25 to 34", 25, 34), ("35 to 39", 35, 39),
              ("40s, 40 to 49", 40, 49), ("50 to 64", 50, 64), ("65 and over", 65, 200), ("Under 65", 0, 64)]
    group_rows = []
    for name, lo, hi in groups:
        m = (i0.index >= lo) & (i0.index <= hi)
        r0 = i0[m].sum() / p0[m].sum() * 100
        r1 = i1[m].sum() / p1[m].sum() * 100
        group_rows.append({"age_group": name, "coverage_first": round(r0, 2), "coverage_latest": round(r1, 2),
                           "change_points": round(r1 - r0, 2), "display": f"{r0:.1f}% to {r1:.1f}% ({r1 - r0:+.1f} points)",
                           "unit": "% of people in the group", "period": period, "kind": "share and change"})
    f.tables["coverage_by_group"] = group_rows
    for fid, name in (("coverage_under_65_change", "Under 65"), ("coverage_65_plus_change", "65 and over"),
                      ("coverage_25_34_change", "25 to 34"), ("coverage_50_64_change", "50 to 64"),
                      ("coverage_children_change", "Children, 0 to 14"), ("coverage_40s_change", "40s, 40 to 49")):
        r = next(g for g in group_rows if g["age_group"] == name)
        f.add(fid, f"Coverage, {name.lower()}, change", r["change_points"], "points", period, "change")
    by_age_total = p1.sum()
    quarterly_total = pop_q[latest_june_age]
    f.add("population_by_age_table_latest_june", "Australia's population, APRA's annual population-by-age table",
          by_age_total, "people", at(latest_june_age), "stock",
          "The denominator for every coverage-by-age figure")
    f.add("population_quarterly_latest_june", "Australia's population, APRA's quarterly population series",
          quarterly_total, "people", at(latest_june_age), "stock",
          "The denominator for the headline coverage rate and the reconciliation")
    f.add("population_series_difference", "Population-by-age table against the quarterly series",
          (by_age_total / quarterly_total - 1) * 100, "%", at(latest_june_age), "difference",
          "APRA publishes two population series; coverage by age uses the annual one, so its rates sit slightly "
          "below the headline rate for the same June")

    # ---- how far our sums sit from APRA's own totals
    totals = pd.read_csv(CLEAN / "published_totals.csv").set_index(["quarter_end", "state"])
    ours_pol = policies.groupby(["quarter_end", "state"])["policies"].sum()
    ours_ins = insured.groupby(["quarter_end", "state"])["insured_persons"].sum()
    diff_pol = (ours_pol - totals["hospital_policies"]).abs() / totals["hospital_policies"] * 100
    diff_ins = (ours_ins - totals["hospital_insured_persons"]).abs() / totals["hospital_insured_persons"] * 100
    worst = max(diff_pol.dropna().max(), diff_ins.dropna().max())
    row = f.add("apra_totals_max_difference", "Largest difference between our sums and APRA's own totals",
                worst, "% of the published total", "any state and quarter", "share",
                "APRA's detail tables and its totals do not agree exactly; etl/checks.py allows a small tolerance")
    row["display"] = f"{worst:.3f}%"

    # ---- policy events and reporting changes, from data/policy_events.json
    events = json.loads(EVENTS.read_text(encoding="utf-8"))
    f.tables["policy_events"] = [{"date": e["date"], "date_label": as_at(e["date"]), "background": e.get("background", False),
                                  **{k: e[k] for k in ("label", "what", "source_name", "source", "explains")}}
                                 for e in sorted(events["events"], key=lambda e: e["date"])]
    f.tables["series_notes"] = ([{"date": r["date"], "date_label": month_year(r["date"]), "kind": "reporting change", **{k: r[k] for k in ("series", "what")}}
                                 for r in events["reporting_changes"]]
                                + [{"date": r["date"], "date_label": month_year(r["date"]), "kind": "unexplained step", **{k: r[k] for k in ("series", "what")}}
                                   for r in events["unexplained"]])
    f.tables["series_notes"].sort(key=lambda r: r["date"])

    # ---- reconciliation, from validate.py's table
    f.tables["reconciliation"] = recon[["measure", "published_display", "ours_display", "matches", "source"]] \
        .rename(columns={"published_display": "published", "ours_display": "ours"}).to_dict("records")
    f.add("reconciliation_matched", "Published figures reproduced from APRA's raw files",
          int(recon.matches.sum()), "figures", f"checked on {recon.checked_on.iloc[0]}", "count")
    f.get("reconciliation_matched")["display"] = f"{int(recon.matches.sum())} of {len(recon)}"

    return f, release


# ------------------------------------------------------------------ rendering
def figure_table(f: Findings, ids: list[str]) -> str:
    rows = [{"Figure": f.get(i)["label"], "Value": f.get(i)["display"], "Period": f.get(i)["period"],
             "Kind": f.get(i)["kind"]} for i in ids]
    return table(rows, ["Figure", "Value", "Period", "Kind"])


HEADLINE = ["insured_latest", "insured_first", "insured_growth", "insured_change_year", "population_growth",
            "coverage_latest", "coverage_peak", "coverage_low_since_peak", "policies_latest", "policies_growth"]
DOWNGRADING = ["full_cover_first", "full_cover_latest", "full_cover_change", "excess_over_500_before_rule",
               "excess_over_500_latest", "full_cover_lowest_state", "full_cover_highest_state"]
AGEING = ["share_65_plus_insured_first", "share_65_plus_insured_latest", "share_65_plus_australia_first",
          "share_65_plus_australia_latest", "age_gap_first", "age_gap_latest", "share_65_plus_insured_change",
          "decomp_kitagawa_ageing", "decomp_kitagawa_coverage", "decomp_interaction",
          "decomp_kitagawa_ageing_proportion", "coverage_under_65_change", "coverage_65_plus_change",
          "coverage_by_band_largest_rise", "coverage_by_band_bands_that_fell", "population_series_difference"]


def blocks(f: Findings, release: dict) -> dict[str, str]:
    state = table([{"State": r["state"], "Full cover": r["display"], "Against Australia": r["gap_display"]}
                   for r in f.tables["full_cover_by_state"]], ["State", "Full cover", "Against Australia"])
    mix = {}
    for r in f.tables["age_mix"]:
        mix.setdefault((r["population"], r["june"]), {})[r["age_group"]] = r["display"]
    mix_rows = [{"Population, June": f"{p}, {j}", **groups} for (p, j), groups in mix.items()]
    mix_table = table(mix_rows, ["Population, June"] + [g for g, _, _ in AGE_GROUPS])
    bands = table([{"Age band": r["age_band"], "Coverage, first to latest June": r["display"]}
                   for r in f.tables["coverage_by_band"]], ["Age band", "Coverage, first to latest June"])
    decomp = table([{"Method": r["method"], "Australia ageing": r["ageing"],
                     "Change in coverage within age groups": r["coverage_change"], "Interaction": r["interaction"]}
                    for r in f.tables["ageing_decomposition"]],
                   ["Method", "Australia ageing", "Change in coverage within age groups", "Interaction"])
    groups = table([{"Age group": r["age_group"], "Coverage, first to latest June": r["display"]}
                    for r in f.tables["coverage_by_group"]], ["Age group", "Coverage, first to latest June"])
    events = table([{"Date": r["date_label"], "Event": f"**{r['label']}.** {r['what']}",
                     "Explains a series feature?": r["explains"] or ("No: background, before the series starts" if r["background"] else "No: context only"),
                     "Source": f"[{r['source_name']}]({r['source']})"} for r in f.tables["policy_events"]],
                   ["Date", "Event", "Explains a series feature?", "Source"])
    notes = table([{"Quarter": r["date_label"], "Series": r["series"], "What": r["what"], "Kind": r["kind"]}
                   for r in f.tables["series_notes"]], ["Quarter", "Series", "What", "Kind"])
    recon = table([{"Measure": r["measure"], "Published": r["published"], "Rebuilt": r["ours"],
                    "Source": r["source"].split(",")[0], "Match": "Yes" if r["matches"] else "No"}
                   for r in f.tables["reconciliation"]], ["Measure", "Published", "Rebuilt", "Source", "Match"])
    kinds = "Kind: " + "; ".join(f"*{k}*: {v}" for k, v in KINDS.items()) + "."
    return {
        "release": (f"APRA data from {release['first_quarter_label']} to {release['latest_quarter_label']}; "
                    f"population by age is annual, to {release['latest_june_with_population_by_age_label']}."),
        "headline": figure_table(f, HEADLINE) + "\n\n" + kinds,
        "downgrading": figure_table(f, DOWNGRADING) + "\n\n" + state,
        "ageing": (figure_table(f, AGEING) + "\n\n" + mix_table + "\n\n"
                   + "Why the pool aged, split two ways. The insured 65 and over share depends on Australia's age "
                   + "structure and on coverage within each age group; holding one at its first June value isolates "
                   + "the other, and the two orderings differ by the interaction.\n\n" + decomp + "\n\n"
                   + "Coverage by age group and by band uses APRA's annual population-by-age table as the "
                   + "denominator; the headline rate uses its quarterly population series, which differs by the "
                   + "amount in the last row of the figures above.\n\n" + groups + "\n\n" + bands),
        "events": events + "\n\n" + notes,
        "reconciliation": recon,
    }


def replace_block(text: str, name: str, body: str) -> tuple[str, bool]:
    pattern = re.compile(rf"(<!-- findings:{name} -->\n).*?(\n<!-- /findings:{name} -->)", re.DOTALL)
    if not pattern.search(text):
        return text, False
    return pattern.sub(lambda m: m.group(1) + body + m.group(2), text), True


def main() -> None:
    f, release = build()
    for row in f.figures:
        if row["kind"] == "share" and not 0 <= row["value"] <= 100:
            sys.exit(f"{row['id']} is outside 0 to 100: {row['value']}")
    out = {"kinds": KINDS, "generated_on": date.today().isoformat(), "release": release,
           "figures": f.figures, "tables": f.tables}
    JSON_OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    b = blocks(f, release)
    MD_OUT.write_text("\n".join([
        "# Findings",
        "",
        f"Written by `etl/findings.py` from the {release['latest_quarter_label']} release. {b['release']}",
        "Every figure carries its unit and its period; nothing on this page is typed by hand, and the",
        "same file feeds the README. The source of every number is `data/findings.json`.",
        "",
        "## The headline", "", b["headline"], "",
        "## Downgrading", "", b["downgrading"], "",
        "## An older pool", "", b["ageing"], "",
        "## Policy events and reporting changes on the timeline", "",
        "Events are context for a chart, not a cause. Only an entry that says so is claimed to explain a",
        "feature of a series. Source: `data/policy_events.json`.", "", b["events"], "",
        "## Checked against published figures", "", b["reconciliation"], "",
    ]), encoding="utf-8")

    readme = README.read_text(encoding="utf-8")
    done = []
    for name, body in b.items():
        readme, hit = replace_block(readme, name, body)
        if hit:
            done.append(name)
    README.write_text(readme, encoding="utf-8")

    print(f"{len(f.figures)} figures and {len(f.tables)} tables -> {JSON_OUT.relative_to(ROOT)}")
    print(f"generated -> {MD_OUT.relative_to(ROOT)}")
    print("README blocks rewritten: " + (", ".join(done) if done else "none (no markers found)"))


if __name__ == "__main__":
    main()
