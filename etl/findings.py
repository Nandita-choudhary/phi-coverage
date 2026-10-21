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
          "share_65_plus_australia_latest", "age_gap_first", "age_gap_latest", "coverage_by_band_largest_rise",
          "coverage_by_band_bands_that_fell"]


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
    recon = table([{"Measure": r["measure"], "Published": r["published"], "Rebuilt": r["ours"],
                    "Source": r["source"].split(",")[0], "Match": "Yes" if r["matches"] else "No"}
                   for r in f.tables["reconciliation"]], ["Measure", "Published", "Rebuilt", "Source", "Match"])
    kinds = "Kind: " + "; ".join(f"*{k}*: {v}" for k, v in KINDS.items()) + "."
    return {
        "release": (f"APRA data from {release['first_quarter_label']} to {release['latest_quarter_label']}; "
                    f"population by age is annual, to {release['latest_june_with_population_by_age_label']}."),
        "headline": figure_table(f, HEADLINE) + "\n\n" + kinds,
        "downgrading": figure_table(f, DOWNGRADING) + "\n\n" + state,
        "ageing": figure_table(f, AGEING) + "\n\n" + mix_table + "\n\n" + bands,
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
