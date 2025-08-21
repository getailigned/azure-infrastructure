# Data Services Module - Main Configuration
# Provides PostgreSQL, MongoDB, and other data services

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.resource_name_prefix}-postgres"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "14"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  storage_mb             = var.postgres_storage_mb
  sku_name               = var.postgres_sku_name
  
  # Network configuration
  subnet_id = var.subnet_id
  
  # Backup configuration
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = var.postgres_geo_redundant_backup
  
  # High availability
  zone = var.postgres_zone
  
  # Maintenance window
  maintenance_window {
    day_of_week  = var.postgres_maintenance_day
    start_hour   = var.postgres_maintenance_start_hour
    start_minute = var.postgres_maintenance_start_minute
  }
  
  tags = var.tags
}

# PostgreSQL Flexible Server Firewall Rule
resource "azurerm_postgresql_flexible_server_firewall_rule" "main" {
  count = length(var.postgres_allowed_ip_ranges)
  
  name             = "allow-ip-${count.index}"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = var.postgres_allowed_ip_ranges[count.index]
  end_ip_address   = var.postgres_allowed_ip_ranges[count.index]
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  for_each = toset(var.postgres_databases)
  
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# MongoDB Account (Cosmos DB)
resource "azurerm_cosmosdb_account" "main" {
  count = var.enable_mongodb ? 1 : 0
  
  name                = "${var.resource_name_prefix}-cosmos"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"
  
  # Consistency policy
  consistency_policy {
    consistency_level = "Session"
  }
  
  # Geo location
  geo_location {
    location          = var.location
    failover_priority = 0
  }
  
  # Capabilities
  capabilities {
    name = "EnableMongo"
  }
  
  # Network configuration
  is_virtual_network_filter_enabled = true
  virtual_network_rule {
    id = var.subnet_id
  }
  
  tags = var.tags
}

# MongoDB Database
resource "azurerm_cosmosdb_mongo_database" "main" {
  count = var.enable_mongodb ? 1 : 0
  
  name                = "htma-mongodb"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main[0].name
}

# Storage Account for data services
resource "azurerm_storage_account" "main" {
  name                     = replace("${var.resource_name_prefix}st${random_string.storage.result}", "-", "")
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
  
  # Blob properties
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = var.storage_delete_retention_days
    }
  }
  
  tags = var.tags
}

# Storage Container for data
resource "azurerm_storage_container" "main" {
  for_each = toset(var.storage_containers)
  
  name                  = each.value
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Random string for storage account name
resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# Private Endpoint for PostgreSQL (if enabled)
resource "azurerm_private_endpoint" "postgres" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-postgres-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-postgres-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.main.id
    is_manual_connection           = false
    subresource_names             = ["postgresqlServer"]
  }
  
  tags = var.tags
}

# Private Endpoint for Storage (if enabled)
resource "azurerm_private_endpoint" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-storage-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names             = ["blob"]
  }
  
  tags = var.tags
}

# Private DNS Zone for PostgreSQL (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "postgres" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Private DNS Zone for Storage (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zones to VNet (if private endpoints are enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-postgres-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-storage-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Records for Private Endpoints (if private endpoints are enabled)
resource "azurerm_private_dns_a_record" "postgres" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_postgresql_flexible_server.main.name
  zone_name           = azurerm_private_dns_zone.postgres[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.postgres[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.postgres, azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_private_dns_a_record" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_storage_account.main.name
  zone_name           = azurerm_private_dns_zone.storage[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.storage, azurerm_private_dns_zone_virtual_network_link.storage]
}
