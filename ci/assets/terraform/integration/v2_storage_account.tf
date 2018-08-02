resource "azurerm_storage_account" "default" {
  name                     = "${replace(azurerm_resource_group.default.name, "-", "")}"
  resource_group_name      = "${azurerm_resource_group.default.name}"
  location                 = "${var.location}"
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
