provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" { default = "my-resource-group" }
variable "location" { default = "East US" }
variable "container_registry_name" { default = "myacr" }
variable "app_gateway_name" { default = "my-app-gateway" }
variable "vnet_name" { default = "my-vnet" }
variable "subnet_appgw_name" { default = "appgw-subnet" }
variable "subnet_mysql_name" { default = "mysql-subnet" }
variable "mysql_server_name" { default = "my-mysql-server" }
variable "mysql_database_name" { default = "appdb" }
variable "mysql_admin_user" { default = "adminuser" }
variable "mysql_admin_password" { default = "SecureP@ssw0rd!" }

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Application Gateway Subnet
resource "azurerm_subnet" "subnet_appgw" {
  name                 = var.subnet_appgw_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# MySQL Private Subnet
resource "azurerm_subnet" "subnet_mysql" {
  name                 = var.subnet_mysql_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Azure MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = var.mysql_server_name
  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  administrator_login    = var.mysql_admin_user
  administrator_password = var.mysql_admin_password
  sku_name               = "Standard_B1ms"
  version                = "8.0"

  storage {
    size_gb = 20
  }

  network {
    delegated_subnet_id = azurerm_subnet.subnet_mysql.id
    private_dns_zone_id = null
  }
}

# MySQL Database
resource "azurerm_mysql_flexible_server_database" "database" {
  name                = var.mysql_database_name
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  collation           = "utf8_general_ci"
  charset             = "utf8"
}

# MySQL Firewall Rule: Allow App ACI
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_app_aci" {
  name                = "allow-app-aci"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = "10.0.1.0"
  end_ip_address      = "10.0.1.255"
}
