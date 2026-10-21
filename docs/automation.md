# Automation

The claim to be able to make at the end: **"this updates itself every quarter."** That sentence
is only worth saying if it is true, so this page is about making it true rather than approximately
true.

---

## The obstacle nobody mentions

APRA's download URLs change every release. The June 2026 membership file lives at:

```
.../system/files/2026-08/Quarterly Private Health Insurance Membership and Benefits June 2026.xlsx
```

Both the folder (`2026-08`, the publication month) and the filename (`June 2026`, the quarter)
move each time, and there is sometimes a `_0` suffix. **A hardcoded URL breaks on the very next
release** — which means a scheduled job pointed at one would quietly keep reloading the same old
file and reporting success. Worse than no automation.

So the downloader has to find the current link rather than be told it:

1. Fetch the [quarterly statistics page](https://www.apra.gov.au/quarterly-private-health-insurance-statistics)
2. Parse it for links ending `.xlsx`
3. Match the ones whose text or filename contains the dataset names
4. Compare against `data/downloads.json`, the committed record of what was last downloaded —
   if the newest link is already recorded, stop and exit cleanly, having done nothing. (A
   record, not a look in `data/raw/`: the runner starts with an empty `data/raw/` every time.)
5. Otherwise download it, record the URL and the date in the change log, and run the pipeline

Step 4 matters: the job runs on a schedule, but APRA publishes when it publishes. Most runs
should find nothing new and do nothing. **A run that finds nothing is a success, not a failure.**

This discovery step is also the bit that makes the project genuinely more interesting than a
hardcoded script, so it is worth doing properly rather than skipping.

## Where it runs

**GitHub Actions**, free for public repositories.

`etl/download.py` does steps 1 to 5. Some cloud sandboxes block apra.gov.au, but the Mac
reaches it (tested 17 Oct 2026), so the downloader was tested there before going into the
workflow. **GitHub Actions runners have open internet**, so the scheduled download works there
too.

```yaml
# .github/workflows/quarterly-refresh.yml
name: Quarterly refresh
on:
  schedule:
    - cron: '17 20 2 2,5,8,11 *'   # a few days after APRA's usual publication months
  workflow_dispatch:                # and a button, for testing
```

APRA publishes roughly quarterly but not on a fixed date, so the schedule is a poll, not an
appointment. Running monthly and exiting early when there is nothing new is also reasonable and
simpler to reason about.

## The shape of a run

```
1. discover    find the newest file links on APRA's pages            etl/download.py
2. compare     already recorded? exit 0, "no new release"
3. download    the new files into data/raw/, and log them
4. restore     the unchanged files the pipeline also needs           download.py --restore
5. clean       raw → tidy tables                                     etl/load_apra.py
6. check       quality checks — any failure stops here               etl/checks.py
7. reconcile   against published figures — a miss stops here         etl/validate.py
8. breaks      refresh the series-break evidence                     etl/breaks.py
9. load        stage, then swap into phi in one transaction          etl/to_azure.py
10. log        commit the records and change log back to the repo

The workflow is .github/workflows/quarterly-refresh.yml.
```

Steps 5 and 6 are what make this a pipeline rather than a cron job. **The failure path is the
feature**: it stops, it says why, and it leaves the database as it was.

## Secrets

The Azure connection string goes in **GitHub repository secrets**, never in the YAML and never
in a committed file:

```yaml
env:
  AZURE_SQL_URL: ${{ secrets.AZURE_SQL_URL }}
```

Its form is in `.env.example`: `mssql+pymssql://user:password@server.database.windows.net:1433/db`.

**The Azure SQL firewall must let the runner in.** GitHub's runners have no fixed address. The
simplest setting is "Allow Azure services and resources to access this server", which works
because the runners run in Azure; it also admits other Azure addresses, which is acceptable for
a database holding public data. The stricter option is a
workflow step that adds the runner's address before loading and removes it after.

Same rule as `.env` locally. A connection string in git history is a connection string you have
to rotate.

## Proven on 18 October 2026

A workflow that has never run is a YAML file, not automation. This one was run by hand
(`workflow_dispatch`) on `main` and passed, loading the June 2026 release and committing its
records. On a branch with a deliberately wrong published figure, the same workflow stopped at
"Clean, check and reconcile" and skipped the load and the commit. GitHub keeps run logs for
90 days; the bot's commits on `main` are the lasting evidence.

## The honest limit

Until a new APRA release lands and the job picks it up unattended, this is a *scheduled*
pipeline rather than one *proven* on a real release. The README says so, and the first
unattended catch will be recorded in the change log.
