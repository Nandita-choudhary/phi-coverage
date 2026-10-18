"""
Find APRA's newest statistics files and download only what is new.

    python etl/download.py              # check APRA's pages and download anything new
    python etl/download.py --dry-run    # say what would happen, change nothing
    python etl/download.py --restore    # fetch recorded files missing from data/raw/

APRA moves its download links every release: the folder is the month of publication, the file
name carries the quarter, and sometimes "_0" is added. So no link is hard-coded. The script
reads APRA's statistics pages, finds the newest link for each file the pipeline uses, and
compares it with data/downloads.json, the committed record of what was last downloaded.

The record is what makes the schedule work: GitHub's runner starts with an empty data/raw/
every time, because the spreadsheets are not in git. Most runs should find nothing new, and
that counts as success.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import textwrap
from datetime import date
from pathlib import Path
from urllib.parse import unquote, urljoin

import warnings

# The Mac's built-in Python uses LibreSSL, which urllib3 2 warns about but works with. GitHub's
# runners use OpenSSL and never see it. Silence only that one warning.
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL")

import requests  # noqa: E402  (imported after the filter on purpose)
from bs4 import BeautifulSoup  # noqa: E402

from load_apra import LoadError, period_of

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
RECORD = ROOT / "data" / "downloads.json"
CHANGE_LOG = ROOT / "docs" / "change-log.md"
PAGES = {
    "quarterly": "https://www.apra.gov.au/news-and-publications/"
                 "quarterly-private-health-insurance-statistics",
    "annual": "https://www.apra.gov.au/news-and-publications/"
              "annual-private-health-insurance-statistics",
}
# The files the pipeline uses: which page lists them, and how their names begin.
WANTED = {
    "membership_and_benefits": ("quarterly", "Quarterly Private Health Insurance Membership and Benefits"),
    "membership_trends": ("quarterly", "Quarterly Private Health Insurance Membership Trends"),
    "membership_coverage": ("quarterly", "Quarterly Private Health Insurance Membership Coverage"),
    "annual_membership": ("annual", "Annual private health insurance membership and benefits statistics"),
}
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; phi-coverage data pipeline)"}


class DownloadError(Exception):
    """APRA's page or file is not what the pipeline expects. Stop rather than guess."""


def spreadsheet_links(html: str, page_url: str) -> dict[str, str]:
    """Every .xlsx link on a page, as {file name: full URL}."""
    links = {}
    for a in BeautifulSoup(html, "html.parser").find_all("a", href=True):
        url = urljoin(page_url, a["href"]).split("?")[0]
        if url.lower().endswith(".xlsx"):
            links[unquote(url.rsplit("/", 1)[1])] = url
    return links


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(url: str, to: Path) -> None:
    """Download to a temporary name, check it is a real spreadsheet, then move it into place."""
    part = to.with_name(to.name + ".part")
    with requests.get(url, headers=HEADERS, timeout=180, stream=True) as response:
        response.raise_for_status()
        with part.open("wb") as f:
            for chunk in response.iter_content(1 << 20):
                f.write(chunk)
    with part.open("rb") as f:
        if f.read(4) != b"PK\x03\x04":       # every .xlsx is a zip file
            part.unlink()
            raise DownloadError(f"{url} did not return a spreadsheet.")
    part.replace(to)


def log_change(text: str) -> None:
    """Add a dated entry at the top of the change log's record."""
    lines = CHANGE_LOG.read_text().split("\n")
    at = lines.index("```") + 1
    body = textwrap.wrap(text, width=80)
    entry = [f"{date.today().isoformat()}  {body[0]}"] + [" " * 12 + line for line in body[1:]]
    CHANGE_LOG.write_text("\n".join(lines[:at] + entry + lines[at:]))


def restore(record: dict, dry_run: bool) -> None:
    """Fetch each recorded file that is missing locally, and check it is the same file."""
    try:
        for entry in record.values():
            path = RAW / entry["file"]
            if path.exists():
                continue
            print(f"{'would restore' if dry_run else 'restoring'}  {entry['file']}")
            if not dry_run:
                fetch(entry["url"], path)
                if sha256(path) != entry["sha256"]:
                    path.unlink()
                    raise DownloadError(f"{entry['file']} differs from the recorded copy: APRA "
                                        f"changed it without renaming it.")
    except (requests.RequestException, DownloadError) as problem:
        sys.exit(f"RESTORE STOPPED: {problem}")
    print("RESTORE DONE: every recorded file is in data/raw")


def main() -> None:
    parser = argparse.ArgumentParser(description="Download APRA's newest files, if any.")
    parser.add_argument("--dry-run", action="store_true", help="say what would happen, change nothing")
    parser.add_argument("--restore", action="store_true",
                        help="download every recorded file missing from data/raw, so the pipeline "
                             "has a full set (a fresh runner holds only the new files)")
    parser.add_argument("--page", action="append", default=[], metavar="KIND=FILE",
                        help="read a saved copy of a page instead of fetching it (for tests)")
    args = parser.parse_args()
    saved = dict(item.split("=", 1) for item in args.page)

    record = json.loads(RECORD.read_text()) if RECORD.exists() else {}
    if args.restore:
        restore(record, args.dry_run)
        return
    links = {}
    try:
        for kind, url in PAGES.items():
            html = (Path(saved[kind]).read_text() if kind in saved
                    else requests.get(url, headers=HEADERS, timeout=60).text)
            links[kind] = spreadsheet_links(html, url)

        new, adopted = [], []
        for dataset, (kind, prefix) in WANTED.items():
            matches = {n: u for n, u in links[kind].items() if n.startswith(prefix)}
            if not matches:
                raise DownloadError(f"No '{prefix}' file on APRA's {kind} page: the page changed.")
            name = max(matches, key=period_of)
            if record.get(dataset, {}).get("file") == name:
                print(f"up to date   {name}")
                continue
            local = RAW / name
            verb = "would record" if args.dry_run else "recorded"
            if local.exists() and dataset not in record:
                print(f"{verb}  {name}  (already in data/raw)")
                adopted.append((dataset, name, matches[name]))
            else:
                print(f"{'would download' if args.dry_run else 'downloading'}  {name}")
                new.append((dataset, name, matches[name]))
                if not args.dry_run:
                    fetch(matches[name], local)
    except (requests.RequestException, DownloadError, LoadError) as problem:
        sys.exit(f"DOWNLOAD STOPPED: {problem}")

    if not args.dry_run:
        for dataset, name, url in new + adopted:
            path = RAW / name
            record[dataset] = {"file": name, "url": url, "recorded_on": date.today().isoformat(),
                               "bytes": path.stat().st_size, "sha256": sha256(path)}
        if new or adopted:
            RECORD.write_text(json.dumps(record, indent=2) + "\n")
        if new:
            log_change("Downloaded " + "; ".join(f"{n} from {u}" for _, n, u in new) + ".")
        if adopted:
            log_change("Recorded files already in data/raw (downloaded by hand): "
                       + "; ".join(n for _, n, _ in adopted) + ".")

    if "GITHUB_OUTPUT" in os.environ:     # tells the scheduled workflow whether to run the rest
        with open(os.environ["GITHUB_OUTPUT"], "a") as out:
            out.write(f"new_release={'true' if new else 'false'}\n")
    print(f"\n{'NEW RELEASE: ' + str(len(new)) + ' file(s)' if new else 'NO NEW RELEASE'}"
          f"{' (dry run: nothing changed)' if args.dry_run else ''}")


if __name__ == "__main__":
    main()
