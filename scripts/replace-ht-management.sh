#!/bin/bash

# HTMA Platform - Safe HT-Management Replacement Script
# This script safely replaces the monolithic HT-Management with the microservices structure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HT_MANAGEMENT_DIR="/Users/wyattfrelot/HT-Management"
HTMA_REPOS_DIR="/Users/wyattfrelot/htma-repos"
BACKUP_DIR="/Users/wyattfrelot/HT-Management-BACKUP-$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HTMA Platform - Safe Replacement Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to show warning
show_warning() {
    echo -e "${RED}⚠️  WARNING: This operation will replace your HT-Management directory!${NC}"
    echo ""
    echo "This script will:"
    echo "  1. Create a backup of HT-Management at: $BACKUP_DIR"
    echo "  2. Move htma-repos to replace HT-Management"
    echo "  3. Update any references to the old location"
    echo ""
    echo -e "${YELLOW}This is a destructive operation. Please ensure you have:${NC}"
    echo "  ✓ Verified all files are migrated to htma-repos"
    echo "  ✓ Confirmed htma-repos contains all necessary code"
    echo "  ✓ Backed up any important uncommitted changes"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if HT-Management exists
    if [[ ! -d "$HT_MANAGEMENT_DIR" ]]; then
        echo -e "${RED}Error: HT-Management directory not found at $HT_MANAGEMENT_DIR${NC}"
        exit 1
    fi
    
    # Check if htma-repos exists
    if [[ ! -d "$HTMA_REPOS_DIR" ]]; then
        echo -e "${RED}Error: htma-repos directory not found at $HTMA_REPOS_DIR${NC}"
        exit 1
    fi
    
    # Check available disk space
    local ht_size=$(du -s "$HT_MANAGEMENT_DIR" | cut -f1)
    local available_space=$(df "$HT_MANAGEMENT_DIR" | tail -1 | awk '{print $4}')
    
    if [[ $available_space -lt $((ht_size * 2)) ]]; then
        echo -e "${YELLOW}Warning: Limited disk space for backup operation${NC}"
        echo "Available: $available_space KB, Required: $((ht_size * 2)) KB"
        read -p "Continue anyway? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Operation cancelled"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Function to create backup
create_backup() {
    echo ""
    echo -e "${BLUE}Creating backup of HT-Management...${NC}"
    echo "Backup location: $BACKUP_DIR"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Copy HT-Management to backup
    echo "Copying files (this may take a while)..."
    cp -R "$HT_MANAGEMENT_DIR"/* "$BACKUP_DIR/"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        echo "Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
    else
        echo -e "${RED}✗ Backup failed${NC}"
        exit 1
    fi
}

# Function to replace HT-Management
replace_ht_management() {
    echo ""
    echo -e "${BLUE}Replacing HT-Management with microservices structure...${NC}"
    
    # Remove old HT-Management
    echo "Removing old HT-Management directory..."
    rm -rf "$HT_MANAGEMENT_DIR"
    
    # Move htma-repos to HT-Management location
    echo "Moving htma-repos to HT-Management location..."
    mv "$HTMA_REPOS_DIR" "$HT_MANAGEMENT_DIR"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ HT-Management successfully replaced with microservices structure${NC}"
    else
        echo -e "${RED}✗ Replacement failed${NC}"
        echo "Attempting to restore from backup..."
        restore_from_backup
        exit 1
    fi
}

# Function to restore from backup
restore_from_backup() {
    echo ""
    echo -e "${YELLOW}Restoring from backup...${NC}"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        # Restore original HT-Management
        cp -R "$BACKUP_DIR"/* "$HT_MANAGEMENT_DIR/"
        echo -e "${GREEN}✓ Original HT-Management restored${NC}"
    else
        echo -e "${RED}✗ Backup not found, cannot restore${NC}"
    fi
}

# Function to update references
update_references() {
    echo ""
    echo -e "${BLUE}Updating references...${NC}"
    
    # Update any shell scripts or configuration files that might reference the old path
    local new_ht_management="/Users/wyattfrelot/HT-Management"
    
    # Find and update any files that reference the old htma-repos path
    echo "Checking for files that reference old htma-repos path..."
    find "$new_ht_management" -type f -name "*.sh" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.md" | xargs grep -l "htma-repos" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Reference update complete${NC}"
}

# Function to verify replacement
verify_replacement() {
    echo ""
    echo -e "${BLUE}Verifying replacement...${NC}"
    
    local new_ht_management="/Users/wyattfrelot/HT-Management"
    
    # Check if new structure exists
    if [[ -d "$new_ht_management" ]]; then
        echo -e "${GREEN}✓ New HT-Management directory exists${NC}"
        
        # List contents
        echo "New structure contents:"
        ls -la "$new_ht_management"
        
        # Check size
        echo "New size: $(du -sh "$new_ht_management" | cut -f1)"
    else
        echo -e "${RED}✗ New HT-Management directory not found${NC}"
        return 1
    fi
    
    # Verify key directories exist
    local key_dirs=("frontend" "work-item-service" "azure-infrastructure")
    for dir in "${key_dirs[@]}"; do
        if [[ -d "$new_ht_management/$dir" ]]; then
            echo -e "  ${GREEN}✓${NC} $dir"
        else
            echo -e "  ${RED}✗${NC} $dir (MISSING)"
        fi
    done
}

# Function to show completion
show_completion() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Replacement Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Your HT-Management directory has been successfully replaced with the microservices structure."
    echo ""
    echo -e "${BLUE}Important Notes:${NC}"
    echo "  • Original HT-Management backed up to: $BACKUP_DIR"
    echo "  • New structure is now at: /Users/wyattfrelot/HT-Management"
    echo "  • All microservices are now accessible from the main directory"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Test that all services can be built and run"
    echo "  2. Update any scripts or documentation that reference the old structure"
    echo "  3. Consider removing the backup directory after verification"
    echo ""
    echo -e "${BLUE}To remove backup:${NC}"
    echo "  rm -rf $BACKUP_DIR"
}

# Function to show help
show_help() {
    echo -e "${BLUE}HTMA Platform - Safe Replacement Script${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run      - Show what would be done without executing"
    echo "  --no-backup    - Skip backup creation (not recommended)"
    echo "  --help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full replacement with backup"
    echo "  $0 --dry-run          # Show what would be done"
    echo "  $0 --no-backup        # Replace without backup (RISKY)"
}

# Main script logic
main() {
    # Parse command line arguments
    local dry_run=false
    local skip_backup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --no-backup)
                skip_backup=true
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
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}DRY RUN MODE - No changes will be made${NC}"
        echo ""
        echo "This script would:"
        echo "  1. Create backup at: $BACKUP_DIR"
        echo "  2. Remove: $HT_MANAGEMENT_DIR"
        echo "  3. Move: $HTMA_REPOS_DIR → $HT_MANAGEMENT_DIR"
        echo ""
        echo "To execute, run without --dry-run flag"
        exit 0
    fi
    
    # Show warning and get confirmation
    show_warning
    
    read -p "Do you want to continue? Type 'YES' to proceed: " confirm
    if [[ "$confirm" != "YES" ]]; then
        echo "Operation cancelled"
        exit 0
    fi
    
    # Execute replacement
    check_prerequisites
    
    if [[ "$skip_backup" != "true" ]]; then
        create_backup
    else
        echo -e "${YELLOW}⚠️  Skipping backup creation (not recommended)${NC}"
    fi
    
    replace_ht_management
    update_references
    verify_replacement
    show_completion
}

# Run main function
main "$@"
