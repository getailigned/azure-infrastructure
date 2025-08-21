# HTMA Platform Infrastructure - Main Configuration
# This Terraform configuration deploys the complete HTMA platform infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  # GitHub Backend for state management
  backend "http" {
    address = "https://api.github.com/repos/getailigned/azure-infrastructure/contents/terraform/state/htma-platform.tfstate"
    lock_address = "https://api.github.com/repos/getailigned/azure-infrastructure/contents/terraform/state/htma-platform.tfstate"
    unlock_address = "https://api.github.com/repos/getailigned/azure-infrastructure/contents/terraform/state/htma-platform.tfstate"
    
    # GitHub authentication will be handled via GITHUB_TOKEN environment variable
    # or GitHub CLI authentication
  }
}

# Configure Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Configure Azure AD Provider
provider "azuread" {
  # Configuration will be handled by Azure CLI authentication
}

# Local variables
locals {
  # Common tags for all resources
  common_tags = {
    Environment     = var.environment
    Project         = "HTMA"
    ManagedBy       = "Terraform"
    Owner           = "HTMA Team"
    CostCenter      = "Engineering"
    DataClassification = "Internal"
  }
  
  # Resource naming convention
  resource_prefix = "htma-${var.environment}"
  
  # Location mapping
  primary_location   = var.primary_location
  secondary_location = var.secondary_location
  
  # Network configuration
  vnet_address_space = ["10.0.0.0/16"]
  subnet_configs = {
    apps = {
      name             = "apps-subnet"
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.ServiceBus", "Microsoft.Storage"]
    }
    data = {
      name             = "data-subnet"
      address_prefixes = ["10.0.2.0/24"]
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.ServiceBus", "Microsoft.Storage"]
    }
    gateway = {
      name             = "gateway-subnet"
      address_prefixes = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.KeyVault"]
    }
    private_endpoints = {
      name             = "private-endpoints-subnet"
      address_prefixes = ["10.0.4.0/24"]
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.ServiceBus", "Microsoft.Storage"]
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-htma-${var.environment}"
  location = local.primary_location
  
  tags = local.common_tags
}

# Resource Group for Secure Resources
resource "azurerm_resource_group" "secure" {
  name     = "rg-htma-${var.environment}-secure"
  location = local.primary_location
  
  tags = local.common_tags
}

# Random suffix for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data sources for existing resources (if taking over)
data "azurerm_client_config" "current" {}

# Network Module
module "networking" {
  source = "./modules/networking"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  vnet_address_space = local.vnet_address_space
  subnet_configs     = local.subnet_configs
  
  tags = local.common_tags
}

# Key Vault Module
module "key_vault" {
  source = "./modules/key_vault"
  
  resource_group_name = azurerm_resource_group.secure.name
  location           = local.primary_location
  environment        = var.environment
  
  key_vault_name = "${local.resource_prefix}-kv-${random_string.suffix.result}"
  
  # Access policies
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id
  
  # Network rules
  subnet_ids = [
    module.networking.subnet_ids["apps"],
    module.networking.subnet_ids["data"],
    module.networking.subnet_ids["gateway"]
  ]
  
  # Private endpoint configuration
  enable_private_endpoint = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  vnet_id = module.networking.vnet_id
  
  # Diagnostic settings
  enable_diagnostic_settings = var.enable_diagnostic_settings
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  log_retention_days = var.log_retention_days
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.monitoring]
}

# Container Registry Module
module "container_registry" {
  source = "./modules/container_registry"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  acr_name = "${local.resource_prefix}acr${random_string.suffix.result}"
  
  # Network rules
  subnet_ids = [
    module.networking.subnet_ids["apps"],
    module.networking.subnet_ids["data"]
  ]
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Container Apps Environment Module
module "container_apps_environment" {
  source = "./modules/container_apps_environment"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  environment_name = "${local.resource_prefix}-container-env"
  
  # Network configuration
  vnet_id = module.networking.vnet_id
  subnet_ids = {
    apps = module.networking.subnet_ids["apps"]
  }
  
  # Log Analytics
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  
  # Storage configuration
  enable_storage = var.enable_container_apps_storage
  
  # Dapr configuration
  enable_dapr = var.enable_dapr
  redis_host = module.cache.redis_host
  redis_password = module.cache.redis_password
  redis_port = module.cache.redis_port
  dapr_scopes = var.dapr_scopes
  
  # Workload profiles
  workload_profiles = var.container_apps_workload_profiles
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.monitoring, module.cache]
}

# Data Services Module
module "data_services" {
  source = "./modules/data_services"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  resource_name_prefix = local.resource_prefix
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["data"]
  vnet_id = module.networking.vnet_id
  
  # Admin credentials
  postgres_admin_username = var.postgres_admin_username
  postgres_admin_password = var.postgres_admin_password
  
  # PostgreSQL configuration
  postgres_storage_mb = var.postgres_storage_mb
  postgres_sku_name = var.postgres_sku_name
  postgres_backup_retention_days = var.postgres_backup_retention_days
  postgres_geo_redundant_backup = var.postgres_geo_redundant_backup
  postgres_zone = var.postgres_zone
  postgres_maintenance_day = var.postgres_maintenance_day
  postgres_maintenance_start_hour = var.postgres_maintenance_start_hour
  postgres_maintenance_start_minute = var.postgres_maintenance_start_minute
  postgres_allowed_ip_ranges = var.postgres_allowed_ip_ranges
  postgres_databases = var.postgres_databases
  
  # MongoDB configuration
  enable_mongodb = var.enable_mongodb
  
  # Storage configuration
  storage_containers = var.storage_containers
  storage_delete_retention_days = var.storage_delete_retention_days
  
  # Private endpoints
  enable_private_endpoints = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Cache Module
module "cache" {
  source = "./modules/cache"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  redis_name = "${local.resource_prefix}-redis-${random_string.suffix.result}"
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["data"]
  
  # Redis configuration
  redis_capacity = var.redis_capacity
  redis_family = var.redis_family
  redis_sku_name = var.redis_sku_name
  redis_maxmemory_reserved = var.redis_maxmemory_reserved
  redis_maxmemory_delta = var.redis_maxmemory_delta
  redis_maxmemory_policy = var.redis_maxmemory_policy
  redis_enable_non_ssl_port = var.redis_enable_non_ssl_port
  redis_patch_day = var.redis_patch_day
  redis_patch_start_hour = var.redis_patch_start_hour
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Messaging Module
module "messaging" {
  source = "./modules/messaging"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  service_bus_name = "${local.resource_prefix}-servicebus-${random_string.suffix.result}"
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["data"]
  
  # Service Bus configuration
  service_bus_sku = var.service_bus_sku
  service_bus_capacity = var.service_bus_capacity
  service_bus_zone_redundant = var.service_bus_zone_redundant
  service_bus_topics = var.service_bus_topics
  service_bus_subscriptions = var.service_bus_subscriptions
  service_bus_topic_max_size = var.service_bus_topic_max_size
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Real-time Services Module
module "realtime_services" {
  source = "./modules/realtime_services"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  resource_name_prefix = local.resource_prefix
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["data"]
  vnet_id = module.networking.vnet_id
  
  # SignalR configuration
  signalr_sku_name = var.signalr_sku_name
  signalr_capacity = var.signalr_capacity
  signalr_public_network_access = var.signalr_public_network_access
  
  # Redis configuration (if not using cache module)
  redis_host = module.cache.redis_host
  redis_password = module.cache.redis_password
  redis_port = module.cache.redis_port
  
  # Service Bus configuration
  servicebus_sku = var.service_bus_sku
  servicebus_capacity = var.service_bus_capacity
  servicebus_zone_redundant = var.service_bus_zone_redundant
  servicebus_topics = var.service_bus_topics
  servicebus_subscriptions = var.service_bus_subscriptions
  servicebus_topic_max_size = var.service_bus_topic_max_size
  
  # Event Grid configuration
  eventgrid_public_network_access = var.eventgrid_public_network_access
  enable_storage_events = var.enable_storage_events
  enable_servicebus_events = var.enable_servicebus_events
  storage_account_id = module.data_services.storage_account_id
  
  # Notification Hubs configuration
  enable_notification_hubs = var.enable_notification_hubs
  notification_hub_sku = var.notification_hub_sku
  notification_hub_public_network_access = var.notification_hub_public_network_access
  gcm_api_key = var.gcm_api_key
  apns_bundle_id = var.apns_bundle_id
  apns_key_id = var.apns_key_id
  apns_team_id = var.apns_team_id
  apns_token = var.apns_token
  
  # Private endpoints
  enable_private_endpoints = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.data_services]
}

# AI Services Module
module "ai_services" {
  source = "./modules/ai_services"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  resource_name_prefix = local.resource_prefix
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["data"]
  vnet_id = module.networking.vnet_id
  
  # OpenAI configuration
  openai_sku_name = var.openai_sku_name
  openai_public_network_access = var.openai_public_network_access
  openai_custom_subdomain = var.openai_custom_subdomain
  openai_model_deployments = var.openai_model_deployments
  
  # Cognitive Search configuration
  search_sku = var.cognitive_search_sku
  search_replica_count = var.cognitive_search_replica_count
  search_partition_count = var.cognitive_search_partition_count
  search_public_network_access = var.search_public_network_access
  
  # Storage configuration
  ai_storage_containers = var.ai_storage_containers
  ai_storage_shares = var.ai_storage_shares
  ai_storage_share_quota = var.ai_storage_share_quota
  storage_delete_retention_days = var.storage_delete_retention_days
  
  # Additional AI services
  enable_content_safety = var.enable_content_safety
  content_safety_sku = var.content_safety_sku
  content_safety_public_network_access = var.content_safety_public_network_access
  
  enable_form_recognizer = var.enable_form_recognizer
  form_recognizer_sku = var.form_recognizer_sku
  form_recognizer_public_network_access = var.form_recognizer_public_network_access
  
  enable_text_analytics = var.enable_text_analytics
  text_analytics_sku = var.text_analytics_sku
  text_analytics_public_network_access = var.text_analytics_public_network_access
  
  # Private endpoints
  enable_private_endpoints = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Container Apps Module
module "container_apps" {
  source = "./modules/container_apps"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  resource_name_prefix = local.resource_prefix
  container_apps_environment_id = module.container_apps_environment.environment_id
  
  # Container registry
  acr_login_server = module.container_registry.login_server
  
  # Container apps configuration
  container_apps_config = var.container_apps_scale_rules
  
  # Connection strings and endpoints
  postgres_connection_string = module.data_services.postgres_connection_string
  redis_connection_string = module.cache.redis_connection_string
  service_bus_connection_string = module.messaging.service_bus_connection_string
  signalr_connection_string = module.realtime_services.signalr_connection_string
  openai_endpoint = module.ai_services.openai_endpoint
  openai_api_key = var.openai_api_key
  elasticsearch_url = var.elasticsearch_url
  elasticsearch_username = var.elasticsearch_username
  elasticsearch_password = var.elasticsearch_password
  
  # Google Workspace configuration
  google_client_id = var.google_client_id
  google_client_secret = var.google_client_secret
  google_refresh_token = var.google_refresh_token
  notification_from_email = var.notification_from_email
  notification_from_name = var.notification_from_name
  
  # Key Vault
  key_vault_url = module.key_vault.vault_url
  
  tags = local.common_tags
  
  depends_on = [
    module.container_apps_environment,
    module.container_registry,
    module.data_services,
    module.cache,
    module.messaging,
    module.realtime_services,
    module.ai_services,
    module.key_vault
  ]
}

# Application Gateway Module
module "application_gateway" {
  source = "./modules/application_gateway"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  gateway_name = "${local.resource_prefix}-appgw"
  
  # Network configuration
  vnet_id = module.networking.vnet_id
  subnet_id = module.networking.subnet_ids["gateway"]
  
  # Container apps
  container_apps_fqdn = module.container_apps.environment_fqdn
  
  # SSL certificate
  ssl_certificate_path = var.ssl_certificate_path
  ssl_certificate_password = var.ssl_certificate_password
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.container_apps]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  log_analytics_name = "${local.resource_prefix}-law-${random_string.suffix.result}"
  app_insights_name = "${local.resource_prefix}-ai-${random_string.suffix.result}"
  
  # Configuration
  log_retention_days = var.log_retention_days
  app_insights_daily_data_cap_gb = var.app_insights_daily_data_cap_gb
  
  tags = local.common_tags
}

# API Management Module (for Cedar Policy integration)
module "api_management" {
  source = "./modules/api_management"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  apim_name = "${local.resource_prefix}-apim-${random_string.suffix.result}"
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["gateway"]
  
  # Key Vault
  key_vault_url = module.key_vault.vault_url
  
  # Container apps
  container_apps_fqdn = module.container_apps.environment_fqdn
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.key_vault, module.container_apps]
}

# Function App Module (for Cedar Policy evaluation)
module "function_app" {
  source = "./modules/function_app"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  function_app_name = "${local.resource_prefix}-cedar-policy-${random_string.suffix.result}"
  
  # Network configuration
  subnet_id = module.networking.subnet_ids["apps"]
  
  # App Service Plan
  app_service_plan_id = module.app_service_plan.plan_id
  
  # Key Vault
  key_vault_url = module.key_vault.vault_url
  
  # Redis connection
  redis_connection_string = module.cache.redis_connection_string
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.app_service_plan, module.key_vault, module.cache]
}

# App Service Plan Module
module "app_service_plan" {
  source = "./modules/app_service_plan"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  plan_name = "${local.resource_prefix}-asp-${random_string.suffix.result}"
  
  # Configuration
  sku_name = var.app_service_plan_sku
  os_type = var.app_service_plan_os_type
  
  tags = local.common_tags
}

# Static Web App Module
module "static_web_app" {
  source = "./modules/static_web_app"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = var.static_web_app_location
  environment        = var.environment
  
  static_web_app_name = "${local.resource_prefix}-webapp"
  
  # Configuration
  sku_tier = var.static_web_app_sku_tier
  app_settings = var.static_web_app_settings
  
  # Custom domains
  custom_domains = var.static_web_app_custom_domains
  
  # Function app integration
  enable_function_app = var.enable_static_web_app_function
  function_app_id = var.static_web_app_function_app_id
  function_name = var.static_web_app_function_name
  
  # Users and roles
  users = var.static_web_app_users
  role_assignments = var.static_web_app_role_assignments
  
  # Environment variables
  environment_variables = var.static_web_app_environment_variables
  
  # Private endpoint
  enable_private_endpoint = var.enable_static_web_app_private_endpoint
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoints"]
  vnet_id = module.networking.vnet_id
  
  # Diagnostic settings
  enable_diagnostic_settings = var.enable_diagnostic_settings
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  log_retention_days = var.log_retention_days
  
  # CDN
  enable_cdn = var.enable_static_web_app_cdn
  cdn_sku = var.static_web_app_cdn_sku
  
  tags = local.common_tags
  
  depends_on = [module.networking, module.monitoring]
}

# VPN Gateway Module (disabled by default)
module "vpn_gateway" {
  source = "./modules/vpn_gateway"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = local.primary_location
  environment        = var.environment
  
  vpn_gateway_name = "${local.resource_prefix}-vpn-gateway"
  
  # Network configuration
  gateway_subnet_id = module.networking.subnet_ids["gateway"]
  
  # VPN Gateway configuration
  enable_vpn_gateway = var.enable_vpn_gateway
  vpn_gateway_sku = var.vpn_gateway_sku
  vpn_gateway_generation = var.vpn_gateway_generation
  
  # VPN client configuration
  vpn_client_address_pool = var.vpn_client_address_pool
  vpn_client_protocols = var.vpn_client_protocols
  vpn_auth_types = var.vpn_auth_types
  vpn_client_root_certificates = var.vpn_client_root_certificates
  vpn_client_revoked_certificates = var.vpn_client_revoked_certificates
  vpn_client_routes = var.vpn_client_routes
  
  # BGP configuration
  enable_bgp = var.enable_vpn_bgp
  bgp_asn = var.vpn_bgp_asn
  
  tags = local.common_tags
  
  depends_on = [module.networking]
}

# Outputs
output "resource_group_name" {
  description = "Name of the main resource group"
  value       = azurerm_resource_group.main.name
}

output "container_apps_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = module.container_apps_environment.environment_id
}

output "container_apps_environment_fqdn" {
  description = "FQDN of the Container Apps Environment"
  value       = module.container_apps.environment_fqdn
}

output "key_vault_url" {
  description = "URL of the Key Vault"
  value       = module.key_vault.vault_url
}

output "acr_login_server" {
  description = "Login server of the Container Registry"
  value       = module.container_registry.login_server
}

output "application_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = module.application_gateway.public_ip_address
}

output "api_management_gateway_url" {
  description = "Gateway URL of API Management"
  value       = module.api_management.gateway_url
}

output "function_app_url" {
  description = "URL of the Cedar Policy Function App"
  value       = module.function_app.function_app_url
}

output "static_web_app_url" {
  description = "URL of the Static Web App"
  value       = module.static_web_app.default_host_name
}

output "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.data_services.postgres_server_name
}

output "redis_cache_name" {
  description = "Name of the Redis cache"
  value       = module.cache.redis_name
}

output "service_bus_namespace" {
  description = "Name of the Service Bus namespace"
  value       = module.messaging.service_bus_namespace
}

output "openai_account_name" {
  description = "Name of the OpenAI account"
  value       = module.ai_services.openai_account_name
}

output "search_service_name" {
  description = "Name of the Cognitive Search service"
  value       = module.ai_services.search_service_name
}
