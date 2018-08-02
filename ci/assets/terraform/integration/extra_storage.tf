resource "azurerm_storage_account" "extra" {
  name                     = "${format("%sx", replace(azurerm_resource_group.default.name, "-", ""))}"
  resource_group_name      = "${azurerm_resource_group.default.name}"
  location                 = "${var.location}"
  account_kind             = "Storage"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "bosh_extra" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.extra.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "stemcell_extra" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.extra.name}"
  container_access_type = "private"
}

output "extra_storage_account_name" {
  value = "${azurerm_storage_account.extra.name}"
}
