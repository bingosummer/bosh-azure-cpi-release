# Public IP Address for Application Gateway
resource "azurerm_public_ip" "appgw_ip" {
  name                         = "appgw_ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  public_ip_address_allocation = "dynamic"
}

resource "azurerm_application_gateway" "default" {
  name                = "default"
  resource_group_name = "${azurerm_resource_group.default.name}"
  location            = "${var.location}"

  sku {
    name     = "Standard_Medium"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = "${azurerm_subnet.appgw_subnet.id}"
  }

  frontend_port {
    name = "appGWFEHttp"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = "${azurerm_public_ip.appgw_ip.id}"
  }

  backend_address_pool {
    name = "appGatewayBackendPool"
  }

  backend_http_settings {
    name                  = "appGWBEHttpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "appGatewayHttpListener"
    frontend_ip_configuration_name = "appGatewayFrontendIP"
    frontend_port_name             = "appGWFEHttp"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "HTTPrule"
    rule_type                  = "Basic"
    http_listener_name         = "appGatewayHttpListener"
    backend_address_pool_name  = "appGatewayBackendPool"
    backend_http_settings_name = "appGWBEHttpSettings"
  }
}

output "application_gateway_name" {
  value = "${azurerm_application_gateway.default.name}"
}
