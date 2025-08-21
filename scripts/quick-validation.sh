#!/bin/bash

# Quick Migration Validation Script
# This script provides a fast overview of the migration status

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HT_MANAGEMENT_DIR="/Users/wyattfrelot/HT-Management"
HTMA_REPOS_DIR="/Users/wyattfrelot/HT-Management"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HTMA Platform - Quick Migration Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check main repositories
echo -e "${BLUE}Repository Status:${NC}"
repos=(
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
)

for repo in "${repos[@]}"; do
    if [[ -d "$HTMA_REPOS_DIR/$repo" ]]; then
        echo -e "  ${GREEN}✓${NC} $repo"
    else
        echo -e "  ${RED}✗${NC} $repo (MISSING)"
    fi
done

echo ""
echo -e "${BLUE}Infrastructure Components:${NC}"

# Check infrastructure components
infra_components=(
    "azure-infrastructure/terraform"
    "azure-infrastructure/scripts"
    "azure-infrastructure/bicep"
    "azure-infrastructure/docs"
)

for component in "${infra_components[@]}"; do
    if [[ -d "$HTMA_REPOS_DIR/$component" ]]; then
        echo -e "  ${GREEN}✓${NC} $component"
    else
        echo -e "  ${YELLOW}⚠${NC} $component"
    fi
done

echo ""
echo -e "${BLUE}Migration Summary:${NC}"

# Count total repositories
total_repos=0
existing_repos=0

for repo in "${repos[@]}"; do
    total_repos=$((total_repos + 1))
    if [[ -d "$HTMA_REPOS_DIR/$repo" ]]; then
        existing_repos=$((existing_repos + 1))
    fi
done

echo "  Total repositories: $total_repos"
echo "  Existing repositories: $existing_repos"
echo "  Missing repositories: $((total_repos - existing_repos))"

if [[ $existing_repos -eq $total_repos ]]; then
    echo -e "  ${GREEN}🎉 All repositories successfully created!${NC}"
else
    echo -e "  ${YELLOW}⚠ Some repositories are missing${NC}"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Verify each repository has the correct content"
echo "  2. Check that all source code was migrated"
echo "  3. Ensure configuration files are properly set up"
echo "  4. Test build processes in each repository"
echo "  5. Set up CI/CD pipelines for each service"
