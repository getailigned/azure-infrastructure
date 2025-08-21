#!/bin/bash

# HTMA Platform - Workspace Management Script
# This script manages Terraform workspaces for multiple environments and cloud providers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/.."

# Available workspaces
AVAILABLE_WORKSPACES=(
    "azure-dev"
    "azure-staging" 
    "azure-prod"
    "gcp-dev"
    "gcp-staging"
    "gcp-prod"
)

# Function to show current workspace
show_current_workspace() {
    echo -e "${BLUE}Current Workspace:${NC}"
    terraform workspace show
    echo ""
}

# Function to list all workspaces
list_workspaces() {
    echo -e "${BLUE}Available Workspaces:${NC}"
    echo "Azure Environments:"
    echo "  azure-dev      - Azure Development"
    echo "  azure-staging  - Azure Staging"
    echo "  azure-prod     - Azure Production"
    echo ""
    echo "Google Cloud Environments:"
    echo "  gcp-dev        - GCP Development"
    echo "  gcp-staging    - GCP Staging"
    echo "  gcp-prod       - GCP Production"
    echo ""
    
    echo -e "${BLUE}Current Workspace:${NC}"
    terraform workspace show
    echo ""
}

# Function to create a new workspace
create_workspace() {
    local workspace_name=$1
    
    if [[ -z "$workspace_name" ]]; then
        echo -e "${RED}Error: Workspace name is required${NC}"
        echo "Usage: $0 create <workspace-name>"
        exit 1
    fi
    
    # Check if workspace exists
    if terraform workspace list | grep -q "$workspace_name"; then
        echo -e "${YELLOW}Workspace '$workspace_name' already exists${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Creating workspace: $workspace_name${NC}"
    terraform workspace new "$workspace_name"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Workspace '$workspace_name' created successfully${NC}"
    else
        echo -e "${RED}Failed to create workspace '$workspace_name'${NC}"
        exit 1
    fi
}

# Function to switch to a workspace
switch_workspace() {
    local workspace_name=$1
    
    if [[ -z "$workspace_name" ]]; then
        echo -e "${RED}Error: Workspace name is required${NC}"
        echo "Usage: $0 switch <workspace-name>"
        exit 1
    fi
    
    # Check if workspace exists
    if ! terraform workspace list | grep -q "$workspace_name"; then
        echo -e "${RED}Error: Workspace '$workspace_name' does not exist${NC}"
        echo "Available workspaces:"
        terraform workspace list
        exit 1
    fi
    
    echo -e "${BLUE}Switching to workspace: $workspace_name${NC}"
    terraform workspace select "$workspace_name"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Switched to workspace '$workspace_name' successfully${NC}"
        show_current_workspace
    else
        echo -e "${RED}Failed to switch to workspace '$workspace_name'${NC}"
        exit 1
    fi
}

# Function to delete a workspace
delete_workspace() {
    local workspace_name=$1
    
    if [[ -z "$workspace_name" ]]; then
        echo -e "${RED}Error: Workspace name is required${NC}"
        echo "Usage: $0 delete <workspace-name>"
        exit 1
    fi
    
    # Check if trying to delete current workspace
    local current_workspace=$(terraform workspace show)
    if [[ "$workspace_name" == "$current_workspace" ]]; then
        echo -e "${RED}Error: Cannot delete current workspace '$workspace_name'${NC}"
        echo "Please switch to a different workspace first"
        exit 1
    fi
    
    # Check if workspace exists
    if ! terraform workspace list | grep -q "$workspace_name"; then
        echo -e "${RED}Error: Workspace '$workspace_name' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Warning: This will permanently delete workspace '$workspace_name' and all its state${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        echo -e "${BLUE}Deleting workspace: $workspace_name${NC}"
        terraform workspace delete "$workspace_name"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Workspace '$workspace_name' deleted successfully${NC}"
        else
            echo -e "${RED}Failed to delete workspace '$workspace_name'${NC}"
            exit 1
            fi
    else
        echo -e "${BLUE}Deletion cancelled${NC}"
    fi
}

# Function to initialize all workspaces
init_all_workspaces() {
    echo -e "${BLUE}Initializing all workspaces...${NC}"
    
    for workspace in "${AVAILABLE_WORKSPACES[@]}"; do
        echo -e "${BLUE}Creating workspace: $workspace${NC}"
        terraform workspace new "$workspace" 2>/dev/null || echo "Workspace '$workspace' already exists"
    done
    
    echo -e "${GREEN}All workspaces initialized successfully${NC}"
    echo ""
    list_workspaces
}

# Function to show workspace status
show_status() {
    echo -e "${BLUE}Workspace Status:${NC}"
    echo "Current workspace: $(terraform workspace show)"
    echo "Total workspaces: $(terraform workspace list | wc -l)"
    echo ""
    
    echo -e "${BLUE}Workspace List:${NC}"
    terraform workspace list
    echo ""
}

# Function to show help
show_help() {
    echo -e "${BLUE}HTMA Platform - Workspace Management Script${NC}"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list                    - List all available workspaces"
    echo "  current                 - Show current workspace"
    echo "  create <name>           - Create a new workspace"
    echo "  switch <name>           - Switch to a workspace"
    echo "  delete <name>           - Delete a workspace"
    echo "  init-all                - Initialize all predefined workspaces"
    echo "  status                  - Show workspace status"
    echo "  help                    - Show this help message"
    echo ""
    echo "Available Workspaces:"
    echo "  azure-dev, azure-staging, azure-prod"
    echo "  gcp-dev, gcp-staging, gcp-prod"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 create azure-dev"
    echo "  $0 switch gcp-staging"
    echo "  $0 delete azure-dev"
}

# Main script logic
main() {
    # Change to terraform directory
    cd "$TERRAFORM_DIR"
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if we're in a terraform directory
    if [[ ! -f "main.tf" ]]; then
        echo -e "${RED}Error: Not in a Terraform directory${NC}"
        echo "Please run this script from the terraform directory"
        exit 1
    fi
    
    # Parse command
    case "${1:-help}" in
        "list")
            list_workspaces
            ;;
        "current")
            show_current_workspace
            ;;
        "create")
            create_workspace "$2"
            ;;
        "switch")
            switch_workspace "$2"
            ;;
        "delete")
            delete_workspace "$2"
            ;;
        "init-all")
            init_all_workspaces
            ;;
        "status")
            show_status
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
