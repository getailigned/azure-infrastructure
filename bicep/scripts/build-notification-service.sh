#!/bin/bash

# Build and Push Notification Service Container Image to Azure Container Registry

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
REGISTRY_NAME="htmaregistry"
IMAGE_NAME="htma/notification-service"
IMAGE_TAG="${1:-latest}"
DOCKERFILE_PATH="services/notification-service/Dockerfile"
BUILD_CONTEXT="services/notification-service"

# Function to check prerequisites
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
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
    
    # Check if Dockerfile exists
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        echo_error "Dockerfile not found at: $DOCKERFILE_PATH"
        exit 1
    fi
    
    echo_success "All prerequisites satisfied"
}

# Function to prepare build context
prepare_build() {
    echo_info "Preparing build context..."
    
    cd "$BUILD_CONTEXT"
    
    # Install dependencies and build TypeScript
    echo_info "Installing dependencies..."
    npm ci --only=production
    
    echo_info "Building TypeScript..."
    npm run build
    
    cd ../..
    echo_success "Build context prepared"
}

# Function to build Docker image
build_image() {
    echo_info "Building Docker image..."
    
    local full_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
    
    echo_info "Building image: $full_image_name"
    docker build \
        --tag "$full_image_name" \
        --file "$DOCKERFILE_PATH" \
        --platform linux/amd64 \
        --progress plain \
        "$BUILD_CONTEXT"
    
    echo_success "Docker image built successfully"
    
    # Also tag as latest if not already
    if [[ "$IMAGE_TAG" != "latest" ]]; then
        local latest_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:latest"
        echo_info "Tagging as latest: $latest_image_name"
        docker tag "$full_image_name" "$latest_image_name"
    fi
}

# Function to test image locally
test_image() {
    echo_info "Testing Docker image locally..."
    
    local full_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Run container with minimal environment
    echo_info "Starting test container..."
    local container_id=$(docker run -d \
        --name "htma-notification-test" \
        --env NODE_ENV=test \
        --env PORT=3007 \
        --env JWT_SECRET=test-secret \
        --publish 3007:3007 \
        "$full_image_name")
    
    # Wait for container to start
    sleep 5
    
    # Test health endpoint
    echo_info "Testing health endpoint..."
    if curl -f http://localhost:3007/health &> /dev/null; then
        echo_success "Health endpoint is responding"
    else
        echo_warning "Health endpoint is not responding (may need database connection)"
    fi
    
    # Show container logs
    echo_info "Container logs:"
    docker logs "$container_id" | tail -10
    
    # Clean up test container
    echo_info "Cleaning up test container..."
    docker stop "$container_id" &> /dev/null || true
    docker rm "$container_id" &> /dev/null || true
    
    echo_success "Image test completed"
}

# Function to push to Azure Container Registry
push_image() {
    echo_info "Pushing image to Azure Container Registry..."
    
    # Login to ACR
    echo_info "Logging in to Azure Container Registry..."
    az acr login --name "$REGISTRY_NAME"
    
    # Push the tagged image
    local full_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
    echo_info "Pushing image: $full_image_name"
    docker push "$full_image_name"
    
    # Also push latest tag if applicable
    if [[ "$IMAGE_TAG" != "latest" ]]; then
        local latest_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:latest"
        echo_info "Pushing latest tag: $latest_image_name"
        docker push "$latest_image_name"
    fi
    
    echo_success "Image pushed to registry successfully"
}

# Function to show image information
show_image_info() {
    echo_info "Image Information:"
    
    local full_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Show image size and details
    docker images "$full_image_name" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    echo ""
    echo_info "Registry Information:"
    echo "  Registry: ${REGISTRY_NAME}.azurecr.io"
    echo "  Image: $IMAGE_NAME"
    echo "  Tag: $IMAGE_TAG"
    echo "  Full Name: $full_image_name"
    echo ""
    
    # Show ACR repository information
    echo_info "Azure Container Registry Repository:"
    az acr repository show \
        --name "$REGISTRY_NAME" \
        --repository "$IMAGE_NAME" \
        --query "{name:name, tagCount:tagCount, lastUpdateTime:lastUpdateTime}" \
        --output table 2>/dev/null || echo "Repository information not available"
}

# Function to cleanup local images
cleanup() {
    echo_info "Cleaning up local images..."
    
    local full_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
    
    read -p "Remove local image? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Removing local image: $full_image_name"
        docker rmi "$full_image_name" &> /dev/null || true
        
        if [[ "$IMAGE_TAG" != "latest" ]]; then
            local latest_image_name="${REGISTRY_NAME}.azurecr.io/${IMAGE_NAME}:latest"
            docker rmi "$latest_image_name" &> /dev/null || true
        fi
        
        echo_success "Local images removed"
    else
        echo_info "Keeping local images"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [TAG]"
    echo ""
    echo "Build and push the HTMA Notification Service container image to Azure Container Registry"
    echo ""
    echo "Arguments:"
    echo "  TAG    Image tag (default: latest)"
    echo ""
    echo "Examples:"
    echo "  $0           # Build and push with 'latest' tag"
    echo "  $0 v1.0.0    # Build and push with 'v1.0.0' tag"
    echo "  $0 dev       # Build and push with 'dev' tag"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY_NAME    Azure Container Registry name (default: htmaregistry)"
    echo "  SKIP_TESTS      Skip local image testing (default: false)"
    echo "  SKIP_PUSH       Skip pushing to registry (default: false)"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    echo_info "🐳 Building HTMA Notification Service Container Image"
    echo ""
    
    check_prerequisites
    prepare_build
    build_image
    
    # Skip tests if requested
    if [[ "$SKIP_TESTS" != "true" ]]; then
        test_image
    fi
    
    # Skip push if requested (for testing builds)
    if [[ "$SKIP_PUSH" != "true" ]]; then
        push_image
    fi
    
    show_image_info
    
    # Optional cleanup
    if [[ "$SKIP_PUSH" != "true" ]]; then
        cleanup
    fi
    
    echo ""
    echo_success "🎉 Container image build completed successfully!"
    echo ""
    echo_info "📋 Next Steps:"
    echo "  1. Deploy to Azure Container Apps"
    echo "  2. Test the deployed service"
    echo "  3. Monitor logs and metrics"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
