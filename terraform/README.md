# HTMA Platform - Terraform Infrastructure

This directory contains the complete Terraform configuration for the HTMA platform, migrated from the original Bicep templates.

## 🚀 **Migration Overview**

The HTMA platform infrastructure has been migrated from Azure Bicep to HashiCorp Terraform to provide:

- **Better State Management** - Centralized state with Azure Storage backend
- **Enhanced Modularity** - Reusable modules for each infrastructure component
- **Improved Collaboration** - Better team workflows and version control
- **Advanced Features** - Workspaces, remote state, and advanced Terraform capabilities

## 🏗️ **Architecture**

The Terraform configuration follows a modular approach with the following structure:

```
terraform/
├── main.tf                          # Main configuration orchestrating all modules
├── variables.tf                     # Global variables and validation
├── environments/                    # Environment-specific configurations
│   ├── dev/                        # Development environment
│   │   └── terraform.tfvars        # Development variables
│   ├── staging/                    # Staging environment
│   └── prod/                       # Production environment
├── modules/                         # Reusable Terraform modules
│   ├── networking/                 # Virtual Network, Subnets, NSGs
│   ├── key_vault/                  # Azure Key Vault with access policies
│   ├── container_apps_environment/ # Container Apps Environment
│   ├── container_apps/             # Individual Container Apps
│   ├── database/                   # PostgreSQL Flexible Server
│   ├── cache/                      # Redis Cache
│   ├── messaging/                  # Service Bus
│   ├── ai_services/                # OpenAI and Cognitive Search
│   ├── application_gateway/        # Application Gateway
│   ├── monitoring/                 # Log Analytics and Application Insights
│   ├── api_management/             # API Management for Cedar Policy
│   ├── function_app/               # Azure Function App
│   └── app_service_plan/           # App Service Plan
└── scripts/                         # Migration and deployment scripts
    └── migrate-from-bicep.sh       # Bicep to Terraform migration script
```

## 🔄 **Migration Options**

### **Option 1: Import Existing Resources (Recommended)**
- **Pros**: No downtime, preserves existing data and configurations
- **Cons**: Complex import process, potential state conflicts
- **Use Case**: Production environments where downtime is not acceptable

### **Option 2: Destroy and Recreate**
- **Pros**: Clean state, no conflicts, fresh deployment
- **Cons**: Data loss, downtime, need to restore from backups
- **Use Case**: Development environments or when starting fresh

### **Option 3: Hybrid Approach**
- **Pros**: Balance of safety and complexity
- **Cons**: Requires careful planning and testing
- **Use Case**: Complex environments with mixed requirements

## 📋 **Prerequisites**

### **Required Tools**
- **Terraform** >= 1.0
- **Azure CLI** >= 2.55.0
- **Azure Subscription** with appropriate permissions
- **Git** for version control

### **Azure Permissions**
- **Contributor** role on the target subscription
- **Key Vault Administrator** role (if managing Key Vaults)
- **Network Contributor** role (if managing networking)

## 🚀 **Quick Start**

### **1. Clone and Navigate**
```bash
cd terraform/environments/dev
```

### **2. Initialize Terraform**
```bash
terraform init
```

### **3. Review the Plan**
```bash
terraform plan
```

### **4. Apply the Configuration**
```bash
terraform apply
```

## 🔐 **Configuration**

### **Environment Variables**
Set the following environment variables for Azure authentication:

```bash
export ARM_CLIENT_ID="your-service-principal-id"
export ARM_CLIENT_SECRET="your-service-principal-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

### **Terraform Variables**
Key variables that need to be configured:

```hcl
# Database Configuration
postgres_admin_username = "htma_admin"
postgres_admin_password = "secure-password"

# SSL Certificate (if using HTTPS)
ssl_certificate_path = "/path/to/certificate.pfx"
ssl_certificate_password = "cert-password"

# Container Apps Scaling
container_apps_scale_rules = {
  work_item_service = {
    min_replicas = 1
    max_replicas = 5
    cpu_threshold = 70
    memory_threshold = 80
  }
}
```

## 🔄 **Migration Process**

### **Automated Migration**
Use the provided migration script:

```bash
# Make script executable
chmod +x scripts/migrate-from-bicep.sh

# Run migration
./scripts/migrate-from-bicep.sh dev
```

### **Manual Migration Steps**

#### **Step 1: Backup Existing Infrastructure**
```bash
# Export current resource group template
az group export --name rg-htma-dev --output-file backup-template.json

# Export individual resources
az resource list --resource-group rg-htma-dev --query "[].{id:id, name:name, type:type}" --output tsv
```

#### **Step 2: Create Terraform State Backend**
```bash
# Create resource group for Terraform state
az group create --name rg-htma-terraform-state --location eastus

# Create storage account
az storage account create --name htmaterraformstate --resource-group rg-htma-terraform-state --location eastus --sku Standard_LRS

# Create container
az storage container create --name tfstate --account-name htmaterraformstate
```

#### **Step 3: Import Existing Resources**
```bash
# Initialize Terraform
terraform init

# Import existing resources (example for Key Vault)
terraform import module.key_vault.azurerm_key_vault.main /subscriptions/{subscription-id}/resourceGroups/rg-htma-dev/providers/Microsoft.KeyVault/vaults/{vault-name}

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

## 🏗️ **Module Details**

### **Networking Module**
- Virtual Network with multiple subnets
- Network Security Groups with appropriate rules
- Application Gateway public IP
- Private endpoints support

### **Key Vault Module**
- Secure Key Vault with access policies
- Network rules and private endpoints
- Diagnostic logging
- Soft delete and purge protection

### **Container Apps Environment Module**
- Container Apps Environment with networking
- Log Analytics integration
- Dapr component support
- Workload profile configuration

### **Container Apps Module**
- Individual microservice deployments
- Environment variable management
- Scaling rules and health checks
- Ingress configuration

### **Database Module**
- PostgreSQL Flexible Server
- Private networking
- Backup and monitoring
- High availability options

### **AI Services Module**
- OpenAI service with model deployments
- Cognitive Search service
- Network security and monitoring

## 🔒 **Security Features**

### **Network Security**
- Private subnets for different resource types
- Network Security Groups with least-privilege access
- Private endpoints for sensitive services
- Service endpoints for Azure services

### **Identity and Access**
- Managed identities for services
- Key Vault access policies
- Azure AD integration
- Role-based access control

### **Data Protection**
- Encryption at rest and in transit
- Private networking for data services
- Backup and disaster recovery
- Audit logging and monitoring

## 📊 **Monitoring and Observability**

### **Log Analytics**
- Centralized logging for all services
- Custom queries and dashboards
- Alert rules and notifications
- Performance monitoring

### **Application Insights**
- Application performance monitoring
- Dependency tracking
- Custom metrics and events
- Real-time monitoring

### **Diagnostic Settings**
- Resource-level logging
- Azure Monitor integration
- Custom log retention policies
- Cost optimization

## 🔄 **CI/CD Integration**

### **GitHub Actions**
The Terraform configuration is designed to work with GitHub Actions:

```yaml
# Example GitHub Actions workflow
- name: Terraform Plan
  run: terraform plan -out=tfplan

- name: Terraform Apply
  run: terraform apply tfplan
```

### **Azure DevOps**
Integration with Azure DevOps pipelines:

```yaml
# Example Azure DevOps task
- task: TerraformTaskV4@4
  inputs:
    provider: 'azurerm'
    command: 'apply'
    workingDirectory: '$(System.DefaultWorkingDirectory)/terraform'
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **State Lock Issues**
```bash
# Force unlock state (use with caution)
terraform force-unlock <lock-id>
```

#### **Import Conflicts**
```bash
# Remove conflicting resources from state
terraform state rm <resource-address>

# Import with correct address
terraform import <resource-address> <resource-id>
```

#### **Provider Issues**
```bash
# Update provider versions
terraform init -upgrade

# Clean provider cache
rm -rf .terraform
terraform init
```

### **Debug Commands**
```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Validate configuration
terraform validate

# Check state
terraform state list
terraform show
```

## 📚 **Documentation and Resources**

### **Terraform Documentation**
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Language Documentation](https://www.terraform.io/language)
- [Terraform Best Practices](https://www.terraform.io/cloud/guides/recommended-practices)

### **Azure Documentation**
- [Azure Container Apps](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Azure Networking](https://docs.microsoft.com/en-us/azure/networking/)

### **HTMA-Specific Resources**
- [Architecture Documentation](../docs/)
- [Migration Guide](./MIGRATION_GUIDE.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

## 🤝 **Support and Contributing**

### **Getting Help**
- **Issues**: Create GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Documentation**: Update documentation for improvements

### **Contributing**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### **Code Standards**
- Use consistent naming conventions
- Include proper documentation
- Follow Terraform best practices
- Test all changes before submitting

## 📄 **License**

This Terraform configuration is part of the HTMA platform and follows the same license terms as the main project.

---

**🎉 Welcome to the Terraform-powered HTMA platform!**

For questions and support, refer to the documentation or create an issue in the repository.
