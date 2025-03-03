provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" { default = "my-resource-group" }
variable "location" { default = "East US" }
variable "container_registry_name" { default = "myacr" }
variable "app_gateway_name" { default = "my-app-gateway" }
variable "vnet_name" { default = "my-vnet" }
variable "subnet_name" { default = "appgw-subnet" }
variable "solr_container_name" { default = "solr-container" }

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Virtual Network & Subnet for Application Gateway
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Application Gateway
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "appgw-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
}

resource "azurerm_application_gateway" "appgw" {
  name                = var.app_gateway_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "http-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "http-settings"
  }
}

# Azure Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                = "my-container-app-env"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# Primary ACI (Application)
resource "azurerm_container_app" "app" {
  name                         = "my-app-container"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  revision_mode                = "Single"

  template {
    container {
      name   = "my-container"
      image  = "${azurerm_container_registry.acr.login_server}/my-app:latest"
      cpu    = 0.5
      memory = "1Gi"
    }

    min_replicas = 2
    max_replicas = 10

    scale_rule {
      name = "cpu-scale"
      custom {
        metadata = {
          type        = "cpu"
          threshold   = "50"
        }
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic {
      percentage = 100
      latest_revision = true
    }
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}

# Secondary ACI (Solr Search)
resource "azurerm_container_group" "solr" {
  name                = var.solr_container_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"

  container {
    name   = "solr"
    image  = "solr:latest"
    cpu    = 0.5
    memory = "1Gi"
    ports {
      port     = 8983
      protocol = "TCP"
    }
  }

  ip_address_type = "Private"
  subnet_ids      = [azurerm_subnet.subnet.id]
}
