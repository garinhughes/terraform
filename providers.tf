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
  }

  backend "azurerm" {
    resource_group_name  = "ghdev-rg"
    storage_account_name = "ghdevstorageaccount"
    container_name       = "ghdevcontainer"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "ca72a60d-fa94-4fb1-b5fc-ae5f7416a474"
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "random" {}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}