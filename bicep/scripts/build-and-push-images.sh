#!/bin/bash

# Build and Push Docker Images to Azure Container Registry
# This script builds all microservice images and pushes them to ACR

set -e

# Configuration
ACR_NAME="htmadevacr3898"
ACR_SERVER="htmadevacr3898.azurecr.io"
IMAGE_TAG="latest"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to build shared package
build_shared_package() {
    print_status "Building shared package..."
    
    cd shared
    npm install
    npm run build
    cd ..
    
    print_success "Shared package built successfully"
}

# Function to build and push a single service
build_and_push_service() {
    local service_name=$1
    local service_path=$2
    local port=$3
    
    print_status "Building $service_name..."
    
    # Build Docker image
    docker build -t $ACR_SERVER/htma/$service_name:$IMAGE_TAG $service_path
    
    if [ $? -eq 0 ]; then
        print_success "$service_name image built successfully"
    else
        print_error "Failed to build $service_name image"
        exit 1
    fi
    
    print_status "Pushing $service_name to ACR..."
    
    # Push to ACR
    docker push $ACR_SERVER/htma/$service_name:$IMAGE_TAG
    
    if [ $? -eq 0 ]; then
        print_success "$service_name pushed to ACR successfully"
    else
        print_error "Failed to push $service_name to ACR"
        exit 1
    fi
}

# Function to verify images in ACR
verify_images() {
    print_status "Verifying images in ACR..."
    
    echo "Repositories in ACR:"
    az acr repository list --name $ACR_NAME --output table
    
    echo ""
    echo "Image tags for each service:"
    
    services=("work-item-service" "dependency-service" "ai-insights-service" "express-gateway")
    
    for service in "${services[@]}"; do
        echo "Tags for htma/$service:"
        az acr repository show-tags --name $ACR_NAME --repository htma/$service --output table || echo "No tags found for $service"
        echo ""
    done
}

# Main execution
main() {
    echo "================================================"
    echo "  HT-Management Docker Build & Push to ACR"
    echo "================================================"
    echo ""
    
    check_prerequisites
    
    print_status "Logging into ACR..."
    az acr login --name $ACR_NAME
    
    if [ $? -eq 0 ]; then
        print_success "Logged into ACR successfully"
    else
        print_error "Failed to login to ACR"
        exit 1
    fi
    
    # Build shared package first
    build_shared_package
    
    # Build and push each service
    print_status "Building and pushing microservices..."
    
    build_and_push_service "work-item-service" "services/work-item-service" "3001"
    build_and_push_service "dependency-service" "services/dependency-service" "3002"  
    build_and_push_service "ai-insights-service" "services/ai-insights-service" "3003"
    build_and_push_service "express-gateway" "services/express-gateway" "3000"
    
    # Verify all images
    verify_images
    
    print_success "All images built and pushed successfully!"
    
    echo ""
    echo "🎉 Build Summary:"
    echo "✅ Shared package built"
    echo "✅ Work Item Service: $ACR_SERVER/htma/work-item-service:$IMAGE_TAG"
    echo "✅ Dependency Service: $ACR_SERVER/htma/dependency-service:$IMAGE_TAG"
    echo "✅ AI Insights Service: $ACR_SERVER/htma/ai-insights-service:$IMAGE_TAG"
    echo "✅ Express Gateway: $ACR_SERVER/htma/express-gateway:$IMAGE_TAG"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Deploy to Azure Container Apps"
    echo "2. Configure environment variables from Key Vault"
    echo "3. Test the deployment"
    echo ""
    echo "🔗 Useful Commands:"
    echo "• View ACR repositories: az acr repository list --name $ACR_NAME"
    echo "• Deploy to Container Apps: az containerapp update --name <app-name> --image <image-url>"
    echo ""
}

# Run main function
main "$@"
