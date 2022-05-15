terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.93.0"
    }
  }
}

provider "azurerm" {
  features {}
}


locals {
  resource_group="app-grp"
  location="East US"
}


resource "azurerm_resource_group" "app_grp"{
  name=local.resource_group
  location=local.location
}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = local.location
  resource_group_name = azurerm_resource_group.app_grp.name
  address_space       = ["10.0.0.0/16"]
  depends_on = [
    azurerm_resource_group.app_grp
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.app_grp.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

// This subnet is for the Azure Application Gateway resource
resource "azurerm_subnet" "SubnetB" {
  name                 = "SubnetB"
  resource_group_name  = azurerm_resource_group.app_grp.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

// The public IP address is needed for the Azure Application Gateway

resource "azurerm_public_ip" "gateway_ip" {
  name                = "gateway-ip"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location
  allocation_method   = "Dynamic"

}

// Here we define the Azure Application Gateway resource
resource "azurerm_application_gateway" "app_gateway" {
  name                = "app-gateway"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }


gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.SubnetB.id
  }

  frontend_port {
    name = "front-end-port"
    port = 80
  }

 frontend_ip_configuration {
    name                 = "front-end-ip-config"
    public_ip_address_id = azurerm_public_ip.gateway_ip.id
  }


// Here we ensure the virtual machines are added to the backend pool
// of the Azure Application Gateway

  backend_address_pool{
      name  = "imagepool"
      ip_addresses = ["1.1.1.1"      ]
    }


  backend_http_settings {
    name                  = "HTTPSetting"
    cookie_based_affinity = "Disabled"
    path                  = ""
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }


 http_listener {
    name                           = "gateway-listener"
    frontend_ip_configuration_name = "front-end-ip-config"
    frontend_port_name             = "front-end-port"
    protocol                       = "Http"
  }

// This is used for implementing the URL routing rules
 request_routing_rule {
    name               = "RoutingRuleA"
    rule_type          = "PathBasedRouting"
    http_listener_name = "gateway-listener"
  }

    }
    
