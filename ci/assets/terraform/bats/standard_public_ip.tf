resource "azurerm_public_ip" "director" {
  name                         = "director"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  public_ip_address_allocation = "static"
  sku                          = "Standard"
}

resource "azurerm_public_ip" "deployment" {
  name                         = "bats"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  public_ip_address_allocation = "static"
  sku                          = "Standard"
}

output "external_ip" {
  value = "${azurerm_public_ip.director.ip_address}"
}
output "bats_public_ip" {
  value = "${azurerm_public_ip.deployment.ip_address}"
}
