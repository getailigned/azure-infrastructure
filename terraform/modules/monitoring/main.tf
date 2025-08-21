# Monitoring Module - Main Configuration
# Provides Log Analytics Workspace and Application Insights

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_days
  
  # Network configuration
  internet_ingestion_enabled = var.internet_ingestion_enabled
  internet_query_enabled     = var.internet_query_enabled
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = var.app_insights_type
  
  # Workspace configuration
  workspace_id = azurerm_log_analytics_workspace.main.id
  
  # Sampling settings
  sampling_percentage = var.sampling_percentage
  
  # Daily data cap
  daily_data_cap_in_gb = var.daily_data_cap_gb
  
  # Retention in days
  retention_in_days = var.app_insights_retention_days
  
  # Disable IP masking
  disable_ip_masking = var.disable_ip_masking
  
  # Enable request telemetry
  enable_request_telemetry = var.enable_request_telemetry
  
  tags = var.tags
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  count = var.enable_action_group ? 1 : 0
  
  name                = "${var.app_insights_name}-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "htma-alerts"
  
  # Email receiver
  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = email_receiver.key
      email_address          = email_receiver.value.email
      use_common_alert_schema = true
    }
  }
  
  # Webhook receiver
  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_receivers
    content {
      name                    = webhook_receiver.key
      service_uri            = webhook_receiver.value.uri
      use_common_alert_schema = true
    }
  }
  
  tags = var.tags
}

# Metric Alert for High CPU
resource "azurerm_monitor_metric_alert" "high_cpu" {
  count = var.enable_cpu_alert ? 1 : 0
  
  name                = "${var.app_insights_name}-high-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes               = [azurerm_application_insights.main.id]
  description          = "Alert when CPU usage is high"
  
  criteria {
    metric_namespace = "Microsoft.Insights/Components"
    metric_name      = "PerformanceCounters/processorCpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_threshold
    
    dimension {
      name     = "Cloud/roleInstance"
      operator = "Include"
      values   = ["*"]
    }
  }
  
  window_size        = "PT5M"
  frequency          = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
  
  tags = var.tags
}

# Metric Alert for High Memory
resource "azurerm_monitor_metric_alert" "high_memory" {
  count = var.enable_memory_alert ? 1 : 0
  
  name                = "${var.app_insights_name}-high-memory-alert"
  resource_group_name = var.resource_group_name
  scopes               = [azurerm_application_insights.main.id]
  description          = "Alert when memory usage is high"
  
  criteria {
    metric_namespace = "Microsoft.Insights/Components"
    metric_name      = "PerformanceCounters/availableMemory"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = var.memory_threshold
    
    dimension {
      name     = "Cloud/roleInstance"
      operator = "Include"
      values   = ["*"]
    }
  }
  
  window_size        = "PT5M"
  frequency          = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
  
  tags = var.tags
}

# Log Alert for Errors
resource "azurerm_monitor_scheduled_query_rules_alert" "error_alert" {
  count = var.enable_error_alert ? 1 : 0
  
  name                = "${var.app_insights_name}-error-alert"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  action {
    action_group = [azurerm_monitor_action_group.main[0].id]
  }
  
  data_source_id = azurerm_log_analytics_workspace.main.id
  
  query = <<-EOT
    AppTraces
    | where SeverityLevel == 3
    | summarize count() by bin(TimeGenerated, 5m)
    | where count_ > ${var.error_threshold}
  EOT
  
  schedule {
    frequency_in_minutes = 5
    time_window_in_minutes = 5
  }
  
  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
  
  tags = var.tags
}

# Diagnostic Settings for Application Insights
resource "azurerm_monitor_diagnostic_setting" "app_insights" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.app_insights_name}-diag"
  target_resource_id         = azurerm_application_insights.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  log {
    category = "Audit"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "Requests"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "Exceptions"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "Dependencies"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "CustomEvents"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "Availability"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "Performance"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
