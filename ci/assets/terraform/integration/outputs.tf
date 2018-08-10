output "environment" {
  value = "${var.azure_environment}"
}
output "location" {
  value = "${var.location}"
}
output "default_resource_group_name" {
  value = "${azurerm_resource_group.default.name}"
}

output "storage_account_name" {
  value = "${azurerm_storage_account.default.name}"
}
output "extra_storage_account_name" {
  value = "${azurerm_storage_account.extra.name}"
}

output "vnet_name" {
  value = "${var.integration_virtual_network_name}"
}
output "manual_subnet_1_name" {
  value = "${var.manual_subnet_1_name}"
}
output "manual_subnet_2_name" {
  value = "${var.manual_subnet_2_name}"
}
output "dynamic_subnet_name" {
  value = "${var.dynamic_subnet_name}"
}

output "default_security_group" {
  value = "${var.default_nsg_name}"
}

output "asg_name" {
  value = "${azurerm_application_security_group.default_asg.name}"
}

output "public_ip_in_default_rg" {
  value = "${azurerm_public_ip.integration_ip.ip_address}"
}

output "additional_resource_group_name" {
  value = "${azurerm_resource_group.additional.name}"
}
output "public_ip_in_additional_rg" {
  value = "${azurerm_public_ip.integration_ip_in_additional_rg.ip_address}"
}
