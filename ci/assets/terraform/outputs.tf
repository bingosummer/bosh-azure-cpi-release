output "environment" {
  value = "${var.cloud_name}"
}
output "storage_account_name" {
  value = "${azurerm_storage_account.default.name}"
}
output "vnet_name" {
  value = "${azurerm_virtual_network.default.name}"
}
output "default_security_group" {
  value = "${azurerm_network_security_group.default.name}"
}

# Used by bats
output "resource_group_name" {
  value = "${azurerm_resource_group.default.name}"
}
output "subnet_name" {
  value = "${azurerm_subnet.director.name}"
}
output "internal_ip" {
  value = "${cidrhost(azurerm_subnet.director.address_prefix, 6)}"
}
output "internal_cidr" {
  value = "${azurerm_subnet.director.address_prefix}"
}
output "internal_gw" {
  value = "${cidrhost(azurerm_subnet.director.address_prefix, 1)}"
}
output "reserved_range" {
  value = "${cidrhost(azurerm_subnet.director.address_prefix, 2)}-${cidrhost(azurerm_subnet.director.address_prefix, 6)}"
}
output "bats_first_network" {
  value = {
    name = "${azurerm_subnet.bats_1.name}"
    cidr = "${azurerm_subnet.bats_1.address_prefix}"
    gateway = "${cidrhost(azurerm_subnet.bats_1.address_prefix, 1)}"
    reserved_range = "${cidrhost(azurerm_subnet.bats_1.address_prefix, 2)}-${cidrhost(azurerm_subnet.bats_1.address_prefix, 3)}"
    static_range =  "${cidrhost(azurerm_subnet.bats_1.address_prefix, 4)}-${cidrhost(azurerm_subnet.bats_1.address_prefix, 10)}"
    static_ip_1 = "${cidrhost(azurerm_subnet.bats_1.address_prefix, 4)}"
    static_ip_2 = "${cidrhost(azurerm_subnet.bats_1.address_prefix, 5)}"
  }
}
output "bats_second_network" {
  value = {
    name = "${azurerm_subnet.bats_2.name}"
    cidr = "${azurerm_subnet.bats_2.address_prefix}"
    gateway = "${cidrhost(azurerm_subnet.bats_2.address_prefix, 1)}"
    reserved_range = "${cidrhost(azurerm_subnet.bats_2.address_prefix, 2)}-${cidrhost(azurerm_subnet.bats_2.address_prefix, 3)}"
    static_range =  "${cidrhost(azurerm_subnet.bats_2.address_prefix, 4)}-${cidrhost(azurerm_subnet.bats_2.address_prefix, 10)}"
    static_ip_1 = "${cidrhost(azurerm_subnet.bats_2.address_prefix, 4)}"
  }
}

# Used by integration tests
output "location" {
  value = "${var.location}"
}
output "default_resource_group_name" {
  value = "${azurerm_resource_group.default.name}"
}
output "subnet_1_name" {
  value = "${azurerm_subnet.integration_manual.name}"
}
output "subnet_2_name" {
  value = "${azurerm_subnet.integration_dynamic.name}"
}
output "application_gateway_subnet_name" {
  value = "${azurerm_subnet.integration_application_gateway.name}"
}
