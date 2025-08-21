# Static Web App Module - Main Configuration
# Provides Azure Static Web App for frontend hosting

# Static Web App
resource "azurerm_static_site" "main" {
  name                = var.static_web_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.sku_tier
  
  # App settings
  app_settings = var.app_settings
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Static Web App Custom Domain (if provided)
resource "azurerm_static_site_custom_domain" "main" {
  for_each = var.custom_domains
  
  static_site_id = azurerm_static_site.main.id
  domain_name    = each.value.domain_name
  
  # Validation method
  validation_type = each.value.validation_type
  
  # DNS validation (if using DNS validation)
  dynamic "dns_validation" {
    for_each = each.value.validation_type == "dns" ? [1] : []
    content {
      dns_record_type = each.value.dns_record_type
      dns_record_name = each.value.dns_record_name
      dns_record_value = each.value.dns_record_value
    }
  }
  
  # HTTP validation (if using HTTP validation)
  dynamic "http_validation" {
    for_each = each.value.validation_type == "http" ? [1] : []
    content {
      validation_url = each.value.validation_url
    }
  }
}

# Static Web App Function App (if enabled)
resource "azurerm_static_site_function_app" "main" {
  count = var.enable_function_app ? 1 : 0
  
  static_site_id = azurerm_static_site.main.id
  function_app_id = var.function_app_id
  function_name   = var.function_name
}

# Static Web App User (if provided)
resource "azurerm_static_site_user" "main" {
  for_each = var.users
  
  static_site_id = azurerm_static_site.main.id
  email          = each.value.email
  role           = each.value.role
}

# Static Web App Role Assignment (if provided)
resource "azurerm_static_site_role_assignment" "main" {
  for_each = var.role_assignments
  
  static_site_id = azurerm_static_site.main.id
  principal_id   = each.value.principal_id
  role_definition_id = each.value.role_definition_id
}

# Static Web App Environment Variable (if provided)
resource "azurerm_static_site_environment_variable" "main" {
  for_each = var.environment_variables
  
  static_site_id = azurerm_static_site.main.id
  environment    = each.value.environment
  key           = each.value.key
  value         = each.value.value
}

# Private Endpoint for Static Web App (if enabled)
resource "azurerm_private_endpoint" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${var.static_web_app_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "${var.static_web_app_name}-psc"
    private_connection_resource_id = azurerm_static_site.main.id
    is_manual_connection           = false
    subresource_names             = ["sites"]
  }
  
  tags = var.tags
}

# Private DNS Zone for Static Web App (if private endpoint is enabled)
resource "azurerm_private_dns_zone" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.azurestaticwebsites.net"
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Link Private DNS Zone to VNet (if private endpoint is enabled)
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${var.static_web_app_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main[0].name
  virtual_network_id    = var.vnet_id
  
  tags = var.tags
}

# DNS A Record for Static Web App Private Endpoint (if private endpoint is enabled)
resource "azurerm_private_dns_a_record" "main" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = azurerm_static_site.main.name
  zone_name           = azurerm_private_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address]
  
  depends_on = [azurerm_private_endpoint.main, azurerm_private_dns_zone_virtual_network_link.main]
}

# Diagnostic Settings for Static Web App
resource "azurerm_monitor_diagnostic_setting" "main" {
  count = var.enable_diagnostic_settings ? 1 : 0
  
  name                       = "${var.static_web_app_name}-diag"
  target_resource_id         = azurerm_static_site.main.id
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
    category = "RequestEvent"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
  
  log {
    category = "ErrorEvent"
    enabled  = true
    
    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}

# CDN Profile for Static Web App (if enabled)
resource "azurerm_cdn_profile" "main" {
  count = var.enable_cdn ? 1 : 0
  
  name                = "${var.static_web_app_name}-cdn"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.cdn_sku
  
  tags = var.tags
}

# CDN Endpoint for Static Web App (if CDN is enabled)
resource "azurerm_cdn_endpoint" "main" {
  count = var.enable_cdn ? 1 : 0
  
  name                = "${var.static_web_app_name}-endpoint"
  profile_name        = azurerm_cdn_profile.main[0].name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  # Origin configuration
  origin {
    name       = "static-web-app-origin"
    host_name  = azurerm_static_site.main.default_host_name
    http_port  = 80
    https_port = 443
  }
  
  # Optimization settings
  optimization_type = "GeneralWebDelivery"
  
  # Compression settings
  compression_enabled = true
  
  # Query string caching behavior
  querystring_caching_behaviour = "IgnoreQueryString"
  
  tags = var.tags
}

# CDN Endpoint Custom Domain (if CDN and custom domains are enabled)
resource "azurerm_cdn_endpoint_custom_domain" "main" {
  for_each = var.enable_cdn ? var.custom_domains : {}
  
  name            = each.key
  cdn_endpoint_id = azurerm_cdn_endpoint.main[0].id
  host_name       = each.value.domain_name
  
  # HTTPS settings
  https_configuration {
    https_enabled = true
    certificate_source = "Cdn"
  }
}
