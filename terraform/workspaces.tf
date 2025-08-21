# Workspace Configuration for HTMA Platform
# This file defines the workspace structure for multiple environments and cloud providers

# Workspace-specific variables
locals {
  # Get current workspace name
  current_workspace = terraform.workspace
  
  # Workspace configurations
  workspaces = {
    # Azure Development Environment
    "azure-dev" = {
      cloud_provider = "azure"
      environment    = "dev"
      location       = "eastus"
      resource_group = "rg-htma-dev"
      tags = {
        Environment     = "dev"
        CloudProvider  = "azure"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
    
    # Azure Staging Environment
    "azure-staging" = {
      cloud_provider = "azure"
      environment    = "staging"
      location       = "eastus2"
      resource_group = "rg-htma-staging"
      tags = {
        Environment     = "staging"
        CloudProvider  = "azure"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
    
    # Azure Production Environment
    "azure-prod" = {
      cloud_provider = "azure"
      environment    = "prod"
      location       = "eastus"
      resource_group = "rg-htma-prod"
      tags = {
        Environment     = "prod"
        CloudProvider  = "azure"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
    
    # Google Cloud Development Environment
    "gcp-dev" = {
      cloud_provider = "gcp"
      environment    = "dev"
      location       = "us-east1"
      project_id     = "htma-dev-project"
      tags = {
        Environment     = "dev"
        CloudProvider  = "gcp"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
    
    # Google Cloud Staging Environment
    "gcp-staging" = {
      cloud_provider = "gcp"
      environment    = "staging"
      location       = "us-east1"
      project_id     = "htma-staging-project"
      tags = {
        Environment     = "staging"
        CloudProvider  = "gcp"
        Project        = "gcp"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
    
    # Google Cloud Production Environment
    "gcp-prod" = {
      cloud_provider = "gcp"
      environment    = "prod"
      location       = "us-central1"
      project_id     = "htma-prod-project"
      tags = {
        Environment     = "prod"
        CloudProvider  = "gcp"
        Project        = "HTMA"
        ManagedBy      = "Terraform"
        Owner          = "HTMA Team"
        CostCenter     = "Engineering"
      }
    }
  }
  
  # Current workspace configuration
  workspace_config = local.workspaces[local.current_workspace]
  
  # Cloud provider specific settings
  is_azure = local.workspace_config.cloud_provider == "azure"
  is_gcp   = local.workspace_config.cloud_provider == "gcp"
  
  # Common tags
  common_tags = local.workspace_config.tags
}

# Output current workspace information
output "current_workspace" {
  description = "Current Terraform workspace name"
  value       = local.current_workspace
}

output "cloud_provider" {
  description = "Current cloud provider"
  value       = local.workspace_config.cloud_provider
}

output "environment" {
  description = "Current environment"
  value       = local.workspace_config.environment
}

output "location" {
  description = "Current location/region"
  value       = local.workspace_config.location
}
