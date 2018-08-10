# Create a default resource group
resource "azurerm_resource_group" "default" {
  name     = "${var.resource_group_prefix}${var.env_name}-default"
  location = "${var.location}"
}
