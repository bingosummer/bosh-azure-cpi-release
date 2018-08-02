resource "azurerm_public_ip" "integration" {
  name                         = "integration"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  public_ip_address_allocation = "static"
}

output "public_ip_in_default_rg" {
  value = "${azurerm_public_ip.integration.ip_address}"
}
