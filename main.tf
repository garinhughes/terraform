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

# Create a resource group in UK south
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.rg
  tags = {
    environment = "Terraform"
  }
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
  metadata = {
    environment = "Terraform"
  }
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "ghdev-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = "Terraform"
  }
}

# Create a subnet
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Create a random password for PostgreSQL admin
resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create a Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "ghdev-keyvault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List",
    ]

    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
    ]

    storage_permissions = [
      "Get", "List",
    ]
  }

  tags = {
    environment = "Terraform"
  }
}

# Store the PostgreSQL password as a Key Vault secret
resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_password.result
  key_vault_id = azurerm_key_vault.kv.id
}

# Create a private DNS zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "ghdev.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the private DNS zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet_link" {
  name                  = "ghdev-postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# Create a burstable PostgreSQL database
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = "ghdev-postgres"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  zone                          = "1"
  administrator_login           = "wabi"
  administrator_password        = random_password.postgres_password.result
  sku_name                      = "B_Standard_B1ms" # burstable 1 vcpu, 2 GiB
  storage_tier                  = "P4"              # 120 iops
  public_network_access_enabled = false
  version                       = "16"
  storage_mb                    = 32768
  backup_retention_days         = 7
  delegated_subnet_id           = azurerm_subnet.subnet1.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.postgres_vnet_link]
}

# # Create a Kubernetes cluster
# resource "azurerm_kubernetes_cluster" "aks" {
#   name                = "ghdev-aks"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   dns_prefix          = "ghdev-aks"

#   default_node_pool {
#     name       = "default"
#     node_count = 1
#     vm_size    = "Standard_B2s"
#   }

#   identity {
#     type = "SystemAssigned"
#   }
# }
