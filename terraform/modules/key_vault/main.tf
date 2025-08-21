# Key Vault Module - Main Configuration
# Provides Azure Key Vault with access policies and network rules

# Key Vault
resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = var.purge_protection_enabled
  sku_name                   = "standard"
  
  # Network rules
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from specified subnets
    dynamic "ip_rules" {
      for_each = var.allowed_ip_ranges
      content {
        ip_range = ip_rules.value
      }
    }
    
    # Allow access from specified subnets
    dynamic "virtual_network_subnet_ids" {
      for_each = var.subnet_ids
      content {
        subnet_id = virtual_network_subnet_ids.value
      }
    }
  }
  
  tags = var.tags
}

# Access Policy for Current User/Service Principal
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.object_id
  
  # Full permissions for current user/service principal
  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover", "Purge"
  ]
  
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]
  
  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover", "Purge"
  ]
  
  storage_permissions = [
    "Get", "List", "Set", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]
}

# Access Policy for Container Apps (if managed identity is provided)
resource "azurerm_key_vault_access_policy" "container_apps" {
  count = var.container_apps_managed_identity_id != null ? 1 : 0
  
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.container_apps_managed_identity_id
  
  # Read permissions for secrets
  secret_permissions = [
    "Get", "List"
  ]
  
  # Read permissions for keys
  key_permissions = [
    "Get", "List"
  ]
}

# Access Policy for Function App (if managed identity is provided)
resource "azurerm_key_vault_access_policy" "function_app" {
  count = var.function_app_managed_identity_id != null ? 1 : 0
  
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.function_app_managed_identity_id
  
  # Read permissions for secrets
  secret_permissions = [
    "Get", "List"
  ]
  
  # Read permissions for keys
  key_permissions = [
    "Get", "List"
  ]
}

# Private Endpoint for Key Vault (if enabled)
resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names             = ["vault"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Key Vault (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.key_vault_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = var.key_vault_name
  zone_name           = azurerm_private_dns_zone.key_vault[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.key_vault[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.key_vault, azurerm_private_dns_zone_virtual_network_link.key_vault]
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.key_vault_name}-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "AuditEvent"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "AzurePolicyEvaluationDetails"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
