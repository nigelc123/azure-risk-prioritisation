# Create the assets table if it doesn't exist.
CREATE TABLE IF NOT EXISTS assets (
    asset_id      TEXT PRIMARY KEY, # Set the asset_id as the primary key.
    name          TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    criticality   INTEGER NOT NULL CHECK (criticality BETWEEN 1 AND 5), # Enforce that criticality must be between 1 and 5.
    exposure      TEXT NOT NULL CHECK (exposure IN ('Public', 'Private', 'Internal')), # Enforce that exposure must be 'Internal', 'Public' or 'Private'.
    environment   TEXT NOT NULL,
    owner         TEXT,
    last_seen     TEXT
);

# Create the findings table to store identified vulnerabilities from scans.
CREATE TABLE IF NOT EXISTS findings (
    finding_id        TEXT PRIMARY KEY, # Set the finding_id as the primary key.
    asset_id          TEXT NOT NULL REFERENCES assets(asset_id), # asset_id references the assets table's primary key.
    cve_id            TEXT,
    cvss_score        REAL,
    defender_severity TEXT,
    description       TEXT,
    detected_date     TEXT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'Remediated'))
);

# Create the risk scoring table, to be updated based on calculated risk scores.
CREATE TABLE IF NOT EXISTS risk_scores (
    id          INTEGER PRIMARY KEY AUTOINCREMENT, # Set the id to be the primary key and autoincrement it.
    finding_id  TEXT NOT NULL REFERENCES findings(finding_id), # Reference the findings_id column from the findings table.
    score_date  TEXT NOT NULL,
    risk_score  REAL NOT NULL,
    priority    TEXT NOT NULL CHECK (priority IN ('Critical', 'High', 'Medium', 'Low'))
);

CREATE INDEX IF NOT EXISTS idx_findings_asset ON findings(asset_id);
CREATE INDEX IF NOT EXISTS idx_risk_scores_finding ON risk_scores(finding_id);
