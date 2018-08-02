resource "azurerm_storage_account" "default" {
  name                     = "${replace(azurerm_resource_group.default.name, "-", "")}"
  resource_group_name      = "${azurerm_resource_group.default.name}"
  location                 = "${var.location}"
  account_kind             = "Storage"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_storage_container" "bosh" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
  container_access_type = "private"
}
resource "azurerm_storage_container" "stemcell" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
  container_access_type = "blob"
}
resource "azurerm_storage_table" "stemcells" {
  name                  = "stemcells"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
}
