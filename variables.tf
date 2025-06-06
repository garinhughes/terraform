# Variables
variable "rg" {
  type        = string
  default     = "ghdev-rg"
  description = "Resource group name"
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Location for the resource group"
}

variable "storage" {
  type        = string
  default     = "ghdevstorageaccount"
  description = "Storage account name"
}

# Get current Azure client configuration for Key Vault access policies
data "azurerm_client_config" "current" {}