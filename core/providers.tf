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
    storage_account_name = "ghdevstorageacc"
    container_name       = "tfstatecore"
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