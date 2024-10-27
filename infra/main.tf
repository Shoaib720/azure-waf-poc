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

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project}"
  location            = local.location
  resource_group_name = azurerm_resource_group.azure_rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = local.env
  }
}

resource "azurerm_subnet" "agw_snet" {
  name                 = "snet-${var.project}-agw"
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "workloads_snet" {
  name                 = "snet-${var.project}-workloads"
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "agw_pip" {
  name                = "pip-${var.project}"
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = local.location
  allocation_method   = "Static"

  tags = {
    environment = local.env
  }
}

resource "azurerm_application_gateway" "network" {
  name                = "agw-${var.project}"
  resource_group_name = azurerm_resource_group.azure_rg.name
  location            = local.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gwipconf-${var.project}"
    subnet_id = azurerm_subnet.agw_snet.id
  }

  frontend_port {
    name = "${var.project}-fp"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.project}-fipconf"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  backend_address_pool {
    name = "${var.project}-bepool"
    fqdns = [ azurerm_container_app.app.latest_revision_fqdn ]
  }

  backend_http_settings {
    name                  = "${var.project}-besettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name = "${var.project}-healthprobe"
  }

  http_listener {
    name                           = "${var.project}-listener"
    frontend_ip_configuration_name = "${var.project}-fipconf"
    frontend_port_name             = "${var.project}-fp"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.project}-rtrule"
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = "${var.project}-listener"
    backend_address_pool_name  = "${var.project}-bepool"
    backend_http_settings_name = "${var.project}-besettings"
  }

  waf_configuration {
    enabled                  = true
    firewall_mode            = "Detection"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    request_body_check       = true
  }

  probe {
    name = "${var.project}-healthprobe"
    interval = 30
    timeout = 10
    protocol = "Http"
    path = "/"
    host = azurerm_container_app.app.latest_revision_fqdn
    unhealthy_threshold = 3
    match {
      status_code = [ "200-299", "404" ]
    }
  }

}

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