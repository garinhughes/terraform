terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "ghdev-rg"
    storage_account_name = "ghdevstorageacc"
    container_name       = "tfstateapp"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "542a0e08-b7f3-4936-9509-d1b7f503ef73"
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "random" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}