#!/bin/bash

# HTMA Platform - Bicep to Terraform Migration Script
# This script helps migrate from existing Bicep-deployed infrastructure to Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/.."
ENVIRONMENT=${1:-dev}
RESOURCE_GROUP="rg-htma-${ENVIRONMENT}"

echo -e "${BLUE}🚀 HTMA Platform - Bicep to Terraform Migration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        echo -e "${RED}❌ Not logged into Azure. Please run 'az login' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
    echo ""
}

# Function to analyze current infrastructure
analyze_infrastructure() {
    echo -e "${YELLOW}🔍 Analyzing current Bicep-deployed infrastructure...${NC}"
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${RED}❌ Resource group '$RESOURCE_GROUP' not found${NC}"
        exit 1
    fi
    
    # List all resources
    echo -e "${BLUE}📋 Current resources in '$RESOURCE_GROUP':${NC}"
    az resource list --resource-group "$RESOURCE_GROUP" \
        --query "[].{name:name, type:type, location:location}" \
        --output table
    
    echo ""
    
    # Check for specific resource types
    echo -e "${BLUE}🔍 Checking for key resources...${NC}"
    
    # Check Container Apps
    if az containerapp list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv | grep -q .; then
        echo -e "${GREEN}✅ Container Apps found${NC}"
    else
        echo -e "${YELLOW}⚠️  No Container Apps found${NC}"
    fi
    
    # Check Key Vault
    if az keyvault list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv | grep -q .; then
        echo -e "${GREEN}✅ Key Vault found${NC}"
    else
        echo -e "${YELLOW}⚠️  No Key Vault found${NC}"
    fi
    
    # Check PostgreSQL
    if az postgres flexible-server list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv | grep -q .; then
        echo -e "${GREEN}✅ PostgreSQL found${NC}"
    else
        echo -e "${YELLOW}⚠️  No PostgreSQL found${NC}"
    fi
    
    echo ""
}

# Function to create Terraform state backend
create_terraform_backend() {
    echo -e "${YELLOW}🏗️  Creating Terraform state backend...${NC}"
    
    # Create resource group for Terraform state
    az group create \
        --name "rg-htma-terraform-state" \
        --location "eastus" \
        --output none
    
    # Create storage account for Terraform state
    az storage account create \
        --name "htmaterraformstate" \
        --resource-group "rg-htma-terraform-state" \
        --location "eastus" \
        --sku "Standard_LRS" \
        --output none
    
    # Create container for Terraform state
    az storage container create \
        --name "tfstate" \
        --account-name "htmaterraformstate" \
        --output none
    
    echo -e "${GREEN}✅ Terraform state backend created${NC}"
    echo ""
}

# Function to backup existing resources
backup_resources() {
    echo -e "${YELLOW}💾 Creating backup of existing resources...${NC}"
    
    BACKUP_DIR="$SCRIPT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Export resource group template
    az group export \
        --name "$RESOURCE_GROUP" \
        --output-file "$BACKUP_DIR/resource-group-template.json"
    
    # Export individual resources
    az resource list --resource-group "$RESOURCE_GROUP" --query "[].{id:id, name:name, type:type}" --output tsv | while read -r id name type; do
        if [[ -n "$id" ]]; then
            echo "Backing up $name ($type)..."
            az resource show --ids "$id" --output json > "$BACKUP_DIR/${name//[^a-zA-Z0-9]/_}.json"
        fi
    done
    
    echo -e "${GREEN}✅ Backup created in: $BACKUP_DIR${NC}"
    echo ""
}

# Function to check if Terraform can import existing resources
check_terraform_import() {
    echo -e "${YELLOW}🔍 Checking Terraform import compatibility...${NC}"
    
    # Check if main Terraform configuration exists
    if [[ ! -f "$TERRAFORM_DIR/main.tf" ]]; then
        echo -e "${RED}❌ Terraform main.tf not found in $TERRAFORM_DIR${NC}"
        exit 1
    fi
    
    # Check if environment configuration exists
    if [[ ! -f "$TERRAFORM_DIR/environments/$ENVIRONMENT/terraform.tfvars" ]]; then
        echo -e "${RED}❌ Environment configuration not found: $TERRAFORM_DIR/environments/$ENVIRONMENT/terraform.tfvars${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Terraform configuration found${NC}"
    echo ""
}

# Function to provide migration options
show_migration_options() {
    echo -e "${BLUE}🔄 Migration Options:${NC}"
    echo ""
    echo "1. ${GREEN}Import existing resources${NC} - Terraform will take over existing Bicep-deployed resources"
    echo "   - Pros: No downtime, preserves existing data"
    echo "   - Cons: Complex import process, potential state conflicts"
    echo ""
    echo "2. ${YELLOW}Destroy and recreate${NC} - Remove existing infrastructure and deploy new with Terraform"
    echo "   - Pros: Clean state, no conflicts, fresh deployment"
    echo "   - Cons: Data loss, downtime, need to restore from backups"
    echo ""
    echo "3. ${BLUE}Hybrid approach${NC} - Import critical resources, recreate others"
    echo "   - Pros: Balance of safety and complexity"
    echo "   - Cons: Requires careful planning and testing"
    echo ""
    
    read -p "Choose migration option (1-3): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}✅ Selected: Import existing resources${NC}"
            MIGRATION_TYPE="import"
            ;;
        2)
            echo -e "${YELLOW}⚠️  Selected: Destroy and recreate${NC}"
            echo -e "${RED}WARNING: This will destroy all existing resources and data!${NC}"
            read -p "Are you sure? Type 'YES' to confirm: " confirm
            if [[ "$confirm" != "YES" ]]; then
                echo -e "${RED}Migration cancelled${NC}"
                exit 1
            fi
            MIGRATION_TYPE="destroy"
            ;;
        3)
            echo -e "${BLUE}✅ Selected: Hybrid approach${NC}"
            MIGRATION_TYPE="hybrid"
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            exit 1
            ;;
    esac
    
    echo ""
}

# Function to execute migration
execute_migration() {
    echo -e "${YELLOW}🚀 Executing migration...${NC}"
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    
    case $MIGRATION_TYPE in
        "import")
            echo -e "${BLUE}📥 Importing existing resources...${NC}"
            
            # Initialize Terraform
            terraform init
            
            # Plan to see what will be imported
            terraform plan -out=tfplan
            
            # Apply the plan
            terraform apply tfplan
            
            echo -e "${GREEN}✅ Import migration completed${NC}"
            ;;
            
        "destroy")
            echo -e "${RED}🗑️  Destroying existing infrastructure...${NC}"
            
            # This would require manual confirmation and careful execution
            echo -e "${YELLOW}⚠️  Manual intervention required for destroy and recreate${NC}"
            echo "Please manually destroy resources using Azure CLI or Portal, then run:"
            echo "terraform init && terraform plan && terraform apply"
            ;;
            
        "hybrid")
            echo -e "${BLUE}🔄 Hybrid migration approach...${NC}"
            
            # Initialize Terraform
            terraform init
            
            # Plan to see what will be imported vs created
            terraform plan -out=tfplan
            
            # Apply the plan
            terraform apply tfplan
            
            echo -e "${GREEN}✅ Hybrid migration completed${NC}"
            ;;
    esac
    
    echo ""
}

# Function to validate migration
validate_migration() {
    echo -e "${YELLOW}✅ Validating migration...${NC}"
    
    cd "$TERRAFORM_DIR/environments/$ENVIRONMENT"
    
    # Check Terraform state
    terraform show
    
    # Validate configuration
    terraform validate
    
    # Check resource health
    echo -e "${BLUE}🔍 Checking resource health...${NC}"
    
    # List resources in Terraform state
    terraform state list
    
    echo -e "${GREEN}✅ Migration validation completed${NC}"
    echo ""
}

# Function to show next steps
show_next_steps() {
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo ""
    
    case $MIGRATION_TYPE in
        "import"|"hybrid")
            echo "1. ${GREEN}Review Terraform state${NC}"
            echo "   - Run: terraform state list"
            echo "   - Run: terraform show"
            echo ""
            echo "2. ${GREEN}Test infrastructure${NC}"
            echo "   - Verify all services are running"
            echo "   - Check connectivity between services"
            echo "   - Validate monitoring and logging"
            echo ""
            echo "3. ${GREEN}Update CI/CD pipelines${NC}"
            echo "   - Replace Bicep deployment with Terraform"
            echo "   - Update GitHub Actions workflows"
            echo "   - Configure Terraform-specific secrets"
            echo ""
            ;;
        "destroy")
            echo "1. ${YELLOW}Restore from backup${NC}"
            echo "   - Restore data from backup: $BACKUP_DIR"
            echo "   - Verify data integrity"
            echo ""
            echo "2. ${GREEN}Deploy with Terraform${NC}"
            echo "   - Run: terraform init && terraform plan && terraform apply"
            echo "   - Configure monitoring and logging"
            echo ""
            ;;
    esac
    
    echo "4. ${BLUE}Document changes${NC}"
    echo "   - Update architecture documentation"
    echo "   - Document Terraform-specific procedures"
    echo "   - Train team on Terraform operations"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting HTMA Platform migration from Bicep to Terraform...${NC}"
    echo ""
    
    check_prerequisites
    analyze_infrastructure
    create_terraform_backend
    backup_resources
    check_terraform_import
    show_migration_options
    execute_migration
    validate_migration
    show_next_steps
    
    echo -e "${GREEN}🎉 Migration process completed!${NC}"
    echo ""
    echo -e "${BLUE}For support and questions, refer to the Terraform documentation and logs.${NC}"
}

# Run main function
main "$@"
