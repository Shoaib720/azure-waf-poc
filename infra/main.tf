# Resources to deploy
# 1. Resource Group
# 2. Vnet and 2 subnets
# 3. security groups
# 4. Container apps environment
# 5. Container app
# 6. Azure app gw with waf

locals {
  location = "Central India"
  env      = "Test"
}

resource "azurerm_resource_group" "azure_rg" {
  name     = "rg-${var.project}"
  location = local.location
  tags = {
    environment = local.env
  }
}

# resource "azurerm_virtual_network" "vnet" {
#   name                = "vnet-${var.project}"
#   location            = local.location
#   resource_group_name = azurerm_resource_group.azure_rg.name
#   address_space       = ["10.0.0.0/16"]
#   dns_servers         = ["10.0.0.4", "10.0.0.5"]

#   subnet {
#     name             = "snet-${var.project}"
#     address_prefixes = ["10.0.1.0/24"]
#     # security_group   = azurerm_network_security_group.example.id
#   }

#   tags = {
#     environment = local.env
#   }
# }

resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "law-${var.project}"
  location            = local.location
  resource_group_name = azurerm_resource_group.azure_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "app_env" {
  name                       = "appenv-${var.project}"
  location                   = local.location
  resource_group_name        = azurerm_resource_group.azure_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace.id
}

resource "azurerm_container_app" "app" {
  name                         = "app-${var.project}"
  container_app_environment_id = azurerm_container_app_environment.app_env.id
  resource_group_name          = azurerm_resource_group.azure_rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "owaspjuiceshop"
      image  = "docker.io/bkimminich/juice-shop:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
    min_replicas = 0
    max_replicas = 2
  }
  ingress {
    external_enabled           = true
    target_port                = 3000
    allow_insecure_connections = true
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}