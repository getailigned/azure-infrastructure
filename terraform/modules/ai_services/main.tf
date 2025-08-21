# AI Services Module - Main Configuration
# Provides OpenAI, Cognitive Search, and other AI services

# OpenAI Account
resource "azurerm_cognitive_account" "openai" {
  name                = "${var.resource_name_prefix}-openai"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = var.openai_sku_name
  
  # Network configuration
  public_network_access_enabled = var.openai_public_network_access
  
  # Custom subdomain
  custom_subdomain_name = var.openai_custom_subdomain
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# OpenAI Model Deployments
resource "azurerm_cognitive_deployment" "models" {
  for_each = var.openai_model_deployments
  
  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.version
  }
  
  scale {
    type = "Standard"
    capacity = each.value.capacity
  }
  
  tags = var.tags
}

# Azure Cognitive Search Service
resource "azurerm_search_service" "main" {
  name                = "${var.resource_name_prefix}-search"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.search_sku
  replica_count       = var.search_replica_count
  partition_count     = var.search_partition_count
  
  # Network configuration
  public_network_access_enabled = var.search_public_network_access
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Cognitive Search Private Endpoint (if enabled)
resource "azurerm_private_endpoint" "search" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-search-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-search-psc"
    private_connection_resource_id = azurerm_search_service.main.id
    is_manual_connection           = false
    subresource_names             = ["searchService"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Cognitive Search (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "search" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.search.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-search-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.search[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Cognitive Search Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "search" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_search_service.main.name
  zone_name           = azurerm_private_dns_zone.search[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.search[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.search, azurerm_private_dns_zone_virtual_network_link.search]
}

# Storage Account for AI services
resource "azurerm_storage_account" "main" {
  name                     = replace("${var.resource_name_prefix}ai${random_string.storage.result}", "-", "")
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
  
  # File share properties
  share_properties {
    retention_policy {
      days = var.storage_delete_retention_days
    }
  }
  
  tags = var.tags
}

# Storage Container for AI data
resource "azurerm_storage_container" "ai_data" {
  for_each = toset(var.ai_storage_containers)
  
  name                  = each.value
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# File Share for AI services
resource "azurerm_storage_share" "ai_data" {
  for_each = toset(var.ai_storage_shares)
  
  name                 = each.value
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.ai_storage_share_quota
}

# Random string for storage account name
resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# Azure Content Safety (if enabled)
resource "azurerm_cognitive_account" "content_safety" {
  count = var.enable_content_safety ? 1 : 0
  
  name                = "${var.resource_name_prefix}-content-safety"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "ContentSafety"
  sku_name            = var.content_safety_sku
  
  # Network configuration
  public_network_access_enabled = var.content_safety_public_network_access
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Azure Form Recognizer (if enabled)
resource "azurerm_cognitive_account" "form_recognizer" {
  count = var.enable_form_recognizer ? 1 : 0
  
  name                = "${var.resource_name_prefix}-form-recognizer"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "FormRecognizer"
  sku_name            = var.form_recognizer_sku
  
  # Network configuration
  public_network_access_enabled = var.form_recognizer_public_network_access
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Azure Text Analytics (if enabled)
resource "azurerm_cognitive_account" "text_analytics" {
  count = var.enable_text_analytics ? 1 : 0
  
  name                = "${var.resource_name_prefix}-text-analytics"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "TextAnalytics"
  sku_name            = var.text_analytics_sku
  
  # Network configuration
  public_network_access_enabled = var.text_analytics_public_network_access
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Private Endpoint for Storage (if enabled)
resource "azurerm_private_endpoint" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${var.resource_name_prefix}-ai-storage-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.resource_name_prefix}-ai-storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names             = ["blob", "file"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Storage (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Private DNS Zone for File Storage (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "file_storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zones to VNet (if private endpoints are enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-ai-storage-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_storage" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                  = "${var.resource_name_prefix}-ai-file-storage-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.file_storage[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Records for Storage Private Endpoints (if private endpoints are enabled)
resource "azurerm_private_dns_a_record" "storage_blob" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = azurerm_storage_account.main.name
  zone_name           = azurerm_private_dns_zone.storage[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.storage, azurerm_private_dns_zone_virtual_network_link.storage]
}

resource "azurerm_private_dns_a_record" "storage_file" {
  count = var.enable_private_endpoints ? 1 : 0
  
  name                = "${azurerm_storage_account.main.name}.file"
  zone_name           = azurerm_private_dns_zone.file_storage[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.storage, azurerm_private_dns_zone_virtual_network_link.file_storage]
}
