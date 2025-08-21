#!/bin/bash

# Deploy Phase 5-6 Enhanced HTMA Infrastructure
# Real-time Services (WebSocket, Redis, Service Bus) and AI Services (OpenAI, Search)

set -e

# Configuration
ENVIRONMENT=${ENVIRONMENT:-dev}
RESOURCE_GROUP="htma-${ENVIRONMENT}-rg"
LOCATION=${LOCATION:-eastus2}
DEPLOYMENT_NAME="htma-phase5-6-$(date +%Y%m%d-%H%M%S)"

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

# Function to check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        echo_error "Please log in to Azure CLI first: az login"
        exit 1
    fi
    
    # Check OpenAI API key
    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo_error "OPENAI_API_KEY environment variable is required"
        echo_info "Please set it with: export OPENAI_API_KEY='your-key-here'"
        exit 1
    fi
    
    # Check if bicep is available
    if ! az bicep version &> /dev/null; then
        echo_warning "Bicep CLI not found. Installing..."
        az bicep install
    fi
    
    echo_success "All prerequisites satisfied"
}

# Function to create resource group
create_resource_group() {
    echo_info "Creating/updating resource group: $RESOURCE_GROUP in $LOCATION"
    
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags Environment="$ENVIRONMENT" Application="htma" ManagedBy="Bicep-Phase5-6"
    
    echo_success "Resource group ready"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo_info "Starting Phase 5-6 infrastructure deployment..."
    echo_info "Deployment name: $DEPLOYMENT_NAME"
    
    local postgres_admin_login="htmaadmin"
    local postgres_admin_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local mongo_admin_username="htmaadmin"
    local mongo_admin_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    echo_info "Generated secure passwords for database services"
    
    # Deploy main template
    local deployment_output
    deployment_output=$(az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "../bicep/main.bicep" \
        --name "$DEPLOYMENT_NAME" \
        --parameters \
            environment="$ENVIRONMENT" \
            appName="htma" \
            location="$LOCATION" \
            postgresAdminLogin="$postgres_admin_login" \
            postgresAdminPassword="$postgres_admin_password" \
            mongoAdminUsername="$mongo_admin_username" \
            mongoAdminPassword="$mongo_admin_password" \
            openAiApiKey="$OPENAI_API_KEY" \
        --output json)
    
    if [[ $? -eq 0 ]]; then
        echo_success "Infrastructure deployment completed successfully"
        
        # Extract key outputs
        local key_vault_name=$(echo "$deployment_output" | jq -r '.properties.outputs.keyVaultName.value')
        local websocket_url=$(echo "$deployment_output" | jq -r '.properties.outputs.websocketServiceUrl.value')
        local search_url=$(echo "$deployment_output" | jq -r '.properties.outputs.searchServiceUrl.value')
        local hta_builder_url=$(echo "$deployment_output" | jq -r '.properties.outputs.htaBuilderServiceUrl.value')
        local static_web_app=$(echo "$deployment_output" | jq -r '.properties.outputs.staticWebAppName.value')
        
        echo_info "📋 Deployment Summary:"
        echo "  🔐 Key Vault: $key_vault_name"
        echo "  🔌 WebSocket Service: $websocket_url"
        echo "  🔍 Search Service: $search_url"
        echo "  🤖 HTA Builder Service: $hta_builder_url"
        echo "  🌐 Static Web App: $static_web_app"
        
        # Save deployment info
        cat > "../deployment-info-phase5-6.json" << EOF
{
  "deploymentName": "$DEPLOYMENT_NAME",
  "environment": "$ENVIRONMENT",
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "services": {
    "keyVault": "$key_vault_name",
    "websocketService": "$websocket_url",
    "searchService": "$search_url",
    "htaBuilderService": "$hta_builder_url",
    "staticWebApp": "$static_web_app"
  },
  "credentials": {
    "postgresAdminLogin": "$postgres_admin_login",
    "mongoAdminUsername": "$mongo_admin_username"
  }
}
EOF
        
        echo_success "Deployment information saved to deployment-info-phase5-6.json"
        
    else
        echo_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    echo_info "Verifying Phase 5-6 deployment..."
    
    local deployment_info="../deployment-info-phase5-6.json"
    if [[ ! -f "$deployment_info" ]]; then
        echo_error "Deployment info file not found"
        return 1
    fi
    
    local websocket_url=$(jq -r '.services.websocketService' "$deployment_info")
    local search_url=$(jq -r '.services.searchService' "$deployment_info")
    local hta_builder_url=$(jq -r '.services.htaBuilderService' "$deployment_info")
    
    echo_info "Testing service endpoints..."
    
    # Test WebSocket Service health
    if curl -sf "${websocket_url}/health" > /dev/null; then
        echo_success "WebSocket Service is healthy"
    else
        echo_warning "WebSocket Service health check failed (may still be starting up)"
    fi
    
    # Test Search Service health
    if curl -sf "${search_url}/health" > /dev/null; then
        echo_success "Search Service is healthy"
    else
        echo_warning "Search Service health check failed (may still be starting up)"
    fi
    
    # Test HTA Builder Service health
    if curl -sf "${hta_builder_url}/health" > /dev/null; then
        echo_success "HTA Builder Service is healthy"
    else
        echo_warning "HTA Builder Service health check failed (may still be starting up)"
    fi
    
    echo_success "Deployment verification completed"
}

# Function to setup container registry
setup_container_registry() {
    echo_info "Setting up Azure Container Registry for Phase 5-6 services..."
    
    local acr_name="htma${ENVIRONMENT}registry"
    
    # Check if ACR exists
    if az acr show --name "$acr_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo_info "Container Registry already exists: $acr_name"
    else
        echo_info "Creating Container Registry: $acr_name"
        az acr create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$acr_name" \
            --sku Basic \
            --admin-enabled true
    fi
    
    # Get ACR credentials
    local acr_server=$(az acr show --name "$acr_name" --resource-group "$RESOURCE_GROUP" --query "loginServer" --output tsv)
    local acr_username=$(az acr credential show --name "$acr_name" --query "username" --output tsv)
    local acr_password=$(az acr credential show --name "$acr_name" --query "passwords[0].value" --output tsv)
    
    echo_success "Container Registry ready: $acr_server"
    
    # Login to ACR
    echo "$acr_password" | docker login "$acr_server" --username "$acr_username" --password-stdin
    
    echo_info "📦 Container Registry Information:"
    echo "  Server: $acr_server"
    echo "  Username: $acr_username"
    echo "  Use 'docker push $acr_server/htma/service-name:tag' to push images"
}

# Function to build and push container images
build_and_push_images() {
    echo_info "Building and pushing Phase 5-6 service containers..."
    
    local deployment_info="../deployment-info-phase5-6.json"
    local acr_name="htma${ENVIRONMENT}registry"
    local acr_server=$(az acr show --name "$acr_name" --resource-group "$RESOURCE_GROUP" --query "loginServer" --output tsv)
    
    cd "../../"  # Go to project root
    
    # Build WebSocket Service
    echo_info "Building WebSocket Service..."
    docker build -t "$acr_server/htma/websocket-service:latest" -f services/websocket-service/Dockerfile services/websocket-service/
    docker push "$acr_server/htma/websocket-service:latest"
    
    # Build Search Service
    echo_info "Building Search Service..."
    docker build -t "$acr_server/htma/search-service:latest" -f services/search-service/Dockerfile services/search-service/
    docker push "$acr_server/htma/search-service:latest"
    
    # Build HTA Builder Service
    echo_info "Building HTA Builder Service..."
    docker build -t "$acr_server/htma/hta-builder-service:latest" -f services/hta-builder-service/Dockerfile services/hta-builder-service/
    docker push "$acr_server/htma/hta-builder-service:latest"
    
    cd "azure/scripts/"  # Return to scripts directory
    
    echo_success "All Phase 5-6 service images built and pushed"
}

# Function to setup monitoring and alerts
setup_monitoring() {
    echo_info "Setting up enhanced monitoring for Phase 5-6 services..."
    
    local deployment_info="../deployment-info-phase5-6.json"
    local app_insights_name=$(jq -r '.services.appInsights // "htma-'${ENVIRONMENT}'-ai"' "$deployment_info")
    
    # Create action group for alerts
    az monitor action-group create \
        --resource-group "$RESOURCE_GROUP" \
        --name "htma-${ENVIRONMENT}-phase5-6-alerts" \
        --short-name "HTMA56Alerts" \
        --email-receivers \
            name="Admin" \
            email-address="${ADMIN_EMAIL:-admin@example.com}" \
            use-common-alert-schema true
    
    # Create alerts for critical services
    echo_info "Creating alerts for Phase 5-6 services..."
    
    # OpenAI API rate limit alert
    az monitor metrics alert create \
        --resource-group "$RESOURCE_GROUP" \
        --name "OpenAI-RateLimit-Alert" \
        --description "Alert when OpenAI API rate limit is approaching" \
        --severity 2 \
        --window-size 5m \
        --evaluation-frequency 1m \
        --action "htma-${ENVIRONMENT}-phase5-6-alerts" \
        --condition "avg 'Processed Prompt Tokens' > 80000" || true
    
    echo_success "Enhanced monitoring configured"
}

# Function to create development configuration
create_dev_config() {
    echo_info "Creating development configuration for Phase 5-6..."
    
    local deployment_info="../deployment-info-phase5-6.json"
    
    cat > "../phase5-6-dev.env" << EOF
# Phase 5-6 Development Configuration
# Generated: $(date)

# Environment
ENVIRONMENT=$ENVIRONMENT

# Service URLs
WEBSOCKET_SERVICE_URL=$(jq -r '.services.websocketService' "$deployment_info")
SEARCH_SERVICE_URL=$(jq -r '.services.searchService' "$deployment_info")
HTA_BUILDER_SERVICE_URL=$(jq -r '.services.htaBuilderService' "$deployment_info")

# Azure Resources
RESOURCE_GROUP=$RESOURCE_GROUP
KEY_VAULT_NAME=$(jq -r '.services.keyVault' "$deployment_info")
STATIC_WEB_APP_NAME=$(jq -r '.services.staticWebApp' "$deployment_info")

# OpenAI Configuration
OPENAI_API_KEY=$OPENAI_API_KEY
PRIMARY_AI_MODEL=gpt-4o-mini
FALLBACK_AI_MODEL=gpt-35-turbo

# Development Notes
# - Use 'source azure/phase5-6-dev.env' to load these variables
# - Services are deployed to Azure Container Apps
# - Check service health at {SERVICE_URL}/health
# - View logs in Azure Portal > Container Apps > Log stream
EOF
    
    echo_success "Development configuration saved to phase5-6-dev.env"
}

# Main execution
main() {
    echo_info "🚀 Starting HTMA Phase 5-6 Deployment"
    echo_info "Environment: $ENVIRONMENT"
    echo_info "Resource Group: $RESOURCE_GROUP"
    echo_info "Location: $LOCATION"
    echo ""
    
    check_prerequisites
    create_resource_group
    setup_container_registry
    build_and_push_images
    deploy_infrastructure
    setup_monitoring
    verify_deployment
    create_dev_config
    
    echo ""
    echo_success "🎉 Phase 5-6 deployment completed successfully!"
    echo_info "📚 Next steps:"
    echo "  1. Review deployment-info-phase5-6.json for service details"
    echo "  2. Load environment with: source azure/phase5-6-dev.env"
    echo "  3. Test services using the provided URLs"
    echo "  4. Check Azure Portal for monitoring and logs"
    echo "  5. Configure frontend to use new service endpoints"
    echo ""
    echo_info "🔗 Key Resources:"
    echo "  • Azure Portal: https://portal.azure.com"
    echo "  • Resource Group: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP"
    echo "  • Container Apps: Search for 'htma-$ENVIRONMENT-env' in the portal"
}

# Run main function
main "$@"
