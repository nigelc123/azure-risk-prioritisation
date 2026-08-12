import os
from dotenv import load_dotenv

load_dotenv()

AZURE_SUBSCRIPTION_ID = os.environ.get("AZURE_SUBSCRIPTION_ID")
DB_PATH = os.environ.get("DB_PATH", "../data/risk.db")
REPORT_DIR = os.environ.get("REPORT_DIR", "../reports")

if not AZURE_SUBSCRIPTION_ID:
    raise EnvironmentError("AZURE_SUBSCRIPTION_ID has not been set. Please store this variable in the environment file.")
else:
    print(f"config.py | AZURE_SUBSCRIPTION_ID: {AZURE_SUBSCRIPTION_ID}")

PROWLER_OUTPUT_DIR = os.environ.get("PROWLER_OUTPUT_DIR", "../data/prowler-output")

WAZUH_INDEXER_HOST = os.environ.get("WAZUH_INDEXER_HOST")  # e.g. https://localhost:9200
WAZUH_INDEXER_USER = os.environ.get("WAZUH_INDEXER_USER")
WAZUH_INDEXER_PASSWORD = os.environ.get("WAZUH_INDEXER_PASSWORD")
WAZUH_VERIFY_SSL = os.environ.get("WAZUH_VERIFY_SSL", "false").lower() == "true"

# Maps Wazuh agent name (hostname) to the Azure resource ID used as asset_id
# in the `assets` table — these are two different identity systems, so this
# bridges them. Add an entry per monitored VM.
WAZUH_AGENT_TO_ASSET_ID = {
    # "riskgrc-vm": "/subscriptions/.../resourceGroups/riskgrc-rg/providers/Microsoft.Compute/virtualMachines/riskgrc-vm",
}