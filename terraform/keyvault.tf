# This resource is the only one which will be intentionally secured, to provide a solid baseline.

resource "azurerm_key_vault" "secure-kv" {
  # Required parameters.
  name                = "${var.project-name}-kv"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name
  sku_name            = "standard" # Standard for the purposes of the lab.

  # Obtains the tenant ID based on the currently logged in service principal. Avoids hard coding the tenant ID.
  tenant_id = data.azurerm_client_config.current.tenant_id

  # Intentionally disale purge_protection on the key vault.
  purge_protection_enabled   = false

  # Don't allow access from public networks.
  public_network_access_enabled = false

  #Wasn't working without this, potentially because the IP was being blocked by the above.
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny" # Deny by default.
    #     ip_rules       = ["${data.http.current_ip.response_body}"] # Use IP address obtained.
  }

  # Enable RBAC authorisation, so only principals with the correct RBAC assignment can access the vault.
  rbac_authorization_enabled = true

  # Tags are hard coded for now.
  tags = {
    Criticality = 5
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Exposure    = "Internal"
    Project = "Cloud Risk Prioritisation"
  }
}