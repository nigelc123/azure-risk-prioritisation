# Python script to ingest assets from Azure.

# from dotenv import load_dotenv
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
    
print(fetch_assets())

def upsert_assets(rows):
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()

    for row in rows:
        tags = row.get("tags", {}) or {}
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
                row.get("id"),
                row.get("name"),
                row.get("type"),
                tags.get("Criticality"),
                tags.get("Exposure"),
                tags.get("Environment"),
                tags.get("Owner"),
                now,
            ),
        )
        conn.commit()
        conn.close()
        print(f"Upserted {len(rows)} assets into the asset database.")

if __name__ == "__main__":
    upsert_assets(fetch_assets())