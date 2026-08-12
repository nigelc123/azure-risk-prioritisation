#!/usr/bin/env bash

# Set bash to strict mode.
set -euo pipefail

# This script confirms az cli is authenticated and pointed at the expected subscription before running TF or Python against it.
# Reads AZURE_SUBSCRIPTION_ID from the environment if set (e.g. sourced from
# python/.env) to sanity check against active az cli context.

# Obtain the directory this script lives in, so it can find secrets/prowler.env regardless of the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="$SCRIPT_DIR/secrets/prowler.env"

# If service principal credentials aren't already in the environment, pick them up from secrets/prowler.env -
# this reuses the same SP creds Prowler uses so az login can authenticate non-interactively (e.g. over SSH).
if [[ -z "${AZURE_CLIENT_ID:-}" && -f "$SECRETS_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
    set +a
fi

# Retrieves the expected subscription ID if set, if it is not set, EXPECTED_SUB will be an empty string.
EXPECTED_SUB="${AZURE_SUBSCRIPTION_ID:-}"

# If az cli is not logged in, authenticate.
if ! az account show >/dev/null 2>&1; then
    # If service principal creds are available, log in non-interactively - this is what lets the script
    # run over SSH, where there's no browser available to complete an interactive `az login`.
    if [[ -n "${AZURE_CLIENT_ID:-}" && -n "${AZURE_CLIENT_SECRET:-}" && -n "${AZURE_TENANT_ID:-}" ]]; then
        echo "Not logged in. Running non-interactive az login with service principal ${AZURE_CLIENT_ID}..."
        az login --service-principal \
            -u "$AZURE_CLIENT_ID" \
            -p "$AZURE_CLIENT_SECRET" \
            --tenant "$AZURE_TENANT_ID" \
            >/dev/null
    else
        echo "Not logged in and no service principal credentials found (AZURE_CLIENT_ID/AZURE_CLIENT_SECRET/AZURE_TENANT_ID)."
        echo "Running interactive az login..."
        az login
    fi
fi

# Once logged in, store the current sub ID and name in variables.
CURRENT_SUB="$(az account show --query id -o tsv)"
CURRENT_NAME="$(az account show --query name -o tsv)"

# Print out the active subscription to confirm.
echo "Active subscription: ${CURRENT_NAME} (${CURRENT_SUB})"

# If EXPECTED_SUB is not empty, and CURRENT_SUB is not the EXPECTED_SUB, then print out a warning.
# Run az account set to set az cli to the correct subscription.
if [ -n "$EXPECTED_SUB" ] && [ "$CURRENT_SUB" != "$EXPECTED_SUB" ]; then
    echo "WARNING: active subscription does not match AZURE_SUBSCRIPTION_ID"
    echo "Running: az account set --subscription ${EXPECTED_SUB}"
    az account set --subscription "$EXPECTED_SUB"
fi

echo "OK - subscription is correct."