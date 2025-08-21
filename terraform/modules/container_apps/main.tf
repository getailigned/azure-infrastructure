# Container Apps Module - Main Configuration
# Provides individual microservice Container Apps

# Container App for Work Item Service
resource "azurerm_container_app" "work_item_service" {
  name                         = "${var.resource_name_prefix}-work-item-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "work-item-service"
      image  = "${var.acr_login_server}/htma/work-item-service:latest"
      cpu    = var.container_apps_config.work_item_service.cpu
      memory = var.container_apps_config.work_item_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "POSTGRES_CONNECTION_STRING"
        value = var.postgres_connection_string
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3000
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.work_item_service.min_replicas
      max_replicas = var.container_apps_config.work_item_service.max_replicas
      
      rule {
        name = "cpu-rule"
        http {
          metadata {
            concurrentRequests = "10"
          }
        }
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.work_item_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.work_item_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for Dependency Service
resource "azurerm_container_app" "dependency_service" {
  name                         = "${var.resource_name_prefix}-dependency-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "dependency-service"
      image  = "${var.acr_login_server}/htma/dependency-service:latest"
      cpu    = var.container_apps_config.dependency_service.cpu
      memory = var.container_apps_config.dependency_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "POSTGRES_CONNECTION_STRING"
        value = var.postgres_connection_string
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3001
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.dependency_service.min_replicas
      max_replicas = var.container_apps_config.dependency_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.dependency_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.dependency_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3001
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for AI Insights Service
resource "azurerm_container_app" "ai_insights_service" {
  name                         = "${var.resource_name_prefix}-ai-insights-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "ai-insights-service"
      image  = "${var.acr_login_server}/htma/ai-insights-service:latest"
      cpu    = var.container_apps_config.ai_insights_service.cpu
      memory = var.container_apps_config.ai_insights_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "POSTGRES_CONNECTION_STRING"
        value = var.postgres_connection_string
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
      
      env {
        name  = "OPENAI_API_KEY"
        value = var.openai_api_key
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3002
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.ai_insights_service.min_replicas
      max_replicas = var.container_apps_config.ai_insights_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.ai_insights_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.ai_insights_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3002
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for WebSocket Service
resource "azurerm_container_app" "websocket_service" {
  name                         = "${var.resource_name_prefix}-websocket-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "websocket-service"
      image  = "${var.acr_login_server}/htma/websocket-service:latest"
      cpu    = var.container_apps_config.websocket_service.cpu
      memory = var.container_apps_config.websocket_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "SIGNALR_CONNECTION_STRING"
        value = var.signalr_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3003
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.websocket_service.min_replicas
      max_replicas = var.container_apps_config.websocket_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.websocket_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.websocket_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3003
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for Search Service
resource "azurerm_container_app" "search_service" {
  name                         = "${var.resource_name_prefix}-search-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "search-service"
      image  = "${var.acr_login_server}/htma/search-service:latest"
      cpu    = var.container_apps_config.search_service.cpu
      memory = var.container_apps_config.search_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "ELASTICSEARCH_URL"
        value = var.elasticsearch_url
      }
      
      env {
        name  = "ELASTICSEARCH_USERNAME"
        value = var.elasticsearch_username
      }
      
      env {
        name  = "ELASTICSEARCH_PASSWORD"
        value = var.elasticsearch_password
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3004
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.search_service.min_replicas
      max_replicas = var.container_apps_config.search_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.search_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.search_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3004
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for HTA Builder Service
resource "azurerm_container_app" "hta_builder_service" {
  name                         = "${var.resource_name_prefix}-hta-builder-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "hta-builder-service"
      image  = "${var.acr_login_server}/htma/hta-builder-service:latest"
      cpu    = var.container_apps_config.hta_builder_service.cpu
      memory = var.container_apps_config.hta_builder_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "POSTGRES_CONNECTION_STRING"
        value = var.postgres_connection_string
      }
      
      env {
        name  = "OPENAI_ENDPOINT"
        value = var.openai_endpoint
      }
      
      env {
        name  = "OPENAI_API_KEY"
        value = var.openai_api_key
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3005
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.hta_builder_service.min_replicas
      max_replicas = var.container_apps_config.hta_builder_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.hta_builder_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.hta_builder_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3005
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for Notification Service
resource "azurerm_container_app" "notification_service" {
  name                         = "${var.resource_name_prefix}-notification-service"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "notification-service"
      image  = "${var.acr_login_server}/htma/notification-service:latest"
      cpu    = var.container_apps_config.notification_service.cpu
      memory = var.container_apps_config.notification_service.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "POSTGRES_CONNECTION_STRING"
        value = var.postgres_connection_string
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "SERVICE_BUS_CONNECTION_STRING"
        value = var.service_bus_connection_string
      }
      
      env {
        name  = "GOOGLE_CLIENT_ID"
        value = var.google_client_id
      }
      
      env {
        name  = "GOOGLE_CLIENT_SECRET"
        value = var.google_client_secret
      }
      
      env {
        name  = "GOOGLE_REFRESH_TOKEN"
        value = var.google_refresh_token
      }
      
      env {
        name  = "NOTIFICATION_FROM_EMAIL"
        value = var.notification_from_email
      }
      
      env {
        name  = "NOTIFICATION_FROM_NAME"
        value = var.notification_from_name
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 3006
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.notification_service.min_replicas
      max_replicas = var.container_apps_config.notification_service.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.notification_service.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.notification_service.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 3006
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}

# Container App for Express Gateway (API Gateway)
resource "azurerm_container_app" "express_gateway" {
  name                         = "${var.resource_name_prefix}-express-gateway"
  container_app_environment_id = var.container_apps_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  
  template {
    container {
      name   = "express-gateway"
      image  = "${var.acr_login_server}/htma/express-gateway:latest"
      cpu    = var.container_apps_config.express_gateway.cpu
      memory = var.container_apps_config.express_gateway.memory
      
      # Environment variables
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "REDIS_CONNECTION_STRING"
        value = var.redis_connection_string
      }
      
      env {
        name  = "KEY_VAULT_URL"
        value = var.key_vault_url
      }
      
      # Port configuration
      port = 8080
    }
    
    # Scale rules
    scale {
      min_replicas = var.container_apps_config.express_gateway.min_replicas
      max_replicas = var.container_apps_config.express_gateway.max_replicas
      
      rule {
        name = "cpu-rule"
        custom {
          type = "cpu"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.express_gateway.cpu_threshold
          }
        }
      }
      
      rule {
        name = "memory-rule"
        custom {
          type = "memory"
          metadata = {
            type  = "Utilization"
            value = var.container_apps_config.express_gateway.memory_threshold
          }
        }
      }
    }
  }
  
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  
  tags = var.tags
}
