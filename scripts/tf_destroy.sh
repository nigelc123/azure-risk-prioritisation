#!/usr/bin/env bash

# Set bash to strict mode.
set -euo pipefail

# Obtain the directory that terraform code exists in and print the directory. Set it to the variable TF_DIR.
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
# Change to the directory so we can terraform init and terraform apply.
cd $TF_DIR

echo "This script is used to destroy the resources in your Azure subscription, to avoid incurring cost."
echo "Note, you will be prompted to enter the project name."
read -rp "Type 'destroy' to confirm that you want to destroy resources." CONFIRM

# If the user types anything other than 'destroy', abort.
if [ "$CONFIRM" != 'destroy ']; then
    echo "Aborted. No resources will be destroyed."
fi

# Run terraform destroy to begin the process of destroying resources.
terraform destroy -auto-approve