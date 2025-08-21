#!/bin/bash

# HTMA Platform - Architecture Coverage Validation Script
# This script validates that all Bicep components have Terraform equivalents

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 HTMA Platform - Architecture Coverage Validation${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/.."
BICEP_DIR="../../azure/bicep"

# Function to check if module exists
check_module() {
    local module_name=$1
    local bicep_file=$2
    local terraform_module=$3
    
    if [[ -d "$TERRAFORM_DIR/modules/$terraform_module" ]]; then
        echo -e "✅ ${GREEN}$module_name${NC} - Terraform module exists"
        return 0
    else
        echo -e "❌ ${RED}$module_name${NC} - Terraform module missing"
        return 1
    fi
}

# Function to check if module is referenced in main.tf
check_main_reference() {
    local module_name=$1
    local terraform_module=$2
    
    if grep -q "module \"$terraform_module\"" "$TERRAFORM_DIR/main.tf"; then
        echo -e "  ✅ Referenced in main.tf"
        return 0
    else
        echo -e "  ❌ Not referenced in main.tf"
        return 1
    fi
}

# Initialize counters
total_modules=0
existing_modules=0
referenced_modules=0

echo -e "${BLUE}📋 Checking Bicep to Terraform Module Coverage${NC}"
echo ""

# Core Infrastructure Modules
echo -e "${YELLOW}🏗️  Core Infrastructure:${NC}"
((total_modules++))
if check_module "Key Vault" "keyvault.bicep" "key_vault"; then
    ((existing_modules++))
    if check_main_reference "Key Vault" "key_vault"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Networking" "networking.bicep" "networking"; then
    ((existing_modules++))
    if check_main_reference "Networking" "networking"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Container Registry" "container-registry.bicep" "container_registry"; then
    ((existing_modules++))
    if check_main_reference "Container Registry" "container_registry"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Data Services Modules
echo -e "${YELLOW}🗄️  Data Services:${NC}"
((total_modules++))
if check_module "Data Services" "data-services.bicep" "data_services"; then
    ((existing_modules++))
    if check_main_reference "Data Services" "data_services"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Cache" "cache.bicep" "cache"; then
    ((existing_modules++))
    if check_main_reference "Cache" "cache"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Messaging" "messaging.bicep" "messaging"; then
    ((existing_modules++))
    if check_main_reference "Messaging" "messaging"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Real-time Services Modules (Phase 5)
echo -e "${YELLOW}⚡ Real-time Services (Phase 5):${NC}"
((total_modules++))
if check_module "Real-time Services" "realtime-services.bicep" "realtime_services"; then
    ((existing_modules++))
    if check_main_reference "Real-time Services" "realtime_services"; then
        ((referenced_modules++))
    fi
fi

echo ""

# AI & Search Services Modules (Phase 6)
echo -e "${YELLOW}🤖 AI & Search Services (Phase 6):${NC}"
((total_modules++))
if check_module "AI Services" "ai-search-services.bicep" "ai_services"; then
    ((existing_modules++))
    if check_main_reference "AI Services" "ai_services"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Container Platform Modules
echo -e "${YELLOW}🐳 Container Platform:${NC}"
((total_modules++))
if check_module "Container Apps Environment" "container-apps.bicep" "container_apps_environment"; then
    ((existing_modules++))
    if check_main_reference "Container Apps Environment" "container_apps_environment"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Container Apps" "enhanced-container-apps.bicep" "container_apps"; then
    ((existing_modules++))
    if check_main_reference "Container Apps" "container_apps"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Frontend & API Modules
echo -e "${YELLOW}🌐 Frontend & API:${NC}"
((total_modules++))
if check_module "Static Web App" "static-web-app.bicep" "static_web_app"; then
    ((existing_modules++))
    if check_main_reference "Static Web App" "static_web_app"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "API Management" "microservices-infrastructure.bicep" "api_management"; then
    ((existing_modules++))
    if check_main_reference "API Management" "api_management"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Function App" "microservices-infrastructure.bicep" "function_app"; then
    ((existing_modules++))
    if check_main_reference "Function App" "function_app"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "App Service Plan" "microservices-infrastructure.bicep" "app_service_plan"; then
    ((existing_modules++))
    if check_main_reference "App Service Plan" "app_service_plan"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Infrastructure & Security Modules
echo -e "${YELLOW}🔒 Infrastructure & Security:${NC}"
((total_modules++))
if check_module "Application Gateway" "application-gateway.bicep" "application_gateway"; then
    ((existing_modules++))
    if check_main_reference "Application Gateway" "application_gateway"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "VPN Gateway" "vpn-gateway.bicep" "vpn_gateway"; then
    ((existing_modules++))
    if check_main_reference "VPN Gateway" "vpn_gateway"; then
        ((referenced_modules++))
    fi
fi

((total_modules++))
if check_module "Monitoring" "monitoring.bicep" "monitoring"; then
    ((existing_modules++))
    if check_main_reference "Monitoring" "monitoring"; then
        ((referenced_modules++))
    fi
fi

echo ""

# Summary
echo -e "${BLUE}📊 Coverage Summary:${NC}"
echo -e "Total Modules: ${total_modules}"
echo -e "Existing Modules: ${existing_modules}/${total_modules}"
echo -e "Referenced in main.tf: ${referenced_modules}/${total_modules}"

coverage_percentage=$((existing_modules * 100 / total_modules))
reference_percentage=$((referenced_modules * 100 / total_modules))

echo -e "Module Coverage: ${coverage_percentage}%"
echo -e "Reference Coverage: ${reference_percentage}%"

echo ""

if [[ $coverage_percentage -eq 100 ]]; then
    echo -e "${GREEN}🎉 All architecture components are covered in Terraform!${NC}"
else
    echo -e "${RED}⚠️  Some architecture components are missing from Terraform.${NC}"
    echo -e "Please create the missing modules to achieve 100% coverage."
fi

if [[ $reference_percentage -eq 100 ]]; then
    echo -e "${GREEN}🎉 All modules are properly referenced in main.tf!${NC}"
else
    echo -e "${RED}⚠️  Some modules are not referenced in main.tf.${NC}"
    echo -e "Please add the missing module references."
fi

echo ""

# List missing modules
if [[ $coverage_percentage -lt 100 ]]; then
    echo -e "${YELLOW}📋 Missing Modules:${NC}"
    # This would need to be implemented based on the actual missing modules
    echo "Run this script to see which specific modules are missing."
fi

echo ""
echo -e "${BLUE}Validation completed!${NC}"
