#!/bin/bash

# HT-Management Azure Development Environment Deployment Script
# This script deploys the complete Azure infrastructure for development

set -e  # Exit on any error

# Configuration
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-htma-dev"
LOCATION="eastus"
DEPLOYMENT_NAME="htma-dev-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Azure CLI is installed and logged in
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to prompt for required parameters
get_deployment_parameters() {
    print_status "Gathering deployment parameters..."
    
    # Get current subscription ID
    CURRENT_SUB=$(az account show --query id -o tsv)
    echo "Current subscription: $CURRENT_SUB"
    
    # Prompt for subscription if needed
    read -p "Use current subscription? (y/n): " use_current
    if [[ $use_current != "y" ]]; then
        read -p "Enter subscription ID: " SUBSCRIPTION_ID
        az account set --subscription "$SUBSCRIPTION_ID"
    else
        SUBSCRIPTION_ID=$CURRENT_SUB
    fi
    
    # Prompt for database credentials
    read -p "Enter PostgreSQL admin username: " POSTGRES_ADMIN_LOGIN
    read -s -p "Enter PostgreSQL admin password: " POSTGRES_ADMIN_PASSWORD
    echo
    
    read -p "Enter MongoDB admin username: " MONGO_ADMIN_USERNAME
    read -s -p "Enter MongoDB admin password: " MONGO_ADMIN_PASSWORD
    echo
    
    read -s -p "Enter OpenAI API key: " OPENAI_API_KEY
    echo
    
    print_success "Parameters collected"
}

# Function to create resource group
create_resource_group() {
    print_status "Creating resource group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group $RESOURCE_GROUP already exists"
    else
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags Environment=dev Application=htma ManagedBy=Script
        print_success "Resource group created"
    fi
}

# Function to validate Bicep template
validate_template() {
    print_status "Validating Bicep template..."
    
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file azure/bicep/main.bicep \
        --parameters \
            environment=dev \
            appName=htma \
            location="$LOCATION" \
            postgresAdminLogin="$POSTGRES_ADMIN_LOGIN" \
            postgresAdminPassword="$POSTGRES_ADMIN_PASSWORD" \
            mongoAdminUsername="$MONGO_ADMIN_USERNAME" \
            mongoAdminPassword="$MONGO_ADMIN_PASSWORD" \
            openAiApiKey="$OPENAI_API_KEY"
    
    print_success "Template validation passed"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying Azure infrastructure..."
    print_warning "This may take 15-20 minutes..."
    
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file azure/bicep/main.bicep \
        --name "$DEPLOYMENT_NAME" \
        --parameters \
            environment=dev \
            appName=htma \
            location="$LOCATION" \
            postgresAdminLogin="$POSTGRES_ADMIN_LOGIN" \
            postgresAdminPassword="$POSTGRES_ADMIN_PASSWORD" \
            mongoAdminUsername="$MONGO_ADMIN_USERNAME" \
            mongoAdminPassword="$MONGO_ADMIN_PASSWORD" \
            openAiApiKey="$OPENAI_API_KEY" \
        --verbose
    
    print_success "Infrastructure deployment completed"
}

# Function to get deployment outputs
get_deployment_outputs() {
    print_status "Retrieving deployment outputs..."
    
    # Get outputs from deployment
    OUTPUTS=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs \
        -o json)
    
    # Extract key values
    KEY_VAULT_NAME=$(echo "$OUTPUTS" | jq -r '.keyVaultName.value')
    CONTAINER_APPS_ENV=$(echo "$OUTPUTS" | jq -r '.containerAppsEnvironmentName.value')
    STATIC_WEB_APP=$(echo "$OUTPUTS" | jq -r '.staticWebAppName.value')
    POSTGRES_SERVER=$(echo "$OUTPUTS" | jq -r '.postgresServerName.value')
    COSMOS_ACCOUNT=$(echo "$OUTPUTS" | jq -r '.cosmosAccountName.value')
    
    print_success "Deployment outputs retrieved"
    
    # Display important information
    echo ""
    echo "================================================"
    echo "  Azure Resources Deployed Successfully"
    echo "================================================"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Key Vault: $KEY_VAULT_NAME"
    echo "Container Apps Environment: $CONTAINER_APPS_ENV"
    echo "Static Web App: $STATIC_WEB_APP"
    echo "PostgreSQL Server: $POSTGRES_SERVER"
    echo "Cosmos DB Account: $COSMOS_ACCOUNT"
    echo "================================================"
}

# Function to setup database schema
setup_database_schema() {
    print_status "Setting up database schema..."
    
    # Get PostgreSQL connection details
    POSTGRES_FQDN=$(az postgres flexible-server show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER" \
        --query fullyQualifiedDomainName -o tsv)
    
    print_status "PostgreSQL FQDN: $POSTGRES_FQDN"
    
    # Create .env file for database migration
    cat > .env.azure << EOF
# Azure Development Environment Configuration
POSTGRES_HOST=$POSTGRES_FQDN
POSTGRES_PORT=5432
POSTGRES_DB=htma
POSTGRES_USER=$POSTGRES_ADMIN_LOGIN
POSTGRES_PASSWORD=$POSTGRES_ADMIN_PASSWORD
POSTGRES_SSL=true

AZURE_KEY_VAULT_NAME=$KEY_VAULT_NAME
ENVIRONMENT=development
EOF
    
    print_success "Environment configuration created"
    print_warning "Run database migrations manually using the .env.azure file"
}

# Function to create container images (placeholder)
build_container_images() {
    print_status "Container images need to be built and pushed..."
    print_warning "This step requires Docker and will be implemented in the next phase"
    
    # Get ACR login server
    ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
    
    echo ""
    echo "Next Steps for Container Deployment:"
    echo "1. Build Docker images for each service"
    echo "2. Tag images for ACR: $ACR_LOGIN_SERVER"
    echo "3. Push images to ACR"
    echo "4. Update Container Apps with image references"
    echo ""
    
    # Create build script for later use
    cat > azure/scripts/build-and-push.sh << 'EOF'
#!/bin/bash
# Container build and push script - to be implemented
echo "Building and pushing container images..."
echo "This script will be implemented in the next deployment phase."
EOF
    chmod +x azure/scripts/build-and-push.sh
}

# Function to display next steps
display_next_steps() {
    print_success "Azure development environment deployment completed!"
    
    echo ""
    echo "🎉 Deployment Summary:"
    echo "✅ Resource Group: $RESOURCE_GROUP"
    echo "✅ Infrastructure: Deployed"
    echo "✅ Databases: Provisioned"
    echo "✅ Container Apps Environment: Ready"
    echo "✅ Static Web App: Ready"
    echo "✅ Monitoring: Configured"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Build and push container images"
    echo "2. Run database migrations"
    echo "3. Configure GitHub Actions for CI/CD"
    echo "4. Deploy application code"
    echo "5. Test the deployment"
    echo ""
    echo "📁 Configuration Files Created:"
    echo "• .env.azure - Azure environment configuration"
    echo "• azure/scripts/build-and-push.sh - Container build script"
    echo ""
    echo "🔗 Useful Commands:"
    echo "• View resources: az resource list --resource-group $RESOURCE_GROUP --output table"
    echo "• View Key Vault secrets: az keyvault secret list --vault-name $KEY_VAULT_NAME"
    echo "• View Container Apps: az containerapp list --resource-group $RESOURCE_GROUP --output table"
    echo ""
}

# Main execution
main() {
    echo "================================================"
    echo "  HT-Management Azure Development Deployment"
    echo "================================================"
    echo ""
    
    check_prerequisites
    get_deployment_parameters
    create_resource_group
    validate_template
    deploy_infrastructure
    get_deployment_outputs
    setup_database_schema
    build_container_images
    display_next_steps
    
    print_success "Deployment script completed successfully!"
}

# Run main function
main "$@"
