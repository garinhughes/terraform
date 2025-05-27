# Resource Groups
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = var.rg
  tags = {
    environment = "Terraform"
  }
}

# Virtual Networks
resource "azurerm_virtual_network" "vnet" {
  name                = "ghdev-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = "Terraform"
  }
}

# Subnets
resource "azurerm_subnet" "pg_subnet" {
  name                 = "pg-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/26"]
  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Storage
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

resource "azurerm_storage_container" "container" {
  name                  = "ghdevcontainer"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
  metadata = {
    environment = "Terraform"
  }
}

# Random Password
resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "ghdev-keyvault"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  tags = {
    environment = "Terraform"
  }
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_password.result
  key_vault_id = azurerm_key_vault.kv.id
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

# Private DNS
resource "azurerm_private_dns_zone" "postgres" {
  name                = "ghdev.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet_link" {
  name                  = "ghdev-postgres-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags = {
    environment = "Terraform"
  }
}

# PostgreSQL
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
  delegated_subnet_id           = azurerm_subnet.pg_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.postgres_vnet_link]

  tags = {
    environment = "Terraform"
  }
}

resource "azurerm_postgresql_flexible_server_database" "portal_db" {
  name      = "portal"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "ghdevregistry" # ghdevregistry.azurecr.io
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    environment = "Terraform"
  }
}

# Don't forget to login to the ACR and push your container image
# az acr login --name ghdevregistry
# docker build -t ghdevregistry.azurecr.io/myimage:1.0 .
# docker push ghdevregistry.azurecr.io/myimage:1.0

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "ghdev-aks"
  dns_prefix          = "ghdev-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  default_node_pool { # auto creates rg - MC_<aks-resource-group><aks-cluster-name><region>
    name                 = "nodepool"
    vm_size              = "Standard_A2_v2"
    min_count            = 1
    max_count            = 2
    auto_scaling_enabled = true
    upgrade_settings {
      max_surge = "10%"
      drain_timeout_in_minutes = 0
      node_soak_duration_in_minutes = 0
    }
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
  tags = {
    environment = "Terraform"
  }
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "ghdev-aks-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = var.aks_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "aks-ingress"

  tags = {
    environment = "Terraform"
  }
}

# DNS
resource "azurerm_dns_zone" "domain_ghdev" {
  name                = "ghdev.uk"
  resource_group_name = azurerm_resource_group.rg.name
}

# Don't forget to add the NS records to your domain registrar
# to point to the Azure DNS nameservers

# Create a DNS A record for the AKS cluster public IP
resource "azurerm_dns_a_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.domain_ghdev.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = ["${azurerm_public_ip.public_ip.ip_address}"]
}

resource "azurerm_dns_a_record" "root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.domain_ghdev.name
  resource_group_name = azurerm_dns_zone.domain_ghdev.resource_group_name
  ttl                 = 300
  records             = ["${azurerm_public_ip.public_ip.ip_address}"]
}

# Network Peerings
data "azurerm_virtual_network" "aks_vnet" {
  name                = "aks-vnet-14252819"
  resource_group_name = "MC_ghdev-rg_ghdev-aks_uksouth"
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_aks_vnet_link" {
  name                  = "ghdev-postgres-aks-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags = {
    environment = "Terraform"
  }
}

resource "azurerm_virtual_network_peering" "ghdev_to_aks" {
  name                         = "ghdev-to-aks"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "aks_to_ghdev" {
  name                         = "aks-to-ghdev"
  resource_group_name          = data.azurerm_virtual_network.aks_vnet.resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.aks_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

# Role Assignments
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

