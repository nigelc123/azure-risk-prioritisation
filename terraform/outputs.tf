output "resource-group-name" {
    type = string
    description = "Name of the resource group."
    value = azurerm_resource_group.test-grp.name
}

output "key-vault-name" {
    type = string
    description = "Name of the Key Vault."
    value = azurerm_key_vault.secure-kv.name
}

output "key-vault-network-access" {
    type = string
    description = "Public network access setting."
    value = azurerm_key_vault.secure-kv.public_network_access_enabled
}

output "storage-account-name" {
    type = string
    description = "Storage account name"
    value = azurerm_storage_account.public_storage.name
}

output "storage-account-network-access" {
    type = string
    description = "Storage account access setting."
    value = azurerm_storage_account.public_storage.public_network_access_enabled
}

output "vm-name" {
    type = string
    description = "Virtual machine name."
    value = azurerm_linux_virtual_machine.vm.name
}

output "vm-admin-username" {
    type = string
    description = "Virtual machine admin username."
    value = azurerm_linux_virtual_machine.vm.admin_username
}

output "vm-ip-addr" {
    type = string
    description = "Virtual machine public IP address."
    value = azurerm_linux_virtual_machine.vm.public_ip_address
}