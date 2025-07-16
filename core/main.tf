# Core infrastructure for Terraform remote state

resource "azurerm_resource_group" "rg" {
  name     = var.rg
  location = var.location
  tags = {
    deployment = "terraform"
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    deployment = "terraform"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name_core
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
  metadata = {
    deployment = "terraform"
  }
}

resource "azurerm_storage_container" "tfstateapp" {
  name                  = var.container_name_app
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
  metadata = {
    deployment = "terraform"
  }
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "ghdev-key-vault"
  location                    = var.location
  resource_group_name         = var.rg
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  tags = {
    deployment = "terraform"
  }
}

# Azure AD and Key Vault Access Policy
resource "azuread_application" "kv_reader" {
  display_name = "kv-reader-sp"
}

resource "azuread_service_principal" "kv_reader" {
  client_id = azuread_application.kv_reader.client_id
}

resource "azuread_service_principal_password" "kv_reader" {
  service_principal_id = azuread_service_principal.kv_reader.id
}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List"
  ]
  secret_permissions = [
    "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set"
  ]
  storage_permissions = [
    "Get", "List"
  ]
}

resource "azurerm_key_vault_access_policy" "kv_reader" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.kv_reader.object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}