resource "azurerm_virtual_network" "default" {
  name                = "default"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
}

resource "azurerm_subnet" "director" {
  name                 = "director"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 0)}"
}

resource "azurerm_subnet" "bats_1" {
  name                 = "bats_1"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 1)}"
}

resource "azurerm_subnet" "bats_2" {
  name                 = "bats_2"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 2)}"
}

resource "azurerm_subnet" "integration_manual" {
  name                 = "integration_manual"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 3)}"
}

resource "azurerm_subnet" "integration_dynamic" {
  name                 = "integration_dynamic"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 4)}"
}

resource "azurerm_subnet" "integration_application_gateway" {
  name                 = "integration_application_gateway"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.default.address_space[0], 8, 5)}"
}
