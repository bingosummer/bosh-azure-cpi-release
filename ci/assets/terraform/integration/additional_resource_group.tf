resource "azurerm_resource_group" "additional" {
  name     = "${var.resource_group_prefix}${var.env_name}-additional"
  location = "${var.location}"
}

# Create a virtual network in the additional resource group
resource "azurerm_virtual_network" "integration_virtual_network_in_additonal_rg" {
  name                = "${var.integration_virtual_network_name}"
  address_space       = "${var.integration_virtual_network_address_space}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.additional.name}"
}
resource "azurerm_subnet" "dynamic_subnet_in_additional_rg" {
  name                 = "${var.dynamic_subnet_name}"
  resource_group_name  = "${azurerm_resource_group.additional.name}"
  virtual_network_name = "${azurerm_virtual_network.integration_virtual_network_in_additonal_rg.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.integration_virtual_network_in_additonal_rg.address_space[0], 8, 0)}"
}

# Create a Network Securtiy Group
resource "azurerm_network_security_group" "default_nsg_in_additional_rg" {
  name                = "${var.default_nsg_name}"
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

# Public IP for Integration Test
resource "azurerm_public_ip" "integration_ip_in_additional_rg" {
  name                         = "integration-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.additional.name}"
  public_ip_address_allocation = "static"
}
