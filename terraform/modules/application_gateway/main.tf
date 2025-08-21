# Application Gateway Module - Main Configuration
# Provides Azure Application Gateway with SSL termination and routing

# Public IP for Application Gateway
resource "azurerm_public_ip" "main" {
  name                = "${var.gateway_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  # DNS settings
  domain_name_label = "${var.gateway_name}-${var.environment}-${random_string.suffix.result}"
  
  tags = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = var.gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # SKU configuration
  sku {
    name     = var.gateway_sku_name
    tier     = var.gateway_sku_tier
    capacity = var.gateway_capacity
  }
  
  # Gateway IP configuration
  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.subnet_id
  }
  
  # Frontend port configuration
  frontend_port {
    name = "http-port"
    port = 80
  }
  
  frontend_port {
    name = "https-port"
    port = 443
  }
  
  # Frontend IP configuration
  frontend_ip_configuration {
    name                 = "frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.main.id
  }
  
  # Backend address pool
  backend_address_pool {
    name = "container-apps-pool"
    fqdn = var.container_apps_fqdn
  }
  
  # Backend HTTP settings
  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  # HTTP listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-configuration"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  
  # HTTP listener for HTTPS
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip-configuration"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "ssl-certificate"
  }
  
  # SSL Certificate
  ssl_certificate {
    name     = "ssl-certificate"
    data     = var.ssl_certificate_data
    password = var.ssl_certificate_password
  }
  
  # Request routing rule for HTTP to HTTPS redirect
  request_routing_rule {
    name                       = "http-to-https-redirect"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    redirect_configuration_name = "http-to-https-redirect"
    priority                   = 100
  }
  
  # Request routing rule for HTTPS
  request_routing_rule {
    name                       = "https-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "container-apps-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 200
  }
  
  # Redirect configuration for HTTP to HTTPS
  redirect_configuration {
    name                 = "http-to-https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }
  
  # WAF configuration (if enabled)
  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []
    content {
      enabled          = true
      firewall_mode    = var.waf_firewall_mode
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
      
      # WAF rules
      dynamic "disabled_rule_group" {
        for_each = var.waf_disabled_rules
        content {
          rule_group_name = disabled_rule_group.value.rule_group_name
          rules            = disabled_rule_group.value.rules
        }
      }
      
      # File upload limits
      file_upload_limit_mb = var.waf_file_upload_limit_mb
      max_request_body_size_kb = var.waf_max_request_body_size_kb
    }
  }
  
  # Identity for managed certificates
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Network Security Group for Application Gateway
resource "azurerm_network_security_group" "main" {
  name                = "${var.gateway_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # Allow HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow Application Gateway health probe
  security_rule {
    name                       = "AllowHealthProbe"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  
  # Allow Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  
  tags = var.tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Random string for DNS label
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.gateway_name}-diag"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "ApplicationGatewayAccessLog"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "ApplicationGatewayPerformanceLog"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "ApplicationGatewayFirewallLog"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
