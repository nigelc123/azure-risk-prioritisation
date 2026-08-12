#/bin/env/bash

# Sets bash strict mode, so the script fails with exit code 0 if an error occurs.
set -euo pipefail

# Creates a subshell to evaluate and print the directory that the script is running from - despite how the script is invoked.
# Note, the /.. goes up one level from /scripts, to the project root, so it can reference other directories in the project.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Defines the directory to use for Prowler's output, uses the SCRIPT_DIR above.
OUTPUT_DIR="${PROWLER_OUTPUT_DIR:-$SCRIPT_DIR/data/prowler-output}"

# Defines where Prowlers .env file lives, so that Prowler can properly reference the correct service principal credentials.
SECRETS_FILE="$SCRIPT_DIR/secrets/prowler.env"

# If the secrets file doesn't exist, print an error message and exit with code 1.
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "$SECRETS_FILE is missing - please fill it in with the appropriate credentials."
    exit 1
fi

# set -a is equivalent to set -o allexport, which means that variables assigned here are exported.
# This means that they are visible to processes outside of the process that spawned this script.
# Otherwise, sourcing $SECRETS_FILE would not be visible when we spawn the Prowler process later on.
set -a
# shellcheck disable=SC1090
source "$SECRETS_FILE" # Sourcing the file runs the lines in the file as commands, thus storing the variables in memory.
set +a # Remove the allexport, so variables aren't unneccessarily exposed.

# Create the directory for Prowler's output.
mkdir -p "$OUTPUT_DIR"

# Loop through the variables (assuming these are the names of the variables exported by source above)
for var in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_CLIENT_SECRET; do
    # If the variable is empty, report it as missing.
    # Exit the script with exit code 1.
    if [[ -z "${!var:-}" ]]; then
        echo "Required variable is missing in $SECRETS_FILE: $var"
        exit 1
    fi
done

# Let the user know that Prowler is going to run, and let them know where the output will go.
echo "Running Prowler against Azure tenant, output will be written to: $OUTPUT_DIR"

# Obtain the subscription ID to limit the scan to only the subscription with the in-scope resources created.
SUB_ID=$(az account show --query id | tr -d '"')

# Obtain the Resource Group name to limit the scan to only the resource group with the in-scope resources (resources in this group were explicitly created for this project).
RG_NAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && terraform output -raw resource-group-name)"

# Run Prowler on the Azure tenant with Service Principal auth (which will use the environment variables)
prowler azure --sp-env-auth --subscription-ids $SUB_ID --azure-resource-group $RG_NAME --output-formats csv --output-directory "$OUTPUT_DIR"

echo "Prowler scan complete."
