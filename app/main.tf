# Virtual Networks
# Main
resource "azurerm_virtual_network" "vnet" {
  name                = "ghdev-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.rg
  tags = {
    deployment = "terraform"
  }
}

# AKS
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "ghdev-aks-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = var.rg
  tags = {
    deployment = "terraform"
  }
}

# Subnets
# Postgres
resource "azurerm_subnet" "pg_subnet" {
  name                 = "pg-subnet"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/26"] # Subnet within main VNet
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# AKS Subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = ["10.1.0.0/22"] # Subnet within new AKS VNet
}

# Get storage account ID for use in other modules
data "azurerm_storage_account" "storage_account" {
  name                = var.storage_account_name
  resource_group_name = var.rg
}

# Django static files
resource "azurerm_storage_container" "static" {
  name                  = "static"
  storage_account_id    = data.azurerm_storage_account.storage_account.id
  container_access_type = "blob"
  metadata = {
    deployment = "terraform"
  }
}

# Django media files
resource "azurerm_storage_container" "media" {
  name                  = "media"
  storage_account_id    = data.azurerm_storage_account.storage_account.id
  container_access_type = "blob"
  metadata = {
    deployment = "terraform"
  }
}

# Get key vault ID for use in other modules
data "azurerm_key_vault" "kv" {
  name                = "ghdev-key-vault"
  resource_group_name = var.rg
}

# PostgreSQL admin password (stored in Key Vault)
resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres_password.result
  key_vault_id = data.azurerm_key_vault.kv.id
}

# Postgres DNS zone and link
resource "azurerm_private_dns_zone" "postgres" {
  name                = "ghdevpg.postgres.database.azure.com"
  resource_group_name = var.rg
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_vnet_link" {
  name                  = "ghdev-postgres-vnet-link"
  resource_group_name   = var.rg
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags = {
    deployment = "terraform"
  }
}

# PostgreSQL
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = "ghdev-postgres"
  resource_group_name           = var.rg
  location                      = var.location
  zone                          = "1"
  administrator_login           = "icsadmin"
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
    deployment = "terraform"
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
  name                = "ghdevazregistry" # ghdevazregistry.azurecr.io
  resource_group_name = var.rg
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    deployment = "terraform"
  }
}

# Don't forget to login to the ACR and push your container image
# az acr login --name ghdevazregistry
# docker build -t ghdevazregistry.azurecr.io/myimage:1.0 .
# docker push ghdevazregistry.azurecr.io/myimage:1.0

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "ghdev-aks"
  dns_prefix          = "ghdev-aks"
  location            = var.location
  resource_group_name = var.rg

  default_node_pool { # auto creates rg - MC_<aks-resource-group><aks-cluster-name><region>
    name                 = "nodepool"
    vm_size              = "Standard_A2_v2"
    min_count            = 1
    max_count            = 2
    auto_scaling_enabled = true
    vnet_subnet_id       = azurerm_subnet.aks_subnet.id
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
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
    deployment = "terraform"
  }
}

# AKS to ACR connection
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Network links and peerings
resource "azurerm_private_dns_zone_virtual_network_link" "postgres_aks_vnet_link" {
  name                  = "ghdev-postgres-aks-vnet-link"
  resource_group_name   = var.rg
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags = {
    deployment = "terraform"
  }
}

resource "azurerm_virtual_network_peering" "ghdev_to_aks" {
  name                         = "ghdev-to-aks"
  resource_group_name          = var.rg
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.aks_vnet.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "aks_to_ghdev" {
  name                         = "aks-to-ghdev"
  resource_group_name          = azurerm_virtual_network.aks_vnet.resource_group_name
  virtual_network_name         = azurerm_virtual_network.aks_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

# NGINX Ingress Controller via Helm
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.3"

  create_namespace = true

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "controller.service.externalTrafficPolicy" # preserve client source IP
    value = "Local"
  }
  set {
    name  = "controller.progressDeadlineSeconds"
    value = "600"
  }
  set {
    name  = "controller.enableModsecurity" # WAF
    value = "true"
  }
  set {
    name  = "controller.enableOwaspModsecurityCrs"
    value = "true"
  }
  set {
    name  = "controller.configMapRef"
    value = "ics/nginx-security-rules" # <namespace>/<configmap>
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.15.0"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Get the external IP of the NGINX Ingress Controller
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress]
}

# DNS
resource "azurerm_dns_zone" "domain_ghdev" {
  name                = "ghdev.uk"
  resource_group_name = var.rg
}

resource "azurerm_dns_a_record" "root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.domain_ghdev.name
  resource_group_name = azurerm_dns_zone.domain_ghdev.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip]
}

resource "azurerm_dns_a_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.domain_ghdev.name
  resource_group_name = azurerm_dns_zone.domain_ghdev.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip]
}

# Network Security Group for PostgreSQL subnet
resource "azurerm_network_security_group" "pg_nsg" {
  name                = "pg-subnet-nsg"
  location            = var.location
  resource_group_name = var.rg
  tags = {
    deployment = "terraform"
  }
}

resource "azurerm_network_security_rule" "allow_aks_postgres" {
  name                        = "Allow-AKS-Postgres"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.1.0.0/16" # AKS vnet
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.pg_nsg.name
  resource_group_name         = var.rg
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.pg_nsg.name
  resource_group_name         = var.rg
}

resource "azurerm_subnet_network_security_group_association" "pg_subnet_assoc" {
  subnet_id                 = azurerm_subnet.pg_subnet.id
  network_security_group_id = azurerm_network_security_group.pg_nsg.id
}

# Certificate Manager sp & role to manage DNS (for wildcard domain)
resource "azuread_application" "cert_manager" {
  display_name = "cert-manager-dns"
}

resource "azuread_service_principal" "cert_manager" {
  client_id     = azuread_application.cert_manager.client_id
}

resource "azuread_service_principal_password" "cert_manager" {
  service_principal_id = azuread_service_principal.cert_manager.id
}

resource "azurerm_role_assignment" "cert_manager_dns" {
  scope                = azurerm_dns_zone.domain_ghdev.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azuread_service_principal.cert_manager.object_id
}