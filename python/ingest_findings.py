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

def upsert_findings(rows):
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()
    inserted = 0
    skipped = 0

    for row in rows:
        if row.get(COL_STATUS, "").upper() != "FAIL":
            continue  # only track findings that actually failed the check

        asset_id = row.get(COL_RESOURCE_UID)
        if not asset_id:
            skipped += 1
            continue
        
        # Normalize casing to match ingest_assets.py — ARM resource IDs are
        # case-insensitive, but Azure Resource Graph and Prowler don't always
        # agree on the casing they report for the same resource.
        asset_id = asset_id.lower()

        check_id = row.get(COL_CHECK_ID)
        # Without CHECK_ID, the fallback below would produce "None:<asset_id>" and merge unrelated findings under one bogus ID — skip instead.
        finding_id = row.get(COL_FINDING_UID) or (f"{check_id}:{asset_id}" if check_id else None)
        if not finding_id:
            skipped += 1
            continue

        description = row.get(COL_CHECK_TITLE)
        severity = (row.get(COL_SEVERITY) or "").lower()

        # Wrap the conn.execute in a try-except so that errors are properly logged and skipped instead of skipping and failing due to sqlite3 error.
        try:
            conn.execute(
                """
                INSERT INTO findings (finding_id, asset_id, source, cve_id, cvss_score, severity, description, detected_date, status)
                VALUES (?, ?, 'prowler', NULL, NULL, ?, ?, ?, 'Open')
                ON CONFLICT(finding_id) DO UPDATE SET
                    severity=excluded.severity,
                    description=excluded.description,
                    status=excluded.status
                """,
                (finding_id, asset_id, severity, description, now),
            )
        # If an error occurs, skip the execution of the row, make note of it and continue to the next row.
        except sqlite3.IntegrityError as e:
            skipped += 1
            print(f"Skipped {finding_id}: {e}")
            continue
        inserted += 1

    conn.commit()
    conn.close()
    print(f"Upserted {inserted} Prowler findings ({skipped} skipped — no matching asset_id)")


if __name__ == "__main__":
    latest_csv = find_latest_csv()
    print(f"Reading Prowler findings from {latest_csv}")
    upsert_findings(load_prowler_findings(latest_csv))