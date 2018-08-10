# Public IP for Integration Test
resource "azurerm_public_ip" "integration_ip" {
  name                         = "integration-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  public_ip_address_allocation = "static"
}
