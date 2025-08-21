#!/bin/bash

# Validate Phase 5-6 Bicep Templates
# This script validates the Bicep templates without deploying them

set -e

# Configuration
ENVIRONMENT=${ENVIRONMENT:-dev}
RESOURCE_GROUP="htma-${ENVIRONMENT}-rg"
LOCATION=${LOCATION:-eastus2}

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

# Function to validate individual modules
validate_module() {
    local module_path=$1
    local module_name=$(basename "$module_path" .bicep)
    
    echo_info "Validating module: $module_name"
    
    if az bicep validate --file "$module_path"; then
        echo_success "✓ $module_name syntax is valid"
    else
        echo_error "✗ $module_name has syntax errors"
        return 1
    fi
}

# Function to validate main template
validate_main_template() {
    echo_info "Validating main template with test parameters..."
    
    # Create temporary parameters file for validation
    cat > "/tmp/test-params.json" << EOF
{
  "environment": {"value": "$ENVIRONMENT"},
  "appName": {"value": "htma"},
  "location": {"value": "$LOCATION"},
  "postgresAdminLogin": {"value": "testadmin"},
  "postgresAdminPassword": {"value": "TempPassword123!"},
  "mongoAdminUsername": {"value": "testadmin"},
  "mongoAdminPassword": {"value": "TempPassword123!"},
  "openAiApiKey": {"value": "sk-test-key"}
}
EOF
    
    # Validate template deployment
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "../bicep/main.bicep" \
        --parameters @/tmp/test-params.json \
        --no-prompt; then
        echo_success "✓ Main template validation passed"
    else
        echo_error "✗ Main template validation failed"
        return 1
    fi
    
    # Clean up
    rm -f /tmp/test-params.json
}

# Function to check bicep version
check_bicep_version() {
    echo_info "Checking Bicep CLI version..."
    
    if ! command -v az &> /dev/null; then
        echo_error "Azure CLI is not installed"
        return 1
    fi
    
    if ! az bicep version &> /dev/null; then
        echo_warning "Bicep CLI not found. Installing..."
        az bicep install
    fi
    
    local bicep_version=$(az bicep version --output tsv)
    echo_success "Bicep CLI version: $bicep_version"
}

# Function to lint templates
lint_templates() {
    echo_info "Running Bicep linter on all templates..."
    
    local bicep_files=(
        "../bicep/main.bicep"
        "../bicep/modules/realtime-services.bicep"
        "../bicep/modules/ai-search-services.bicep"
        "../bicep/modules/enhanced-container-apps.bicep"
    )
    
    for file in "${bicep_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo_info "Linting $(basename "$file")..."
            if az bicep lint --file "$file"; then
                echo_success "✓ $(basename "$file") passed linting"
            else
                echo_warning "⚠ $(basename "$file") has linting warnings"
            fi
        else
            echo_error "✗ File not found: $file"
        fi
    done
}

# Function to check resource group
check_resource_group() {
    echo_info "Checking if resource group exists: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo_success "✓ Resource group exists: $RESOURCE_GROUP"
    else
        echo_warning "⚠ Resource group does not exist: $RESOURCE_GROUP"
        echo_info "Creating resource group for validation..."
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        echo_success "✓ Resource group created: $RESOURCE_GROUP"
    fi
}

# Function to estimate costs
estimate_costs() {
    echo_info "Estimating deployment costs..."
    
    cat << EOF

📊 Estimated Monthly Costs (USD):

Phase 5 - Real-time Services:
  • Azure SignalR Service (Free/Standard):     \$0 - \$50
  • Azure Cache for Redis (Basic/Standard):    \$15 - \$100
  • Azure Service Bus (Basic):                 \$10
  • Azure Event Grid (pay-per-event):          \$1 - \$5
  • Azure Notification Hubs (Free):            \$0 - \$1
  ────────────────────────────────────────────
  Phase 5 Subtotal:                           \$26 - \$166

Phase 6 - AI & Search Services:
  • Azure OpenAI Service (pay-per-token):      \$50 - \$200
  • Azure Cognitive Search (Basic/Standard):   \$250
  • Azure Storage Account (Hot tier):          \$10 - \$50
  • Cognitive Services (F0/S0):                \$0 - \$100
  ────────────────────────────────────────────
  Phase 6 Subtotal:                           \$310 - \$600

Container Platform:
  • Azure Container Apps (consumption):        \$50 - \$200
  • Azure Container Registry (Basic):          \$5
  ────────────────────────────────────────────
  Platform Subtotal:                          \$55 - \$205

═══════════════════════════════════════════════
TOTAL ESTIMATED COST:                          \$391 - \$971/month

Environment: $ENVIRONMENT
Note: Production costs will be higher due to redundancy and scale.

EOF
}

# Function to generate deployment summary
generate_summary() {
    echo_info "Generating deployment summary..."
    
    cat << EOF

🚀 Phase 5-6 Azure Deployment Summary

Environment:           $ENVIRONMENT
Resource Group:        $RESOURCE_GROUP
Location:              $LOCATION
Template Version:      Phase 5-6 v1.0

Services to Deploy:
┌─────────────────────────────────────────────┐
│ Phase 5 - Real-time Foundation             │
├─────────────────────────────────────────────┤
│ ✓ Azure SignalR Service                    │
│ ✓ Azure Cache for Redis                    │
│ ✓ Azure Service Bus                        │
│ ✓ Azure Event Grid                         │
│ ✓ Azure Notification Hubs                  │
│ ✓ WebSocket Service (Container App)        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Phase 6 - AI & Search Services             │
├─────────────────────────────────────────────┤
│ ✓ Azure OpenAI Service                     │
│   - GPT-4o-mini deployment                 │
│   - GPT-3.5-turbo deployment               │
│   - Text embedding deployment              │
│ ✓ Azure Cognitive Search                   │
│ ✓ Azure Storage Account                    │
│ ✓ Form Recognizer                          │
│ ✓ Text Analytics                           │
│ ✓ Computer Vision                          │
│ ✓ Content Safety                           │
│ ✓ Search Service (Container App)           │
│ ✓ HTA Builder Service (Container App)      │
└─────────────────────────────────────────────┘

Next Steps:
1. Run validation: ./validate-phase5-6.sh
2. Set OPENAI_API_KEY environment variable
3. Deploy: ./deploy-phase5-6.sh
4. Test services using provided health endpoints

EOF
}

# Main execution
main() {
    echo_info "🔍 Starting Phase 5-6 Bicep Template Validation"
    echo_info "Environment: $ENVIRONMENT"
    echo_info "Resource Group: $RESOURCE_GROUP"
    echo ""
    
    check_bicep_version
    echo ""
    
    # Validate individual modules
    echo_info "Validating individual Bicep modules..."
    validate_module "../bicep/modules/realtime-services.bicep"
    validate_module "../bicep/modules/ai-search-services.bicep"
    validate_module "../bicep/modules/enhanced-container-apps.bicep"
    echo ""
    
    # Lint all templates
    lint_templates
    echo ""
    
    # Check resource group
    check_resource_group
    echo ""
    
    # Validate main template
    validate_main_template
    echo ""
    
    # Show cost estimates
    estimate_costs
    
    # Generate summary
    generate_summary
    
    echo_success "🎉 All validations completed successfully!"
    echo_info "Templates are ready for deployment."
}

# Run main function
main "$@"
