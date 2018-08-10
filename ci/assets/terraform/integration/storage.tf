# Create a default Storage Account in the default resouce group
resource "azurerm_storage_account" "default" {
  name                     = "${replace(var.env_name, "-", "")}"
  resource_group_name      = "${azurerm_resource_group.default.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# Create a Storage Container for the disks
resource "azurerm_storage_container" "bosh" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
  container_access_type = "private"
}
# Create a Storage Container for the stemcells
resource "azurerm_storage_container" "stemcell" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
  container_access_type = "blob"
}
# Create a Storage Table for the metadata of the stemcells
resource "azurerm_storage_table" "stemcells" {
  name                  = "stemcells"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.default.name}"
}

# Create an extra Storage Account in the default resouce group
resource "azurerm_storage_account" "extra" {
  name                     = "${format("%sx", replace(var.env_name, "-", ""))}"
  resource_group_name      = "${azurerm_resource_group.default.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# Create a Storage Container for the disks
resource "azurerm_storage_container" "bosh_extra" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.extra.name}"
  container_access_type = "private"
}
# Create a Storage Container for the stemcells
resource "azurerm_storage_container" "stemcell_extra" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.default.name}"
  storage_account_name  = "${azurerm_storage_account.extra.name}"
  container_access_type = "private"
}
