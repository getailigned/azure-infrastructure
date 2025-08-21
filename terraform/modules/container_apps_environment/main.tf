# Container Apps Environment Module - Main Configuration
# Provides Azure Container Apps Environment with networking and monitoring

# Log Analytics Workspace (if not provided)
resource "azurerm_log_analytics_workspace" "main" {
  count = var.log_analytics_workspace_id == null ? 1 : 0
  
  name                = "${var.environment_name}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  
  tags = var.tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  
  # Infrastructure subnet
  infrastructure_subnet_id = var.subnet_ids.apps
  
  # Log Analytics
  log_analytics_workspace_id = var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.main[0].id
  
  # Tags
  tags = var.tags
}

# Container Apps Environment Storage
resource "azurerm_container_app_environment_storage" "main" {
  count = var.enable_storage ? 1 : 0
  
  name                         = "${var.environment_name}-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main[0].name
  access_key                   = azurerm_storage_account.main[0].primary_access_key
  access_mode                  = "ReadWrite"
  share_name                   = azurerm_storage_share.main[0].name
}

# Storage Account for Container Apps (if storage is enabled)
resource "azurerm_storage_account" "main" {
  count = var.enable_storage ? 1 : 0
  
  name                     = replace("${var.environment_name}st${random_string.storage.result}", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Network rules
  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [var.subnet_ids.apps]
    bypass = ["AzureServices"]
  }
  
  tags = var.tags
}

# File Share for Container Apps (if storage is enabled)
resource "azurerm_storage_share" "main" {
  count = var.enable_storage ? 1 : 0
  
  name                 = "container-apps-share"
  storage_account_name = azurerm_storage_account.main[0].name
  quota                = 50
}

# Random string for storage account name
resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# Container Apps Environment Certificate (if provided)
resource "azurerm_container_app_environment_certificate" "main" {
  for_each = var.certificates
  
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  certificate_blob_base64      = each.value.certificate_blob_base64
  certificate_password         = each.value.certificate_password
}

# Container Apps Environment Dapr Component (if enabled)
resource "azurerm_container_app_environment_dapr_component" "main" {
  count = var.enable_dapr ? 1 : 0
  
  name                         = "dapr-component"
  container_app_environment_id = azurerm_container_app_environment.main.id
  component_type               = "bindings.redis"
  version                      = "v1"
  
  metadata {
    name  = "redisHost"
    value = var.redis_host
  }
  
  metadata {
    name  = "redisPassword"
    value = var.redis_password
  }
  
  metadata {
    name  = "redisPort"
    value = var.redis_port
  }
  
  scopes = var.dapr_scopes
}

# Container Apps Environment Workload Profile (if specified)
resource "azurerm_container_app_environment_workload_profile" "main" {
  for_each = var.workload_profiles
  
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  workload_profile_type        = each.value.type
  minimum_count                = each.value.minimum_count
  maximum_count                = each.value.maximum_count
}
