# HTMA Platform Infrastructure - Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "primary_location" {
  description = "Primary Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "secondary_location" {
  description = "Secondary Azure region for disaster recovery"
  type        = string
  default     = "eastus2"
}

# Database Configuration
variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "htma_admin"
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

# SSL Certificate Configuration
variable "ssl_certificate_path" {
  description = "Path to SSL certificate file"
  type        = string
  default     = ""
}

variable "ssl_certificate_password" {
  description = "SSL certificate password"
  type        = string
  default     = ""
  sensitive   = true
}

# Container Apps Configuration
variable "container_apps_scale_rules" {
  description = "Scale rules for container apps"
  type = map(object({
    min_replicas = number
    max_replicas = number
    cpu_threshold = number
    memory_threshold = number
  }))
  default = {
    work_item_service = {
      min_replicas = 1
      max_replicas = 5
      cpu_threshold = 70
      memory_threshold = 80
    }
    dependency_service = {
      min_replicas = 1
      max_replicas = 3
      cpu_threshold = 70
      memory_threshold = 80
    }
    ai_insights_service = {
      min_replicas = 1
      max_replicas = 3
      cpu_threshold = 70
      memory_threshold = 80
    }
    express_gateway = {
      min_replicas = 2
      max_replicas = 10
      cpu_threshold = 70
      memory_threshold = 80
    }
  }
}

# AI Services Configuration
variable "openai_sku" {
  description = "OpenAI service SKU"
  type        = string
  default     = "S0"
}

variable "openai_model_deployments" {
  description = "OpenAI model deployments"
  type = map(object({
    model_name = string
    version    = string
    capacity   = number
  }))
  default = {
    gpt4 = {
      model_name = "gpt-4"
      version    = "0613"
      capacity   = 10
    }
    gpt35 = {
      model_name = "gpt-35-turbo"
      version    = "0613"
      capacity   = 20
    }
  }
}

variable "cognitive_search_sku" {
  description = "Cognitive Search service SKU"
  type        = string
  default     = "Standard"
}

variable "cognitive_search_replica_count" {
  description = "Number of Cognitive Search replicas"
  type        = number
  default     = 1
}

variable "cognitive_search_partition_count" {
  description = "Number of Cognitive Search partitions"
  type        = number
  default     = 1
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}

variable "app_insights_daily_data_cap_gb" {
  description = "Daily data cap for Application Insights in GB"
  type        = number
  default     = 5
}

# Network Configuration
variable "enable_private_endpoints" {
  description = "Enable private endpoints for services"
  type        = bool
  default     = true
}

variable "enable_service_endpoints" {
  description = "Enable service endpoints for subnets"
  type        = bool
  default     = true
}

# Security Configuration
variable "enable_azure_defender" {
  description = "Enable Azure Defender for Key Vault"
  type        = bool
  default     = true
}

variable "enable_soft_delete" {
  description = "Enable soft delete for Key Vault"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention period in days"
  type        = number
  default     = 7
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Cost Management
variable "enable_cost_management" {
  description = "Enable cost management and budgeting"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 1000
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable backup for critical resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}
