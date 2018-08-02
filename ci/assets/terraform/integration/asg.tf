resource "azurerm_application_security_group" "default" {
  name                         = "default"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
}

output "asg_name" {
  value = "${azurerm_application_security_group.default.name}"
}
