import csv
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from config import PROWLER_OUTPUT_DIR
from db import get_connection

# Column names in Prowler's CSV output.
COL_FINDING_UID = "FINDING_UID"
COL_STATUS = "STATUS"
COL_SEVERITY = "SEVERITY"
COL_RESOURCE_UID = "RESOURCE_UID"
COL_CHECK_ID = "CHECK_ID"
COL_CHECK_TITLE = "CHECK_TITLE"


# Find the latest csv file in the Prowler Output directory set in the config file.
def find_latest_csv():
    # Set output_dir as PROWLER_OUTPUT_DIR imported from config.
    output_dir = Path(PROWLER_OUTPUT_DIR)

    # Obtain a sorted list of all csv files within the output directory, sorted in reverse order by the last modified time.
    csv_files = sorted(output_dir.glob("*.csv"), key=lambda p: p.stat().st_mtime,reverse=True)

    # If no Prowler CSV files are found, raise a FileNotFoundError and inform the user to run Prowler first.
    if not csv_files:
        raise FileNotFoundError(
            f"No Prowler CSV output found in {output_dir} - run scripts/run_prowler.sh first."
        )
    return csv_files[0]

def load_prowler_findings(csv_path):
    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f,delimiter=";") # Prowler's output is semi-colon delimited.
        return [row for row in reader]

def find_parent_asset(resource_id, tracked_assets):
    """Walk up an ARM resource path to the nearest tracked ancestor asset.

    Azure records some security settings on child resources — e.g.
    .../storageAccounts/<name>/fileServices/default, or a subnet under a vnet.
    Those have their own resource IDs and never appear in the assets table,
    because Resource Graph only returns top-level resources and child resources
    generally can't be tagged. Without this, a finding on a child of a tracked
    asset is silently dropped as "unknown asset".

    Strips /<type>/<name> pairs off the end until a tracked resource is found,
    stopping at the top-level resource (namespace/type/name) so a finding is
    never attributed to a resource group or subscription.
    """
    if not resource_id or "/providers/" not in resource_id:
        return None

    base, tail = resource_id.split("/providers/", 1)
    parts = tail.split("/")  # [namespace, type, name, childType, childName, ...]

    while len(parts) > 3:
        parts = parts[:-2]
        candidate = f"{base}/providers/{'/'.join(parts)}"
        if candidate in tracked_assets:
            return candidate
    return None


def upsert_findings(rows):
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()

    # Read the asset inventory once up front so each finding can be resolved to a
    # tracked asset before we attempt the insert, rather than relying on the
    # database to reject it. Assets are always ingested before findings.
    tracked_assets = {r[0] for r in conn.execute("SELECT asset_id FROM assets")}

    inserted = 0
    attributed = 0          # matched via a parent asset rather than directly
    skipped_no_resource = 0 # row had no RESOURCE_UID
    skipped_no_id = 0       # row had neither FINDING_UID nor CHECK_ID
    skipped_untracked = 0   # resource (and its ancestors) aren't in the inventory
    skipped_error = 0       # database rejected the row

    for row in rows:
        if row.get(COL_STATUS, "").upper() != "FAIL":
            continue  # only track findings that actually failed the check

        resource_uid = row.get(COL_RESOURCE_UID)
        if not resource_uid:
            skipped_no_resource += 1
            continue

        # Normalize casing to match ingest_assets.py — ARM resource IDs are
        # case-insensitive, but Azure Resource Graph and Prowler don't always
        # agree on the casing they report for the same resource.
        resource_uid = resource_uid.lower()

        check_id = row.get(COL_CHECK_ID)
        # Without CHECK_ID, the fallback below would produce "None:<resource_uid>" and merge unrelated findings under one bogus ID — skip instead.
        finding_id = row.get(COL_FINDING_UID) or (f"{check_id}:{resource_uid}" if check_id else None)
        if not finding_id:
            skipped_no_id += 1
            continue

        # Resolve the flagged resource to a tracked asset, directly if possible,
        # otherwise via the asset that owns it.
        if resource_uid in tracked_assets:
            asset_id = resource_uid
        else:
            asset_id = find_parent_asset(resource_uid, tracked_assets)
            if asset_id is None:
                skipped_untracked += 1
                continue
            attributed += 1

        description = row.get(COL_CHECK_TITLE)
        severity = (row.get(COL_SEVERITY) or "").lower()

        # Wrap the conn.execute in a try-except so that errors are properly logged and skipped instead of skipping and failing due to sqlite3 error.
        try:
            conn.execute(
                """
                INSERT INTO findings (finding_id, asset_id, resource_uid, source, cve_id, cvss_score, severity, description, detected_date, status)
                VALUES (?, ?, ?, 'prowler', NULL, NULL, ?, ?, ?, 'Open')
                ON CONFLICT(finding_id) DO UPDATE SET
                    asset_id=excluded.asset_id,
                    resource_uid=excluded.resource_uid,
                    severity=excluded.severity,
                    description=excluded.description,
                    status=excluded.status
                """,
                (finding_id, asset_id, resource_uid, severity, description, now),
            )
        # If an error occurs, skip the execution of the row, make note of it and continue to the next row.
        except sqlite3.IntegrityError as e:
            skipped_error += 1
            print(f"Skipped {finding_id}: {e}")
            continue
        inserted += 1

    conn.commit()
    conn.close()
    print(
        f"Upserted {inserted} Prowler findings "
        f"({attributed} attributed to a parent asset) — skipped "
        f"{skipped_untracked} untracked, {skipped_no_resource} no resource id, "
        f"{skipped_no_id} no check id, {skipped_error} rejected"
    )


if __name__ == "__main__":
    latest_csv = find_latest_csv()
    print(f"Reading Prowler findings from {latest_csv}")
    upsert_findings(load_prowler_findings(latest_csv))