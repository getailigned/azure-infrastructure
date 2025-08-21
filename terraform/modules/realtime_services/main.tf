# Real-time Services Module - Main Configuration
# Provides SignalR, Redis, Service Bus, Event Grid, and Notification Hubs

# Azure SignalR Service
resource "azurerm_signalr_service" "main" {
  name                = "${var.resource_name_prefix}-signalr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku {
    name     = var.signalr_sku_name
    capacity = var.signalr_capacity
  }
  
  # Features
  features {
    flag  = "ServiceMode"
    value = "Default"
  }
  
  features {
    flag  = "EnableConnectivityLogs"
    value = "true"
  }
  
  features {
    flag  = "EnableMessagingLogs"
    value = "true"
  }
  
  # Network configuration
  public_network_access_enabled = var.signalr_public_network_access
  
  tags = var.tags
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = "${var.resource_name_prefix}-redis"
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

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.resource_name_prefix}-servicebus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.servicebus_sku
  capacity            = var.servicebus_capacity
  
  # Network configuration
  zone_redundant = var.servicebus_zone_redundant
  
  # Local authentication
  local_auth_enabled = true
  
  # Minimum TLS version
  minimum_tls_version = "1.2"
  
  tags = var.tags
}

# Service Bus Topics
resource "azurerm_servicebus_topic" "main" {
  for_each = toset(var.servicebus_topics)
  
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.main.id
  
  # Topic settings
  max_size_in_megabytes = var.servicebus_topic_max_size
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
  for_each = var.servicebus_subscriptions
  
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

# Event Grid Topic
resource "azurerm_eventgrid_topic" "main" {
  name                = "${var.resource_name_prefix}-eventgrid"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # Input schema
  input_schema = "CloudEventSchemaV1_0"
  
  # Local authentication
  local_auth_enabled = true
  
  # Public network access
  public_network_access_enabled = var.eventgrid_public_network_access
  
  tags = var.tags
}

# Event Grid System Topic for Storage Account
resource "azurerm_eventgrid_system_topic" "storage" {
  count = var.enable_storage_events ? 1 : 0
  
  name                   = "${var.resource_name_prefix}-storage-events"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = var.storage_account_id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  
  tags = var.tags
}

# Event Grid System Topic for Service Bus
resource "azurerm_eventgrid_system_topic" "servicebus" {
  count = var.enable_servicebus_events ? 1 : 0
  
  name                   = "${var.resource_name_prefix}-servicebus-events"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = azurerm_servicebus_namespace.main.id
  topic_type             = "Microsoft.ServiceBus.Namespaces"
  
  tags = var.tags
}

# Notification Hub Namespace
resource "azurerm_notification_hub_namespace" "main" {
  count = var.enable_notification_hubs ? 1 : 0
  
  name                = "${var.resource_name_prefix}-notificationhub"
  resource_group_name = var.resource_group_name
  location            = var.location
  namespace_type      = "NotificationHub"
  sku_name            = var.notification_hub_sku
  
  # Network configuration
  public_network_access_enabled = var.notification_hub_public_network_access
  
  tags = var.tags
}

# Notification Hub
resource "azurerm_notification_hub" "main" {
  count = var.enable_notification_hubs ? 1 : 0
  
  name                = "${var.resource_name_prefix}-hub"
  namespace_name      = azurerm_notification_hub_namespace.main[0].name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # Notification settings
  gcm_credential {
    api_key = var.gcm_api_key
  }
  
  apns_credential {
    application_mode = "Production"
    bundle_id        = var.apns_bundle_id
    key_id           = var.apns_key_id
    team_id          = var.apns_team_id
    token            = var.apns_token
  }
  
  tags = var.tags
}

# Private Endpoint for SignalR (if enabled)
resource "azurerm_private_endpoint" "signalr" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-signalr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-signalr-psc"
    private_connection_resource_id = azurerm_signalr_service.main.id
    is_manual_connection           = false
    subresource_names             = ["signalr"]
  }
  
  tags = var.tags
}

# Private Endpoint for Service Bus (if enabled)
resource "azurerm_private_endpoint" "servicebus" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-servicebus-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-servicebus-psc"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    is_manual_connection           = false
    subresource_names             = ["namespace"]
  }
  
  tags = var.tags
}

# Private DNS Zone for SignalR (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "signalr" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.signalr.azure.com"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Private DNS Zone for Service Bus (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "servicebus" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zones to VNet (if private endpoints are enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "signalr" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-signalr-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.signalr[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-servicebus-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Records for Private Endpoints (if private endpoints are enabled)
resource "azurerm_private_dns_a_record" "signalr" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_signalr_service.main.name
  zone_name           = azurerm_private_dns_zone.signalr[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.signalr[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.signalr, azurerm_private_dns_zone_virtual_network_link.signalr]
}

resource "azurerm_private_dns_a_record" "servicebus" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_servicebus_namespace.main.name
  zone_name           = azurerm_private_dns_zone.servicebus[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.servicebus[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.servicebus, azurerm_private_dns_zone_virtual_network_link.servicebus]
}
