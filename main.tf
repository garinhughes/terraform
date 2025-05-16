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

# Create a resource group in UK south
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.rg
}

# Create a storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage
  resource_group_name      = var.rg
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform"
  }
}

# Create a storage container
resource "azurerm_storage_container" "container" {
  name                  = "ghdevcontainer"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}