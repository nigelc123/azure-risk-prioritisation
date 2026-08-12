# INTENTIONAL MISCONFIGURATION
# Public network access + anonymous blob access allowed, network rules set to
# "Allow" by default. This exists to generate a real Public-exposure,
# high-criticality finding for the pipeline to detect and score.

resource "azurerm_storage_account" "public_storage" {
  name                     = "${var.project-name}pubsa"
  resource_group_name      = azurerm_resource_group.test-grp.name
  location                 = azurerm_resource_group.test-grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled   = true # Intentional misconfiguration to allow public network access.
  allow_nested_items_to_be_public = true # Intentional misconfiguration to allow public network access.

  network_rules {
    default_action = "Allow"
  }

  tags = {
    Criticality = "2" # Arbitrarily set to 2, simulating a storage account that isn't highly risky or important.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }
}