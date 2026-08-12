provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "test-grp" {
  name     = "${var.project-name}-rg"
  location = "Australia East"

  tags = {
    Project = "Cloud Risk Prioritisation"
  }
}

data "azurerm_client_config" "current" {}