# Python script to ingest assets from Azure.

# from dotenv import load_dotenv
import sqlite3
from datetime import datetime, timezone

from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.resourcegraph.models import QueryRequest

from config import AZURE_SUBSCRIPTION_ID
from db import get_connection

query = """
resources
| where isnotempty(tags.Criticality) and isnotempty(tags.Exposure)
| project id, name, type, tags, resourceGroup
"""
# if isinstance(AZURE_SUBSCRIPTION_ID,str):
#     AZURE_SUBSCRIPTION_ID = list(AZURE_SUBSCRIPTION_ID.split(",")) # Azure SDK wants the subscriptions field in QueryRequest to be a list of subscriptions. For now, assuming a single subscription ID is provided in the environment variables.
#     print(f"ingest_assets.py | AZURE_SUBSCRIPTION_ID: {AZURE_SUBSCRIPTION_ID}")
# elif isinstance(AZURE_SUBSCRIPTION_ID,list):
#     print(f"ingest_assets.py | AZURE_SUBSCRIPTION_ID: {AZURE_SUBSCRIPTION_ID}")
# else:
#     raise TypeError("AZURE_SUBSCRIPTION_ID must be a string or a list of strings.")

def fetch_assets():
    credential = DefaultAzureCredential()
    client = ResourceGraphClient(credential)
    request = QueryRequest(subscriptions=[AZURE_SUBSCRIPTION_ID],query=query) # Azure SDK wants the subscriptions field in QueryRequest to be a list of subscriptions. For now, assuming a single subscription ID is provided in the environment variables.
    print(f"ingest_assets.py | AZURE_SUBSCRIPTION_ID: {AZURE_SUBSCRIPTION_ID}")
    query_response = client.resources(request)

    return query_response.data or []

# Azure tags are always strings; normalize to the exact values the exposure CHECK constraint allows.
VALID_EXPOSURES = {"public": "Public", "private": "Private", "internal": "Internal"}

def upsert_assets(rows):
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()
    inserted = 0
    skipped = 0

    for row in rows:
        # ARM resource IDs are case-insensitive; Azure Resource Graph and Prowler
        # don't always agree on casing for the same resource, so normalize to
        # lowercase here to match the lookup in ingest_findings.py.
        raw_id = row.get("id")
        asset_id = raw_id.lower() if raw_id else None
        tags = row.get("tags", {}) or {}

        # criticality must be an integer 1-5; exposure must match the schema's CHECK
        # constraint exactly — reject rather than let a malformed tag crash the batch.
        try:
            criticality = int(str(tags.get("Criticality")).strip())
        except (TypeError, ValueError):
            criticality = None
        if criticality is None or not (1 <= criticality <= 5):
            skipped += 1
            print(f"Skipped {asset_id}: invalid Criticality tag {tags.get('Criticality')!r}")
            continue

        exposure = VALID_EXPOSURES.get(str(tags.get("Exposure") or "").strip().lower())
        if exposure is None:
            skipped += 1
            print(f"Skipped {asset_id}: invalid Exposure tag {tags.get('Exposure')!r}")
            continue

        try:
            conn.execute(
                """
                INSERT INTO assets (asset_id, name, resource_type, criticality, exposure, environment, owner, last_seen)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(asset_id) DO UPDATE SET
                    name=excluded.name,
                    resource_type=excluded.resource_type,
                    criticality=excluded.criticality,
                    exposure=excluded.exposure,
                    environment=excluded.environment,
                    owner=excluded.owner,
                    last_seen=excluded.last_seen
                """,
                (
                    asset_id,
                    row.get("name"),
                    row.get("type"),
                    criticality,
                    exposure,
                    tags.get("Environment"),
                    tags.get("Owner"),
                    now,
                ),
            )
        except sqlite3.IntegrityError as e:
            skipped += 1
            print(f"Skipped {asset_id}: {e}")
            continue
        inserted += 1

    conn.commit()
    conn.close()
    print(f"Upserted {inserted} assets ({skipped} skipped) into the asset database.")

if __name__ == "__main__":
    assets = fetch_assets()
    print(assets)
    upsert_assets(assets)