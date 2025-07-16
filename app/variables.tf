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
  description = "Storage account name for Terraform state."
  type        = string
  default     = "ghdevstorageacc"
}