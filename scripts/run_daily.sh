#!/usr/bin/env bash
set -euo pipefail # Set bash to strict mode.

# This script is used to ingest assets, ingest findings, create a score and report on a daily basis.
# The intent is for the run to be triggered by cron.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd $SCRIPT_DIR

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/run_${TIMESTAMP}.log"

echo "=== Daily run started: $TIMESTAMP ===" | tee -a "$LOG_FILE"

# Function to run the python sections of the codebase.
run_step() {
    # Create local variables to represent the parameters for the function running.
    local step_name="$1"
    local script_path="$2"

    echo "--- ${step_name} ---" | tee -a "$LOG_FILE"

    # If the python script runs successfully, print OK and log this.
    if python "$script_path" >> "$LOG_FILE" 2>&1; then
        echo "${step_name}: OK" | tee -a "$LOG_FILE"
    else
    # Or else, print that it failed and log this.
        echo "${step_name}: FAILED - see $LOG_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to run the bash sections of the code base.
run_bash_step() {
    # Create local variables to represent parameters for the function running.
    local step_name="$1"
    local script_path="$2"

     # If the bash script runs successfully, print OK and log this.
    echo "--- ${step_name} ---" | tee -a "$LOG_FILE"
    if bash "$script_path" >> "$LOG_FILE" 2>&1; then
        echo "${step_name}: OK" | tee -a "$LOG_FILE"
    else  
    # Or else, print that it failed and log this.
        echo "${step_name}: FAILED - see $LOG_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
}

run_bash_step "Run Prowler scan" "scripts/run_prowler.sh"
run_step "Ingest assets" "python/ingest_assets.py"
# run_step "Ingest Prowler findings" "python/ingest_findings.py"
# run_step "Ingest Wazuh findings" "python/ingest_wazuh_findings.py"
# run_step "Score findings" "python/risk_scorer.py"
# run_step "Generate report" "python/report.py"