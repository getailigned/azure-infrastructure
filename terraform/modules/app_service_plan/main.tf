# App Service Plan Module - Main Configuration
# Provides Azure App Service Plan for Function Apps

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = var.os_type
  sku_name            = var.sku_name
  
  # Per site scaling
  per_site_scaling = var.per_site_scaling
  
  # Zone redundancy
  zone_balancing_enabled = var.zone_balancing_enabled
  
  # Maximum elastic worker count
  maximum_elastic_worker_count = var.maximum_elastic_worker_count
  
  # Reserved (if Linux)
  reserved = var.os_type == "Linux" ? true : false
  
  tags = var.tags
}

# Diagnostic Settings for App Service Plan
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.plan_name}-diag"
  target_resource_id         = azurerm_service_plan.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "AppServicePlanLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
