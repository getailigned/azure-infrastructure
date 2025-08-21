# Cache Module - Main Configuration
# Provides Redis Cache with networking and security

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = var.redis_name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku_name            = var.redis_sku_name
  
  # Network configuration
  subnet_id = var.subnet_id
  
  # Redis configuration
  redis_configuration {
    maxmemory_reserved = var.redis_maxmemory_reserved
    maxmemory_delta    = var.redis_maxmemory_delta
    maxmemory_policy   = var.redis_maxmemory_policy
    enable_non_ssl_port = var.redis_enable_non_ssl_port
  }
  
  # Patch schedule
  patch_schedule {
    day_of_week    = var.redis_patch_day
    start_hour_utc = var.redis_patch_start_hour
  }
  
  tags = var.tags
}

# Private Endpoint for Redis (if enabled)
resource "azurerm_private_endpoint" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.redis_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.redis_name}-psc"
    private_connection_resource_id = azurerm_redis_cache.main.id
    is_manual_connection           = false
    subresource_names             = ["redisCache"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Redis (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.redis_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Redis Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = azurerm_redis_cache.main.name
  zone_name           = azurerm_private_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.main, azurerm_private_dns_zone_virtual_network_link.main]
}

# Diagnostic Settings for Redis Cache
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.redis_name}-diag"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "ConnectedClientList"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
