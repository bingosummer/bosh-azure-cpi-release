resource "azurerm_resource_group" "additional" {
  name     = "${var.resource_group_prefix}${var.env_name}-additional"
  location = "${var.location}"
}

# Create a virtual network in the additional resource group
resource "azurerm_virtual_network" "additional" {
  name                = "additional"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.additional.name}"
}
resource "azurerm_subnet" "integration_manual" {
  name                 = "integration_manual"
  resource_group_name  = "${azurerm_resource_group.additional.name}"
  virtual_network_name = "${azurerm_virtual_network.additional.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.additional.address_space[0], 8, 0)}"
}

resource "azurerm_subnet" "integration_dynamic" {
  name                 = "integration_dynamic"
  resource_group_name  = "${azurerm_resource_group.additional.name}"
  virtual_network_name = "${azurerm_virtual_network.additional.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.additional.address_space[0], 8, 1)}"
}

# Create a Network Securtiy Group
resource "azurerm_network_security_group" "additional" {
  name                = "bosh"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.additional.name}"

  security_rule {
    name                       = "ssh"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "bosh-agent"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6868"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "bosh-director"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "25555"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "dns"
    priority                   = 203
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP Address for Integration Test
resource "azurerm_public_ip" "integration_in_additional_rg" {
  name                         = "integration"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.additional.name}"
  public_ip_address_allocation = "static"
}

output "additional_resource_group_name" {
  value = "${azurerm_resource_group.additional.name}"
}
output "public_ip_in_additional_rg" {
  value = "${azurerm_public_ip.integration_in_additional_rg.ip_address}"
}
