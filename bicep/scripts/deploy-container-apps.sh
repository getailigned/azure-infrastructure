#!/bin/bash

# Deploy Container Apps with Azure-integrated images
# This script updates Container Apps to use the latest images from ACR

set -e

# Configuration
RESOURCE_GROUP="rg-htma-dev"
ACR_SERVER="htmadevacr3898.azurecr.io"
IMAGE_TAG="latest"
ENVIRONMENT_NAME="htma-dev-container-env"

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to update a container app
update_container_app() {
    local app_name=$1
    local service_name=$2
    local port=$3
    local image_url="$ACR_SERVER/htma/$service_name:$IMAGE_TAG"
    
    print_status "Updating $app_name with image $image_url..."
    
    # Update the container app
    az containerapp update \
        --name $app_name \
        --resource-group $RESOURCE_GROUP \
        --image $image_url \
        --set-env-vars \
            NODE_ENV=development \
            AZURE_KEY_VAULT_URI=https://htma-dev-kv.vault.azure.net/ \
            AZURE_SERVICE_BUS_NAMESPACE=htma-dev-servicebus \
            AZURE_REDIS_HOST=htma-dev-redis.redis.cache.windows.net \
            AZURE_REDIS_PORT=6380 \
            AZURE_SEARCH_ENDPOINT=https://htma-dev-search.search.windows.net \
            AZURE_OPENAI_ENDPOINT=https://htma-dev-openai.openai.azure.com/ \
            AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini \
            PORT=$port
    
    if [ $? -eq 0 ]; then
        print_success "$app_name updated successfully"
    else
        print_error "Failed to update $app_name"
        return 1
    fi
}

# Function to check app status
check_app_status() {
    local app_name=$1
    
    print_status "Checking status of $app_name..."
    
    az containerapp show \
        --name $app_name \
        --resource-group $RESOURCE_GROUP \
        --query '{name:name, fqdn:properties.configuration.ingress.fqdn, provisioningState:properties.provisioningState, runningState:properties.runningStatus}' \
        --output table
}

# Function to get app logs
get_app_logs() {
    local app_name=$1
    
    print_status "Getting recent logs for $app_name..."
    
    az containerapp logs show \
        --name $app_name \
        --resource-group $RESOURCE_GROUP \
        --tail 20
}

# Main execution
main() {
    echo "================================================"
    echo "  Deploy HT-Management to Azure Container Apps"
    echo "================================================"
    echo ""
    
    print_status "Checking Azure login..."
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_status "Updating Container Apps with latest images..."
    
    # Update each container app
    update_container_app "htma-work-item-service" "work-item-service" "3001"
    update_container_app "htma-dependency-service" "dependency-service" "3002"
    update_container_app "htma-ai-insights-service" "ai-insights-service" "3003"
    update_container_app "htma-express-gateway" "express-gateway" "3000"
    
    print_success "All Container Apps updated!"
    
    echo ""
    print_status "Checking application status..."
    
    check_app_status "htma-work-item-service"
    check_app_status "htma-dependency-service"
    check_app_status "htma-ai-insights-service"
    check_app_status "htma-express-gateway"
    
    echo ""
    print_success "Deployment completed!"
    
    echo ""
    echo "🎉 Deployment Summary:"
    echo "✅ Work Item Service updated"
    echo "✅ Dependency Service updated"
    echo "✅ AI Insights Service updated"
    echo "✅ Express Gateway updated"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Test the applications at their FQDNs"
    echo "2. Monitor logs for any issues"
    echo "3. Configure custom domains if needed"
    echo ""
    echo "🔗 Useful Commands:"
    echo "• Check app status: az containerapp show --name <app-name> --resource-group $RESOURCE_GROUP"
    echo "• View logs: az containerapp logs show --name <app-name> --resource-group $RESOURCE_GROUP"
    echo "• Scale app: az containerapp update --name <app-name> --min-replicas 2 --max-replicas 10"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --logs)
            shift
            app_name=$1
            if [ -z "$app_name" ]; then
                print_error "Please specify app name for logs: --logs <app-name>"
                exit 1
            fi
            get_app_logs $app_name
            exit 0
            ;;
        --status)
            shift
            app_name=$1
            if [ -z "$app_name" ]; then
                print_error "Please specify app name for status: --status <app-name>"
                exit 1
            fi
            check_app_status $app_name
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --logs <app-name>    Show logs for specific app"
            echo "  --status <app-name>  Show status for specific app"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                     # Deploy all apps"
            echo "  $0 --logs htma-work-item-service      # Show logs"
            echo "  $0 --status htma-ai-insights-service  # Show status"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Run main function if no specific command was given
main "$@"
