#!/bin/bash

# HTMA Production-Grade Deployment Script
# Deploys development environment with production-grade configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo_info "🚀 Starting HTMA Production-Grade Deployment"
echo_info "📁 Project Root: $PROJECT_ROOT"
echo ""

# Load environment variables
if [[ -f "$PROJECT_ROOT/azure/setup-deployment-env.sh" ]]; then
    echo_info "📋 Loading environment configuration..."
    source "$PROJECT_ROOT/azure/setup-deployment-env.sh"
else
    echo_error "Environment setup script not found!"
    exit 1
fi

echo ""
echo_info "🔍 Pre-deployment validation..."

# Validate Azure CLI
if ! command -v az &> /dev/null; then
    echo_error "Azure CLI not found. Please install Azure CLI."
    exit 1
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo_error "Not logged into Azure. Please run 'az login'"
    exit 1
fi

# Validate resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo_error "Resource group '$RESOURCE_GROUP' not found!"
    exit 1
fi

echo_success "Pre-deployment validation completed"
echo ""

# Step 1: Deploy Key Vault first (if not exists)
echo_info "🔐 Step 1: Setting up Key Vault and secrets..."

KEYVAULT_NAME="htma-dev-kv"

# Check if Key Vault exists
if ! az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo_info "Creating Key Vault: $KEYVAULT_NAME"
    
    # Deploy minimal Key Vault first
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "$PROJECT_ROOT/azure/bicep/modules/keyvault.bicep" \
        --parameters \
            keyVaultName="$KEYVAULT_NAME" \
            location="$LOCATION" \
            environment="$ENVIRONMENT" \
            tenantId="$(az account show --query tenantId --output tsv)" \
        --verbose
    
    echo_success "Key Vault created successfully"
else
    echo_info "Key Vault already exists: $KEYVAULT_NAME"
fi

# Step 2: Store secrets in Key Vault
echo_info "🔑 Step 2: Storing secrets in Key Vault..."

# Store database credentials
echo_info "Storing database credentials..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "postgres-admin-login" --value "$POSTGRES_ADMIN_LOGIN" --output none
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "postgres-admin-password" --value "$POSTGRES_ADMIN_PASSWORD" --output none
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "mongo-admin-username" --value "$MONGO_ADMIN_USERNAME" --output none
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "mongo-admin-password" --value "$MONGO_ADMIN_PASSWORD" --output none

# Store OpenAI API key
echo_info "Storing OpenAI API key..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "openai-api-key" --value "$OPENAI_API_KEY" --output none

# Store Google Workspace credentials
echo_info "Storing Google Workspace credentials..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "google-client-id" --value "$GOOGLE_CLIENT_ID" --output none
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "google-client-secret" --value "$GOOGLE_CLIENT_SECRET" --output none
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "google-refresh-token" --value "$GOOGLE_REFRESH_TOKEN" --output none

# Store notification configuration
echo_info "Storing notification configuration..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "notification-from-email" --value "$NOTIFICATION_FROM_EMAIL" --output none

echo_success "All secrets stored in Key Vault"
echo ""

# Step 3: Deploy main infrastructure
echo_info "🏗️  Step 3: Deploying main infrastructure..."

DEPLOYMENT_NAME="htma-notification-$(date +%Y%m%d-%H%M%S)"

echo_info "Deployment name: $DEPLOYMENT_NAME"
echo_info "Using parameters file: parameters-notification.prod-grade.json"

# Deploy using the production-grade parameters file
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$PROJECT_ROOT/azure/bicep/main.bicep" \
    --parameters "$PROJECT_ROOT/azure/parameters-notification.prod-grade.json" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

echo_success "Main infrastructure deployment completed"
echo ""

# Step 4: Validate deployment
echo_info "🔍 Step 4: Validating deployment..."

# Check deployment status
DEPLOYMENT_STATUS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.provisioningState" \
    --output tsv)

if [[ "$DEPLOYMENT_STATUS" == "Succeeded" ]]; then
    echo_success "Deployment validation successful"
    
    # Get deployment outputs
    echo_info "📊 Deployment outputs:"
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output table
        
else
    echo_error "Deployment failed with status: $DEPLOYMENT_STATUS"
    
    # Show deployment errors
    echo_info "Deployment errors:"
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.error" \
        --output json
    
    exit 1
fi

echo ""
echo_success "🎉 HTMA Production-Grade Deployment Completed Successfully!"
echo ""
echo_info "📋 Next Steps:"
echo "  1. Build and push container images"
echo "  2. Update container app revisions"
echo "  3. Configure DNS and SSL certificates"
echo "  4. Run integration tests"
echo ""
echo_info "🔗 Key Resources:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Key Vault: $KEYVAULT_NAME"
echo "  Deployment: $DEPLOYMENT_NAME"
echo ""
