# API Management Module - Main Configuration
# Provides Azure API Management for Cedar Policy integration

# API Management Service
resource "azurerm_api_management" "main" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  
  # SKU configuration
  sku_name = var.apim_sku_name
  
  # Network configuration
  virtual_network_type = var.virtual_network_type
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # Protocols
  protocols {
    enable_http2 = true
  }
  
  # Security settings
  security {
    enable_backend_ssl30  = false
    enable_triple_des_ciphers = false
  }
  
  # Sign up settings
  sign_up {
    enabled = false
  }
  
  tags = var.tags
}

# API Management Virtual Network Integration (if enabled)
resource "azurerm_api_management_virtual_network_integration" "main" {
  count = var.enable_vnet_integration ? 1 : 0
  
  api_management_id = azurerm_api_management.main.id
  subnet_id         = var.subnet_id
}

# API Management Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.apim_name}-diag"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "GatewayLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "WebSocketLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "AuthenticationLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
