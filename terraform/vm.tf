resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project-name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name

  tags = {
    Criticality = "3" # Set to 3 to match the criticality rating of the Linux VM that sits within this vnet.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.project-name}-subnet"
  resource_group_name  = azurerm_resource_group.test-grp.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# INTENTIONAL MISCONFIGURATION
# NSG allows inbound SSH (22) from any source on the internet.
resource "azurerm_network_security_group" "open_nsg" {
  name                = "${var.project-name}-open-nsg"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name

  security_rule {
    name                       = "AllowSSHFromAnywhere"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    Criticality = "3" # Set to 3 to match the criticality rating of the Linux VM that this resource is attached to.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }
  
}

resource "azurerm_public_ip" "vm_public-ip" {
  name                = "${var.project-name}-vm-pip"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Criticality = "3" # Set to 3 to match the criticality rating of the Linux VM that this resource is attached to.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.project-name}-vm-nic"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public-ip.id
  }

  tags = {
    Criticality = "3" # Set to 3 to match the criticality rating of the Linux VM that this resource is attached to.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }

}

resource "azurerm_network_interface_security_group_association" "vm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.open_nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.project-name}-vm"
  resource_group_name = azurerm_resource_group.test-grp.name
  location            = azurerm_resource_group.test-grp.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Criticality = "3" # Arbitrarily set to 3, simulating a Linux VM that isn't very risky or critical.
    Exposure    = "Public"
    Environment = "Prod"
    ManagedBy   = "Terraform"
    Project = "Cloud Risk Prioritisation"
  }
}
