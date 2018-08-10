variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_subscription_id" {}
variable "azure_tenant_id" {}
variable "location" {
  default = "eastus2"
}
variable "env_name" {}
variable "azure_environment" {}
variable "environments" {
  type = "map"
  default = {
    AzureCloud        = "public"
    AzureUSGovernment = "usgovernment"
    AzureGermanCloud  = "german"
    AzureChinaCloud   = "china"
  }
}
variable "resource_group_prefix" {
  type    = "string"
  default = ""
}

variable "integration_virtual_network_name" {
  type    = "string"
  default = "integration-virtual-network"
}

variable "integration_virtual_network_address_space" {
  type    = "list"
  default = ["10.0.0.0/16"]
}

variable "manual_subnet_1_name" {
  type    = "string"
  default = "manual-subnet-1"
}

variable "manual_subnet_2_name" {
  type    = "string"
  default = "manual-subnet-2"
}

variable "dynamic_subnet_name" {
  type    = "string"
  default = "dynamic-subnet"
}

variable "default_nsg_name" {
  type    = "string"
  default = "default-network-security-group"
}
