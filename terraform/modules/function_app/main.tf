# Function App Module - Main Configuration
# Provides Azure Function App for Cedar Policy evaluation

# Function App
resource "azurerm_function_app" "main" {
  name                       = var.function_app_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = var.app_service_plan_id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  
  # App settings
  app_settings = merge(var.app_settings, {
    "FUNCTIONS_WORKER_RUNTIME" = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "AzureWebJobsStorage" = azurerm_storage_account.main.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.main.primary_connection_string
    "WEBSITE_CONTENTSHARE" = azurerm_storage_account_share.main.name
    "KEY_VAULT_URL" = var.key_vault_url
    "REDIS_CONNECTION_STRING" = var.redis_connection_string
  })
  
  # Site configuration
  site_config {
    application_stack {
      node_version = "18"
    }
    
    # CORS settings
    cors {
      allowed_origins = var.cors_allowed_origins
    }
    
    # Application insights
    application_insights_connection_string = var.app_insights_connection_string
    application_insights_key               = var.app_insights_key
  }
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # HTTPS only
  https_only = true
  
  tags = var.tags
}

# Storage Account for Function App
resource "azurerm_storage_account" "main" {
  name                     = replace("${var.function_app_name}st${random_string.storage.result}", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  # Network rules
  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [var.subnet_id]
    bypass = ["AzureServices"]
  }
  
  tags = var.tags
}

# File Share for Function App content
resource "azurerm_storage_account_share" "main" {
  name                 = "function-content"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 5120
}

# Random string for storage account name
resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# Function App Slot for staging (if enabled)
resource "azurerm_function_app_slot" "staging" {
  count = var.enable_staging_slot ? 1 : 0
  
  name                       = "staging"
  function_app_name          = azurerm_function_app.main.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = var.app_service_plan_id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  
  # App settings
  app_settings = merge(var.app_settings, {
    "FUNCTIONS_WORKER_RUNTIME" = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "AzureWebJobsStorage" = azurerm_storage_account.main.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.main.primary_connection_string
    "WEBSITE_CONTENTSHARE" = azurerm_storage_account_share.main.name
    "KEY_VAULT_URL" = var.key_vault_url
    "REDIS_CONNECTION_STRING" = var.redis_connection_string
    "ENVIRONMENT" = "staging"
  })
  
  # Site configuration
  site_config {
    application_stack {
      node_version = "18"
    }
    
    # CORS settings
    cors {
      allowed_origins = var.cors_allowed_origins
    }
    
    # Application insights
    application_insights_connection_string = var.app_insights_connection_string
    application_insights_key               = var.app_insights_key
  }
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # HTTPS only
  https_only = true
  
  tags = var.tags
}

# Private Endpoint for Function App (if enabled)
resource "azurerm_private_endpoint" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.function_app_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.function_app_name}-psc"
    private_connection_resource_id = azurerm_function_app.main.id
    is_manual_connection           = false
    subresource_names             = ["sites"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Function App (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.function_app_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Function App Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = azurerm_function_app.main.name
  zone_name           = azurerm_private_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.main, azurerm_private_dns_zone_virtual_network_link.main]
}

# Diagnostic Settings for Function App
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.function_app_name}-diag"
  target_resource_id         = azurerm_function_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "FunctionAppLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "FunctionAppAuditLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
