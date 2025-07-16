data "azurerm_client_config" "current" {}

variable "rg" {
  description = "Resource group name."
  type        = string
  default     = "ghdev-rg"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "uksouth"
}

variable "storage_account_name" {
  description = "Storage account name."
  type        = string
  default     = "ghdevstorageacc"
}

variable "container_name_core" {
  description = "Storage container name for Terraform state (core)."
  type        = string
  default     = "tfstatecore"
}

variable "container_name_app" {
  description = "Storage container name for Terraform state (app)."
  type        = string
  default     = "tfstateapp"
}
