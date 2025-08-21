#!/bin/bash

# HTMA Notification Service Azure Deployment Script
# Deploys Google Workspace SMTP integration to Azure Container Apps

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
SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID:-""}
RESOURCE_GROUP="htma-dev-rg"
LOCATION="East US 2"
ENVIRONMENT="dev"
DEPLOYMENT_NAME="htma-notification-$(date +%Y%m%d%H%M%S)"

# Function to check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        echo_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    echo_success "All prerequisites satisfied"
}

# Function to set Azure subscription
set_subscription() {
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        echo_info "Available subscriptions:"
        az account list --query "[].{Name:name, SubscriptionId:id}" --output table
        echo ""
        read -p "Enter your Azure subscription ID: " SUBSCRIPTION_ID
    fi
    
    echo_info "Setting Azure subscription to: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
    echo_success "Subscription set successfully"
}

# Function to validate Google Workspace configuration
validate_google_workspace() {
    echo_info "Validating Google Workspace configuration..."
    
    local missing_vars=()
    
    if [[ -z "$GOOGLE_CLIENT_ID" ]]; then
        missing_vars+=("GOOGLE_CLIENT_ID")
    fi
    
    if [[ -z "$GOOGLE_CLIENT_SECRET" ]]; then
        missing_vars+=("GOOGLE_CLIENT_SECRET")
    fi
    
    if [[ -z "$GOOGLE_REFRESH_TOKEN" ]]; then
        missing_vars+=("GOOGLE_REFRESH_TOKEN")
    fi
    
    if [[ -z "$NOTIFICATION_FROM_EMAIL" ]]; then
        missing_vars+=("NOTIFICATION_FROM_EMAIL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo_error "Missing required Google Workspace environment variables:"
        printf '  - %s\n' "${missing_vars[@]}"
        echo ""
        echo_info "Please set these environment variables or run the Google OAuth setup:"
        echo "  cd services/notification-service && node scripts/setup-google-oauth.js"
        exit 1
    fi
    
    echo_success "Google Workspace configuration validated"
}

# Function to store secrets in Key Vault
store_secrets() {
    echo_info "Storing Google Workspace secrets in Azure Key Vault..."
    
    local key_vault_name="htma-${ENVIRONMENT}-kv"
    
    # Check if Key Vault exists
    if ! az keyvault show --name "$key_vault_name" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        echo_error "Key Vault '$key_vault_name' not found. Please deploy the main infrastructure first."
        exit 1
    fi
    
    # Store Google Workspace secrets
    echo_info "Storing Google Client ID..."
    az keyvault secret set \
        --vault-name "$key_vault_name" \
        --name "google-client-id" \
        --value "$GOOGLE_CLIENT_ID" \
        --description "Google Workspace OAuth2 Client ID" \
        --output none
    
    echo_info "Storing Google Client Secret..."
    az keyvault secret set \
        --vault-name "$key_vault_name" \
        --name "google-client-secret" \
        --value "$GOOGLE_CLIENT_SECRET" \
        --description "Google Workspace OAuth2 Client Secret" \
        --output none
    
    echo_info "Storing Google Refresh Token..."
    az keyvault secret set \
        --vault-name "$key_vault_name" \
        --name "google-refresh-token" \
        --value "$GOOGLE_REFRESH_TOKEN" \
        --description "Google Workspace OAuth2 Refresh Token" \
        --output none
    
    echo_success "Secrets stored in Key Vault successfully"
}

# Function to build and push container image
build_and_push_image() {
    echo_info "Building and pushing notification service container image..."
    
    local registry_name="htmaregistry"
    local image_name="htma/notification-service"
    local image_tag="latest"
    
    # Login to Azure Container Registry
    echo_info "Logging in to Azure Container Registry..."
    az acr login --name "$registry_name"
    
    # Build the image
    echo_info "Building Docker image..."
    cd services/notification-service
    docker build -t "${registry_name}.azurecr.io/${image_name}:${image_tag}" .
    
    # Push the image
    echo_info "Pushing Docker image to registry..."
    docker push "${registry_name}.azurecr.io/${image_name}:${image_tag}"
    
    cd ../..
    echo_success "Container image built and pushed successfully"
}

# Function to validate Bicep templates
validate_templates() {
    echo_info "Validating Bicep templates..."
    
    # Validate notification services module
    echo_info "Validating notification services module..."
    az bicep build --file azure/bicep/modules/notification-services.bicep
    
    # Validate main template
    echo_info "Validating main template..."
    az bicep build --file azure/bicep/main.bicep
    
    # Validate deployment
    echo_info "Validating deployment..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file azure/bicep/main.bicep \
        --parameters azure/parameters-notification.dev.json \
        --parameters notificationFromEmail="$NOTIFICATION_FROM_EMAIL" \
        --output none
    
    echo_success "Bicep templates validated successfully"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo_info "Deploying notification service infrastructure..."
    
    # Run the deployment
    echo_info "Starting Azure deployment: $DEPLOYMENT_NAME"
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --template-file azure/bicep/main.bicep \
        --parameters azure/parameters-notification.dev.json \
        --parameters notificationFromEmail="$NOTIFICATION_FROM_EMAIL" \
        --parameters notificationFromName="${NOTIFICATION_FROM_NAME:-HTMA Platform}" \
        --verbose
    
    echo_success "Infrastructure deployment completed"
}

# Function to test deployment
test_deployment() {
    echo_info "Testing notification service deployment..."
    
    # Get the notification service URL
    local notification_url=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs.notificationServiceUrl.value" \
        --output tsv)
    
    if [[ -z "$notification_url" ]]; then
        echo_warning "Could not retrieve notification service URL"
        return
    fi
    
    echo_info "Notification service URL: $notification_url"
    
    # Test health endpoint
    echo_info "Testing health endpoint..."
    if curl -f "${notification_url}/health" &> /dev/null; then
        echo_success "Health endpoint is responding"
    else
        echo_warning "Health endpoint is not responding yet (this is normal for new deployments)"
    fi
    
    # Test API endpoints (requires authentication)
    echo_info "API endpoints available at: ${notification_url}/api"
    echo_info "  - POST /api/notifications/send"
    echo_info "  - GET /api/preferences/:userId"
    echo_info "  - GET /api/metrics"
}

# Function to display deployment summary
show_summary() {
    echo ""
    echo_success "🎉 Notification Service Azure Integration Complete!"
    echo ""
    echo_info "📋 Deployment Summary:"
    
    # Get deployment outputs
    local outputs=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output json 2>/dev/null || echo "{}")
    
    if [[ "$outputs" != "{}" ]]; then
        echo "  Resource Group: $RESOURCE_GROUP"
        echo "  Environment: $ENVIRONMENT"
        echo "  Deployment: $DEPLOYMENT_NAME"
        echo ""
        
        # Extract key URLs
        local notification_url=$(echo "$outputs" | jq -r '.notificationServiceUrl.value // "N/A"')
        local communication_service=$(echo "$outputs" | jq -r '.communicationServiceName.value // "N/A"')
        local storage_account=$(echo "$outputs" | jq -r '.notificationStorageAccountName.value // "N/A"')
        
        echo_info "🔗 Service URLs:"
        echo "  Notification Service: $notification_url"
        echo ""
        
        echo_info "📧 Email Services:"
        echo "  Azure Communication Service: $communication_service"
        echo "  Storage Account: $storage_account"
        echo "  Google Workspace: Configured"
        echo ""
    fi
    
    echo_info "📚 Next Steps:"
    echo "  1. Test email sending via API endpoints"
    echo "  2. Configure notification templates and preferences"
    echo "  3. Integrate with workflow events and escalations"
    echo "  4. Monitor email delivery and performance metrics"
    echo ""
    echo_info "📖 Documentation: azure/NOTIFICATION_SERVICE_AZURE_INTEGRATION.md"
}

# Function to generate documentation
generate_documentation() {
    echo_info "Generating Azure integration documentation..."
    
    cat > azure/NOTIFICATION_SERVICE_AZURE_INTEGRATION.md << 'EOF'
# HTMA Notification Service Azure Integration

## Overview
The HTMA Notification Service is deployed on Azure Container Apps with Google Workspace SMTP integration, providing enterprise-grade email notifications for workflow automation.

## Architecture

### Azure Services
- **Azure Container Apps**: Hosting the notification service
- **Azure Communication Services**: Backup email delivery
- **Azure Event Grid**: Event-driven notification triggers
- **Azure Storage Account**: Email templates and attachments
- **Azure Key Vault**: Secure secret management
- **Azure Application Insights**: Monitoring and analytics

### Google Workspace Integration
- **Gmail SMTP**: Primary email delivery via OAuth2
- **Gmail API**: Advanced email features and tracking
- **Google Cloud Console**: OAuth2 credential management

## Deployment

### Prerequisites
1. Azure subscription with appropriate permissions
2. Google Workspace account with admin access
3. Google Cloud Project with Gmail API enabled
4. Docker for building container images

### Environment Variables
```bash
# Required for deployment
export GOOGLE_CLIENT_ID="your-google-client-id"
export GOOGLE_CLIENT_SECRET="your-google-client-secret"
export GOOGLE_REFRESH_TOKEN="your-google-refresh-token"
export NOTIFICATION_FROM_EMAIL="notifications@yourcompany.com"
export NOTIFICATION_FROM_NAME="HTMA Platform"
export AZURE_SUBSCRIPTION_ID="your-azure-subscription-id"
```

### Deployment Commands
```bash
# Deploy notification service to Azure
./azure/scripts/deploy-notification-integration.sh

# Or deploy manually
az deployment group create \
  --resource-group htma-dev-rg \
  --template-file azure/bicep/main.bicep \
  --parameters azure/parameters-notification.dev.json
```

## Configuration

### Google Workspace Setup
1. Create Google Cloud Project
2. Enable Gmail API
3. Create OAuth2 credentials
4. Run setup wizard: `cd services/notification-service && node scripts/setup-google-oauth.js`

### Azure Configuration
- Secrets stored in Azure Key Vault
- Service runs on Azure Container Apps
- Monitoring via Application Insights
- Private networking with VNet integration

## API Endpoints

### Send Notification
```bash
POST https://htma-dev-notification.azurecontainerapps.io/api/notifications/send
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "tenantId": "tenant-123",
  "recipientId": "user-456",
  "type": "work_item_assigned",
  "templateId": "work_item_assigned",
  "data": {
    "workItemTitle": "Design User Interface",
    "assigneeName": "John Doe"
  }
}
```

### User Preferences
```bash
GET https://htma-dev-notification.azurecontainerapps.io/api/preferences/user-123
PUT https://htma-dev-notification.azurecontainerapps.io/api/preferences/user-123
```

### Metrics and Analytics
```bash
GET https://htma-dev-notification.azurecontainerapps.io/api/metrics?tenantId=tenant-123
```

## Monitoring

### Application Insights
- Service health and performance metrics
- Email delivery success/failure rates
- API request tracking and errors
- Custom telemetry for business metrics

### Key Metrics
- Email delivery rate (target: >99%)
- Response time (target: <200ms)
- Error rate (target: <1%)
- Google Workspace quota usage

## Security

### Authentication
- JWT-based API authentication
- Azure AD integration for service identity
- Role-based access control (RBAC)

### Secrets Management
- Google credentials stored in Azure Key Vault
- Automatic secret rotation support
- Network isolation with private endpoints

### Compliance
- Email tracking and audit logging
- GDPR-compliant unsubscribe handling
- Data residency in specified regions

## Troubleshooting

### Common Issues

1. **Email Not Sending**
   - Check Google Workspace quotas and permissions
   - Verify OAuth2 token validity
   - Review Application Insights logs

2. **Service Unavailable**
   - Check Container Apps scaling and health
   - Verify network connectivity
   - Review resource limits and quotas

3. **Authentication Errors**
   - Validate JWT tokens and expiration
   - Check Azure AD configuration
   - Verify service principal permissions

### Logs and Diagnostics
```bash
# View service logs
az containerapp logs show \
  --name htma-dev-notification \
  --resource-group htma-dev-rg

# Check Application Insights
az monitor app-insights query \
  --app htma-dev-notification-insights \
  --analytics-query "requests | where timestamp > ago(1h)"
```

## Scaling and Performance

### Auto-scaling
- CPU-based scaling (target: 70% utilization)
- Memory-based scaling (target: 80% utilization)
- HTTP request-based scaling (max 30 concurrent)

### Performance Optimization
- Connection pooling for database and SMTP
- Template caching for faster rendering
- Batch processing for bulk emails
- Rate limiting to respect API quotas

## Cost Optimization

### Azure Costs
- Container Apps: Pay-per-use model
- Communication Services: Free tier available
- Storage: Minimal costs for templates
- Key Vault: Low-cost secret management

### Google Workspace
- Gmail API: Free tier up to quota limits
- SMTP: No additional costs for Workspace accounts
- Monitoring via Google Cloud Console

## Maintenance

### Regular Tasks
- Monitor email delivery metrics
- Review and rotate OAuth2 tokens
- Update container images for security patches
- Analyze usage patterns and costs

### Updates and Upgrades
- Blue-green deployments for zero downtime
- Automated testing before production
- Configuration drift detection
- Backup and disaster recovery procedures

EOF

    echo_success "Documentation generated: azure/NOTIFICATION_SERVICE_AZURE_INTEGRATION.md"
}

# Main execution
main() {
    echo_info "🚀 Starting HTMA Notification Service Azure Deployment"
    echo ""
    
    check_prerequisites
    set_subscription
    validate_google_workspace
    store_secrets
    build_and_push_image
    validate_templates
    deploy_infrastructure
    test_deployment
    generate_documentation
    show_summary
    
    echo ""
    echo_success "🎉 Deployment completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
