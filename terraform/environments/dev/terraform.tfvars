# Development Environment Configuration

environment = "dev"
primary_location = "eastus"
secondary_location = "eastus2"

# Database Configuration
postgres_admin_username = "htma_dev_admin"
postgres_admin_password = "HTMA_Dev_Password_2024!" # Change this in production

# Container Apps Configuration
container_apps_scale_rules = {
  work_item_service = {
    min_replicas = 1
    max_replicas = 3
    cpu_threshold = 70
    memory_threshold = 80
  }
  dependency_service = {
    min_replicas = 1
    max_replicas = 2
    cpu_threshold = 70
    memory_threshold = 80
  }
  ai_insights_service = {
    min_replicas = 1
    max_replicas = 2
    cpu_threshold = 70
    memory_threshold = 80
  }
  express_gateway = {
    min_replicas = 1
    max_replicas = 3
    cpu_threshold = 70
    memory_threshold = 80
  }
}

# AI Services Configuration
openai_sku = "S0"
cognitive_search_sku = "Standard"
cognitive_search_replica_count = 1
cognitive_search_partition_count = 1

# Monitoring Configuration
log_retention_days = 30
app_insights_daily_data_cap_gb = 5

# Network Configuration
enable_private_endpoints = true
enable_service_endpoints = true

# Security Configuration
enable_azure_defender = true
enable_soft_delete = true
soft_delete_retention_days = 7

# Cost Management
enable_cost_management = true
monthly_budget_amount = 500

# Backup Configuration
enable_backup = true
backup_retention_days = 30

# Additional Tags
additional_tags = {
  Environment = "Development"
  CostCenter  = "Engineering-Dev"
  Owner       = "HTMA-Dev-Team"
}
