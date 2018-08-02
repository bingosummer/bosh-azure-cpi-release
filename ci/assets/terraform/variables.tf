variable "env_name" {}

variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}

variable "location" {
  default = "East US"
}

variable "cloud_name" {}

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
