import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

# Relative paths (default or from .env) are resolved against this file's directory,
# not the process's cwd — otherwise running scripts from the repo root instead of
# python/ silently writes/reads outside the project.
_CONFIG_DIR = Path(__file__).resolve().parent

def _resolve_path(env_var, default):
    path = Path(os.environ.get(env_var, default))
    return str(path if path.is_absolute() else (_CONFIG_DIR / path).resolve())

AZURE_SUBSCRIPTION_ID = os.environ.get("AZURE_SUBSCRIPTION_ID")
DB_PATH = _resolve_path("DB_PATH", "../data/risk.db")
REPORT_DIR = _resolve_path("REPORT_DIR", "../reports")

if not AZURE_SUBSCRIPTION_ID:
    raise EnvironmentError("AZURE_SUBSCRIPTION_ID has not been set. Please store this variable in the environment file.")
else:
    print(f"config.py | AZURE_SUBSCRIPTION_ID: {AZURE_SUBSCRIPTION_ID}")

PROWLER_OUTPUT_DIR = _resolve_path("PROWLER_OUTPUT_DIR", "../data/prowler-output")

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