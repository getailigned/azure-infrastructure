#!/bin/bash

# HTMA Deployment Script Using Existing Key Vault Credentials
# Uses production-grade configuration with existing vault secrets

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

# Configuration
RESOURCE_GROUP="htma-dev-rg"
KEYVAULT_SERVICES="htma-dev-kv"          # Service connections and API keys
KEYVAULT_SECURE="htma-dev-secure-kv"     # Admin passwords and secure credentials
LOCATION="East US 2"
ENVIRONMENT="dev"

echo_info "🚀 Starting HTMA Deployment with Vault Credentials"
echo_info "🔐 Services Key Vault: $KEYVAULT_SERVICES"
echo_info "🔐 Secure Key Vault: $KEYVAULT_SECURE"
echo_info "📦 Resource Group: $RESOURCE_GROUP"
echo ""

# Validate Azure CLI and login
if ! command -v az &> /dev/null; then
    echo_error "Azure CLI not found. Please install Azure CLI."
    exit 1
fi

if ! az account show &> /dev/null; then
    echo_error "Not logged into Azure. Please run 'az login'"
    exit 1
fi

# Check Key Vault access
if ! az keyvault show --name "$KEYVAULT_SERVICES" &> /dev/null; then
    echo_error "Cannot access Services Key Vault '$KEYVAULT_SERVICES'. Check permissions."
    exit 1
fi

if ! az keyvault show --name "$KEYVAULT_SECURE" &> /dev/null; then
    echo_error "Cannot access Secure Key Vault '$KEYVAULT_SECURE'. Check permissions."
    exit 1
fi

echo_success "Azure authentication and both Key Vault access verified"
echo ""

# Retrieve existing secrets from both Key Vaults
echo_info "🔑 Retrieving existing credentials from Key Vaults..."

# Get existing secrets from services vault
OPENAI_API_KEY=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "openai-api-key" --query "value" --output tsv 2>/dev/null || echo "")
POSTGRES_CONNECTION=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "postgres-connection" --query "value" --output tsv 2>/dev/null || echo "")
COSMOS_CONNECTION=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "cosmos-connection" --query "value" --output tsv 2>/dev/null || echo "")
REDIS_CONNECTION=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "redis-connection" --query "value" --output tsv 2>/dev/null || echo "")
SERVICEBUS_CONNECTION=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "servicebus-connection" --query "value" --output tsv 2>/dev/null || echo "")
SEARCH_ADMIN_KEY=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "search-admin-key" --query "value" --output tsv 2>/dev/null || echo "")

# Get existing secrets from secure vault
POSTGRES_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "postgres-admin-password" --query "value" --output tsv 2>/dev/null || echo "")
MONGO_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "mongo-admin-password" --query "value" --output tsv 2>/dev/null || echo "")

if [[ -z "$OPENAI_API_KEY" ]]; then
    echo_error "OpenAI API key not found in Services Key Vault"
    exit 1
fi

if [[ -z "$POSTGRES_ADMIN_PASSWORD" ]]; then
    echo_error "PostgreSQL admin password not found in Secure Key Vault"
    exit 1
fi

echo_success "Retrieved existing credentials from both Key Vaults"
echo ""

# Check for Google Workspace credentials - check both vaults and add if missing
echo_info "🔍 Checking Google Workspace credentials..."

# Check both vaults for Google Workspace credentials
GOOGLE_CLIENT_ID=$(az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "google-client-id" --query "value" --output tsv 2>/dev/null || \
                   az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "google-client-id" --query "value" --output tsv 2>/dev/null || echo "")

GOOGLE_CLIENT_SECRET=$(az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "google-client-secret" --query "value" --output tsv 2>/dev/null || \
                       az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "google-client-secret" --query "value" --output tsv 2>/dev/null || echo "")

GOOGLE_REFRESH_TOKEN=$(az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "google-refresh-token" --query "value" --output tsv 2>/dev/null || \
                       az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "google-refresh-token" --query "value" --output tsv 2>/dev/null || echo "")

NOTIFICATION_FROM_EMAIL=$(az keyvault secret show --vault-name "$KEYVAULT_SERVICES" --name "notification-from-email" --query "value" --output tsv 2>/dev/null || \
                          az keyvault secret show --vault-name "$KEYVAULT_SECURE" --name "notification-from-email" --query "value" --output tsv 2>/dev/null || echo "")

# Add missing Google Workspace secrets to secure vault (for sensitive credentials)
if [[ -z "$GOOGLE_CLIENT_ID" ]]; then
    echo_info "Adding Google Workspace Client ID to Secure Key Vault..."
    read -p "Enter Google Workspace Client ID: " GOOGLE_CLIENT_ID
    az keyvault secret set --vault-name "$KEYVAULT_SECURE" --name "google-client-id" --value "$GOOGLE_CLIENT_ID" --output none
fi

if [[ -z "$GOOGLE_CLIENT_SECRET" ]]; then
    echo_info "Adding Google Workspace Client Secret to Secure Key Vault..."
    read -s -p "Enter Google Workspace Client Secret: " GOOGLE_CLIENT_SECRET
    echo
    az keyvault secret set --vault-name "$KEYVAULT_SECURE" --name "google-client-secret" --value "$GOOGLE_CLIENT_SECRET" --output none
fi

if [[ -z "$GOOGLE_REFRESH_TOKEN" ]]; then
    echo_info "Adding Google Workspace Refresh Token to Secure Key Vault..."
    read -s -p "Enter Google Workspace Refresh Token: " GOOGLE_REFRESH_TOKEN
    echo
    az keyvault secret set --vault-name "$KEYVAULT_SECURE" --name "google-refresh-token" --value "$GOOGLE_REFRESH_TOKEN" --output none
fi

if [[ -z "$NOTIFICATION_FROM_EMAIL" ]]; then
    echo_info "Adding notification sender email to Services Key Vault..."
    read -p "Enter notification sender email: " NOTIFICATION_FROM_EMAIL
    az keyvault secret set --vault-name "$KEYVAULT_SERVICES" --name "notification-from-email" --value "$NOTIFICATION_FROM_EMAIL" --output none
fi

echo_success "Google Workspace credentials configured in Key Vaults"
echo ""

# Update parameters file to use the correct Key Vaults
echo_info "📋 Updating parameters file with correct Key Vault references..."

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
KEYVAULT_SERVICES_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-htma-dev/providers/Microsoft.KeyVault/vaults/$KEYVAULT_SERVICES"
KEYVAULT_SECURE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-htma-dev/providers/Microsoft.KeyVault/vaults/$KEYVAULT_SECURE"

cat > azure/parameters-vault-deployment.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceNamePrefix": {
      "value": "htma-dev"
    },
    "environment": {
      "value": "dev"
    },
    "postgresAdminLogin": {
      "value": "htma_admin"
    },
    "postgresAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SECURE_ID"
        },
        "secretName": "postgres-admin-password"
      }
    },
    "mongoAdminUsername": {
      "value": "htma_admin"
    },
    "mongoAdminPassword": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SECURE_ID"
        },
        "secretName": "mongo-admin-password"
      }
    },
    "openAiApiKey": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SERVICES_ID"
        },
        "secretName": "openai-api-key"
      }
    },
    "googleClientId": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SECURE_ID"
        },
        "secretName": "google-client-id"
      }
    },
    "googleClientSecret": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SECURE_ID"
        },
        "secretName": "google-client-secret"
      }
    },
    "googleRefreshToken": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SECURE_ID"
        },
        "secretName": "google-refresh-token"
      }
    },
    "notificationFromEmail": {
      "reference": {
        "keyVault": {
          "id": "$KEYVAULT_SERVICES_ID"
        },
        "secretName": "notification-from-email"
      }
    },
    "notificationFromName": {
      "value": "HTMA Platform"
    }
  }
}
EOF

echo_success "Parameters file created with Key Vault references"
echo ""

# Deploy the infrastructure
echo_info "🏗️  Deploying HTMA infrastructure with notification services..."

DEPLOYMENT_NAME="htma-notification-vault-$(date +%Y%m%d-%H%M%S)"

echo_info "Deployment name: $DEPLOYMENT_NAME"
echo_info "Using Services Key Vault: $KEYVAULT_SERVICES"
echo_info "Using Secure Key Vault: $KEYVAULT_SECURE"

# Deploy using the vault-based parameters
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "azure/bicep/main.bicep" \
    --parameters "@azure/parameters-vault-deployment.json" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

DEPLOYMENT_STATUS=$?

if [[ $DEPLOYMENT_STATUS -eq 0 ]]; then
    echo_success "🎉 Deployment completed successfully!"
    
    # Get deployment outputs
    echo_info "📊 Deployment outputs:"
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output table
        
    echo ""
    echo_info "🔗 Key Resources Deployed:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Services Key Vault: $KEYVAULT_SERVICES"
    echo "  Secure Key Vault: $KEYVAULT_SECURE"
    echo "  Deployment: $DEPLOYMENT_NAME"
    echo ""
    echo_info "📋 Next Steps:"
    echo "  1. Build and push notification service container image"
    echo "  2. Update container app with new image"
    echo "  3. Test notification service endpoints"
    echo "  4. Configure Google Workspace OAuth2 flow"
    
else
    echo_error "Deployment failed!"
    
    # Show deployment errors
    az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.error" \
        --output json
    
    exit 1
fi
