provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "my-resource-group"
  location = "East US"
}

resource "azurerm_storage_account" "storage" {
  name                     = "solrstorageacct"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "solr_share" {
  name                 = "solrshare"
  storage_account_name = azurerm_storage_account.storage.name
  quota               = 10
}

resource "azurerm_container_group" "react" {
  name                = "react-container-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"

  container {
    name   = "react-container"
    image  = "myacr.azurecr.io/react-app:latest"
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}

resource "azurerm_container_group" "solr" {
  name                = "solr-container-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"

  container {
    name   = "solr-container"
    image  = "myacr.azurecr.io/solr:latest"
    cpu    = "1"
    memory = "2"
    ports {
      port     = 8983
      protocol = "TCP"
    }
    volume {
      name       = "solr-storage"
      mount_path = "/var/solr"
      storage_account_name = azurerm_storage_account.storage.name
      storage_account_key  = azurerm_storage_account.storage.primary_access_key
      share_name           = azurerm_storage_share.solr_share.name
    }
  }
}

resource "azurerm_application_gateway" "app_gateway" {
  name                = "app-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }
  
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = "your-subnet-id"
  }

  frontend_ip_configuration {
    name = "frontend-ip"
    public_ip_address_id = "your-public-ip-id"
  }
  
  backend_address_pool {
    name  = "backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }
  
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  
  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }
}
