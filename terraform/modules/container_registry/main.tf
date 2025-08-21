# Container Registry Module - Main Configuration
# Provides Azure Container Registry with networking and security

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = var.admin_enabled
  
  # Network configuration
  public_network_access_enabled = var.public_network_access_enabled
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  # Georeplications (if premium SKU)
  dynamic "georeplications" {
    for_each = var.acr_sku == "Premium" ? var.georeplication_locations : []
    content {
      location                  = georeplications.value.location
      zone_redundancy_enabled  = georeplications.value.zone_redundancy_enabled
      regional_endpoint_enabled = georeplications.value.regional_endpoint_enabled
    }
  }
  
  # Retention policy
  retention_policy {
    days    = var.retention_policy_days
    enabled = var.retention_policy_enabled
  }
  
  # Trust policy
  trust_policy {
    enabled = var.trust_policy_enabled
  }
  
  # Encryption
  encryption {
    enabled = var.encryption_enabled
  }
  
  tags = var.tags
}

# Network rules for Container Registry
resource "azurerm_container_registry_network_rule" "main" {
  count = var.enable_network_rules ? 1 : 0
  
  container_registry_name = azurerm_container_registry.main.name
  resource_group_name     = var.resource_group_name
  
  # Subnet rules
  dynamic "subnet" {
    for_each = var.subnet_ids
    content {
      subnet_id = subnet.value
    }
  }
  
  # IP rules
  dynamic "ip_rule" {
    for_each = var.allowed_ip_ranges
    content {
      action   = "Allow"
      ip_range = ip_rule.value
    }
  }
  
  # Default action
  default_action = "Deny"
}

# Private Endpoint for Container Registry (if enabled)
resource "azurerm_private_endpoint" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.acr_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.acr_name}-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names             = ["registry"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Container Registry (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.acr_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Container Registry Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = azurerm_container_registry.main.name
  zone_name           = azurerm_private_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.main, azurerm_private_dns_zone_virtual_network_link.main]
}

# Diagnostic Settings for Container Registry
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.acr_name}-diag"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "ContainerRegistryRepositoryEvents"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "ContainerRegistryArtifactEvents"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "ContainerRegistryLoginEvents"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
