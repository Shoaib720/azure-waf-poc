terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
  backend "azurerm" {
    resource_group_name  = "basic-rg"
    storage_account_name = "stgaccterraformfiles"
    container_name       = "tfstates"
    key                  = "test.terraform.tfstate"
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  use_oidc = true
  resource_provider_registrations = "none"
}

provider "random" {
  # Configuration options
}