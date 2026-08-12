#!/usr/bin/env bash

# Set bash to strict mode.
set -euo pipefail

# Obtain the directory that terraform code exists in and print the directory. Set it to the variable TF_DIR.
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
# Change to the directory so we can terraform init and terraform apply.
cd $TF_DIR

echo "This will deploy the mock cloud resources, some intentionally misconfigured - into your Azure subscription."
echo "This will incur cost for as long as the resources exist."
read -rp "Type 'apply' to continue: " CONFIRM

# If the user types anything other than apply, abort.
if [ "$CONFIRM" != "apply" ]; then
    echo "Aborted. No resources will be deployed."
    exit 1
fi

# Run terraform init to initialise terraform in the directory.
terraform init

# Create the terraform plan, and store as tfplan.
terraform plan -out=tfplan

echo ""

read -rp "Review the plan above. Type 'apply' again to proceed: " CONFIRM2

# If the user types anything other than apply, abort.
if [ "$CONFIRM2" != "apply" ]; then
    echo "Aborted. No resources will be deployed."
    exit 1
fi

# If the user doesn't abort, run terraform apply, using the tfplan created.
terraform apply -auto-approve tfplan