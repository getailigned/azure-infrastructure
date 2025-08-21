#!/bin/bash

# HTMA Platform - Migration Validation Script
# This script validates that all files from HT-Management have been properly migrated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HT_MANAGEMENT_DIR="/Users/wyattfrelot/HT-Management"
HTMA_REPOS_DIR="/Users/wyattfrelot/HT-Management"

# Migration mapping (source paths)
SOURCE_PATHS=(
    "frontend"
    "services/work-item-service"
    "services/dependency-service"
    "services/ai-insights-service"
    "services/websocket-service"
    "services/search-service"
    "services/hta-builder-service"
    "services/notification-service"
    "services/express-gateway"
    "services/policy-service"
    "shared-types"
    "shared"
    "infrastructure"
    "docs"
    "azure"
    "terraform"
    "scripts"
)

# Migration mapping (target paths)
TARGET_PATHS=(
    "frontend"
    "work-item-service"
    "dependency-service"
    "ai-insights-service"
    "websocket-service"
    "search-service"
    "hta-builder-service"
    "notification-service"
    "api-gateway"
    "policy-service"
    "shared-types"
    "shared-utils"
    "infrastructure"
    "documentation"
    "azure-infrastructure"
    "azure-infrastructure/terraform"
    "azure-infrastructure/scripts"
)

# Function to show header
show_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  HTMA Platform Migration Validation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to check if directory exists
check_directory() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        echo -e "${GREEN}✓${NC} $dir_path"
        return 0
    else
        echo -e "${RED}✗${NC} $dir_path (MISSING)"
        return 1
    fi
}

# Function to count files in directory
count_files() {
    local dir_path="$1"
    local file_count=$(find "$dir_path" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "$file_count"
}

# Function to validate service migration
validate_service() {
    local service_name="$1"
    local source_dir="$2"
    local target_dir="$3"
    
    echo -e "${BLUE}Validating $service_name...${NC}"
    
    # Check if target directory exists
    if ! check_directory "$target_dir"; then
        return 1
    fi
    
    # Count files in source and target
    local source_count=$(count_files "$source_dir")
    local target_count=$(count_files "$target_dir")
    
    echo "  Source files: $source_count"
    echo "  Target files: $target_count"
    
    if [[ "$target_count" -ge "$source_count" ]]; then
        echo -e "  ${GREEN}✓ Migration appears complete${NC}"
        return 0
    else
        echo -e "  ${YELLOW}⚠ Target has fewer files than source${NC}"
        return 1
    fi
}

# Function to validate infrastructure migration
validate_infrastructure() {
    echo -e "${BLUE}Validating Infrastructure...${NC}"
    
    local infra_dirs=("infrastructure" "azure" "terraform")
    local target_base="$HTMA_REPOS_DIR/azure-infrastructure"
    
    for dir in "${infra_dirs[@]}"; do
        local source_dir="$HT_MANAGEMENT_DIR/$dir"
        local target_dir="$target_base/$dir"
        
        if [[ "$dir" == "infrastructure" ]]; then
            target_dir="$HTMA_REPOS_DIR/infrastructure"
        fi
        
        if [[ -d "$source_dir" ]]; then
            echo "  Checking $dir..."
            check_directory "$target_dir"
        fi
    done
}

# Function to validate shared components
validate_shared() {
    echo -e "${BLUE}Validating Shared Components...${NC}"
    
    local shared_dirs=("shared-types" "shared")
    local target_dirs=("shared-types" "shared-utils")
    
    for i in "${!shared_dirs[@]}"; do
        local source_dir="$HT_MANAGEMENT_DIR/${shared_dirs[$i]}"
        local target_dir="$HTMA_REPOS_DIR/${target_dirs[$i]}"
        
        if [[ -d "$source_dir" ]]; then
            echo "  Checking ${shared_dirs[$i]}..."
            check_directory "$target_dir"
        fi
    done
}

# Function to validate documentation
validate_documentation() {
    echo -e "${BLUE}Validating Documentation...${NC}"
    
    local docs_source="$HT_MANAGEMENT_DIR/docs"
    local docs_target="$HTMA_REPOS_DIR/documentation"
    
    if [[ -d "$docs_source" ]]; then
        echo "  Checking documentation..."
        check_directory "$docs_target"
    fi
}

# Function to generate summary report
generate_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Migration Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    local total_services=0
    local migrated_services=0
    
    for i in "${!SOURCE_PATHS[@]}"; do
        local source_path="${SOURCE_PATHS[$i]}"
        local target_path="${TARGET_PATHS[$i]}"
        local source_dir="$HT_MANAGEMENT_DIR/$source_path"
        local target_dir="$HTMA_REPOS_DIR/$target_path"
        
        if [[ -d "$source_dir" ]]; then
            total_services=$((total_services + 1))
            
            if [[ -d "$target_dir" ]]; then
                migrated_services=$((migrated_services + 1))
                echo -e "${GREEN}✓${NC} $source_path → $target_path"
            else
                echo -e "${RED}✗${NC} $source_path → $target_path (MISSING)"
            fi
        fi
    done
    
    echo ""
    echo -e "${BLUE}Migration Status: $migrated_services/$total_services services migrated${NC}"
    
    if [[ "$migrated_services" -eq "$total_services" ]]; then
        echo -e "${GREEN}🎉 All services successfully migrated!${NC}"
    else
        echo -e "${YELLOW}⚠ Some services still need migration${NC}"
    fi
}

# Function to check for missing files
check_missing_files() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Checking for Missing Files${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Check for important configuration files
    local important_files=(
        "package.json"
        "docker-compose.yml"
        "README.md"
        ".env.example"
        "tsconfig.json"
        "Dockerfile"
    )
    
    for file in "${important_files[@]}"; do
        local found=false
        
        for repo in "$HTMA_REPOS_DIR"/*; do
            if [[ -f "$repo/$file" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "$found" == "true" ]]; then
            echo -e "${GREEN}✓${NC} $file found in at least one repository"
        else
            echo -e "${YELLOW}⚠${NC} $file not found in any repository"
        fi
    done
}

# Function to show help
show_help() {
    echo -e "${BLUE}HTMA Platform - Migration Validation Script${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --services      - Validate service migrations only"
    echo "  --infra         - Validate infrastructure migrations only"
    echo "  --shared        - Validate shared component migrations only"
    echo "  --docs          - Validate documentation migrations only"
    echo "  --missing       - Check for missing important files"
    echo "  --summary       - Show migration summary only"
    echo "  --help          - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full validation"
    echo "  $0 --services         # Services only"
    echo "  $0 --summary          # Summary only"
}

# Main script logic
main() {
    show_header
    
    # Parse command line arguments
    local validate_services=true
    local validate_infra=true
    local validate_shared=true
    local validate_docs=true
    local check_missing=true
    local show_summary=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --services)
                validate_infra=false
                validate_shared=false
                validate_docs=false
                check_missing=false
                show_summary=false
                shift
                ;;
            --infra)
                validate_services=false
                validate_shared=false
                validate_docs=false
                check_missing=false
                show_summary=false
                shift
                ;;
            --shared)
                validate_services=false
                validate_infra=false
                validate_docs=false
                check_missing=false
                show_summary=false
                shift
                ;;
            --docs)
                validate_services=false
                validate_infra=false
                validate_shared=false
                check_missing=false
                show_summary=false
                shift
                ;;
            --missing)
                validate_services=false
                validate_infra=false
                validate_shared=false
                validate_docs=false
                show_summary=false
                shift
                ;;
            --summary)
                validate_services=false
                validate_infra=false
                validate_shared=false
                validate_docs=false
                check_missing=false
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate services
    if [[ "$validate_services" == "true" ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Service Migration Validation${NC}"
        echo -e "${BLUE}========================================${NC}"
        
        for i in "${!SOURCE_PATHS[@]}"; do
            local source_path="${SOURCE_PATHS[$i]}"
            if [[ "$source_path" == *"services/"* ]] || [[ "$source_path" == "frontend" ]]; then
                local target_path="${TARGET_PATHS[$i]}"
                local source_dir="$HT_MANAGEMENT_DIR/$source_path"
                local target_dir="$HTMA_REPOS_DIR/$target_path"
                
                if [[ -d "$source_dir" ]]; then
                    validate_service "$source_path" "$source_dir" "$target_dir"
                    echo ""
                fi
            fi
        done
    fi
    
    # Validate infrastructure
    if [[ "$validate_infra" == "true" ]]; then
        validate_infrastructure
        echo ""
    fi
    
    # Validate shared components
    if [[ "$validate_shared" == "true" ]]; then
        validate_shared
        echo ""
    fi
    
    # Validate documentation
    if [[ "$validate_docs" == "true" ]]; then
        validate_documentation
        echo ""
    fi
    
    # Check for missing files
    if [[ "$check_missing" == "true" ]]; then
        check_missing_files
    fi
    
    # Show summary
    if [[ "$show_summary" == "true" ]]; then
        generate_summary
    fi
}

# Run main function
main "$@"
