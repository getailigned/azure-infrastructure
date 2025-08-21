# Messaging Module - Main Configuration
# Provides Azure Service Bus with topics and subscriptions

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = var.service_bus_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.service_bus_sku
  capacity            = var.service_bus_capacity
  
  # Network configuration
  zone_redundant = var.service_bus_zone_redundant
  
  # Local authentication
  local_auth_enabled = true
  
  # Minimum TLS version
  minimum_tls_version = "1.2"
  
  tags = var.tags
}

# Service Bus Topics
resource "azurerm_servicebus_topic" "main" {
  for_each = toset(var.service_bus_topics)
  
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.main.id
  
  # Topic settings
  max_size_in_megabytes = var.service_bus_topic_max_size
  enable_batched_operations = true
  enable_express = false
  enable_partitioning = false
  support_ordering = false
  
  # Message settings
  default_message_ttl = "P14D"
  duplicate_detection_history_time_window = "PT10M"
}

# Service Bus Subscriptions
resource "azurerm_servicebus_subscription" "main" {
  for_each = var.service_bus_subscriptions
  
  name                = each.key
  topic_id            = azurerm_servicebus_topic.main[each.value.topic].id
  max_delivery_count  = each.value.max_delivery_count
  lock_duration       = "PT1M"
  
  # Subscription settings
  enable_batched_operations = true
  requires_session = false
  
  # Message settings
  default_message_ttl = "P14D"
  dead_lettering_on_message_expiration = true
}

# Private Endpoint for Service Bus (if enabled)
resource "azurerm_private_endpoint" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.service_bus_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.service_bus_name}-psc"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    is_manual_connection           = false
    subresource_names             = ["namespace"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Service Bus (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.service_bus_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Service Bus Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = azurerm_servicebus_namespace.main.name
  zone_name           = azurerm_private_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.main, azurerm_private_dns_zone_virtual_network_link.main]
}

# Diagnostic Settings for Service Bus
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.service_bus_name}-diag"
  target_resource_id         = azurerm_servicebus_namespace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  log {
    category = "OperationalLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "VNetAndIPFilteringLogs"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}
