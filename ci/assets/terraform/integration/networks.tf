# Create a virtual network in the default resource group
resource "azurerm_virtual_network" "integration_virtual_network" {
  name                = "${var.integration_virtual_network_name}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  address_space       = "${var.integration_virtual_network_address_space}"
  location            = "${var.location}"
}
resource "azurerm_subnet" "manual_subnet_1" {
  name                 = "${var.manual_subnet_1_name}"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.integration_virtual_network.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.integration_virtual_network.address_space[0], 8, 0)}"
}
resource "azurerm_subnet" "manual_subnet_2" {
  name                 = "${var.manual_subnet_2_name}"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.integration_virtual_network.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.integration_virtual_network.address_space[0], 8, 1)}"
}
resource "azurerm_subnet" "dynamic_subnet" {
  name                 = "${var.dynamic_subnet_name}"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.integration_virtual_network.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.integration_virtual_network.address_space[0], 8, 2)}"
}
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "application-gateway"
  resource_group_name  = "${azurerm_resource_group.default.name}"
  virtual_network_name = "${azurerm_virtual_network.integration_virtual_network.name}"
  address_prefix       = "${cidrsubnet(azurerm_virtual_network.integration_virtual_network.address_space[0], 8, 3)}"
}
