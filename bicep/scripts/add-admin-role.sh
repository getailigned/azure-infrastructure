#!/bin/bash

# Azure CLI script to add admin role to user
# Usage: ./add-admin-role.sh user@domain.com

USER_EMAIL="$1"
ROLE_TYPE="${2:-Application Administrator}"

if [ -z "$USER_EMAIL" ]; then
    echo "❌ Usage: $0 <user-email> [role-type]"
    echo "   Example: $0 admin@company.com"
    echo "   Example: $0 admin@company.com \"Global Administrator\""
    exit 1
fi

echo "🔐 Adding admin role to Azure AD user"
echo "User: $USER_EMAIL"
echo "Role: $ROLE_TYPE"
echo ""

# Check if logged in to Azure
echo "📋 Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "🔑 Please log in to Azure CLI first:"
    echo "   az login"
    exit 1
fi

# Get current tenant info
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "✅ Connected to tenant: $TENANT_ID"

# Get user object ID
echo "👤 Looking up user: $USER_EMAIL"
USER_OBJECT_ID=$(az ad user show --id "$USER_EMAIL" --query objectId -o tsv 2>/dev/null)

if [ -z "$USER_OBJECT_ID" ]; then
    echo "❌ User not found: $USER_EMAIL"
    echo "   Make sure the user exists in your Azure AD tenant"
    exit 1
fi

echo "✅ Found user with Object ID: $USER_OBJECT_ID"

# Get role definition
echo "🔍 Looking up role: $ROLE_TYPE"
ROLE_DEFINITION_ID=$(az ad sp list --filter "appDisplayName eq 'Microsoft.DirectoryServices'" --query "[0].appRoles[?displayName=='$ROLE_TYPE'].id" -o tsv 2>/dev/null)

if [ -z "$ROLE_DEFINITION_ID" ]; then
    # Try common role mappings
    case "$ROLE_TYPE" in
        "Application Administrator")
            ROLE_TEMPLATE_ID="9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
            ;;
        "Global Administrator")
            ROLE_TEMPLATE_ID="62e90394-69f5-4237-9190-012177145e10"
            ;;
        *)
            echo "❌ Role not found: $ROLE_TYPE"
            echo "   Common roles: 'Application Administrator', 'Global Administrator'"
            exit 1
            ;;
    esac
    
    echo "📝 Using role template ID: $ROLE_TEMPLATE_ID"
    
    # Assign directory role
    echo "🔧 Assigning directory role..."
    az rest --method POST \
        --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
        --body "{\"@odata.type\": \"#microsoft.graph.unifiedRoleAssignment\", \"roleDefinitionId\": \"$ROLE_TEMPLATE_ID\", \"principalId\": \"$USER_OBJECT_ID\", \"directoryScopeId\": \"/\"}" \
        --headers "Content-Type=application/json"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully assigned $ROLE_TYPE role to $USER_EMAIL"
    else
        echo "❌ Failed to assign role"
        exit 1
    fi
else
    echo "✅ Found role definition ID: $ROLE_DEFINITION_ID"
fi

echo ""
echo "🎉 Admin role assignment completed!"
echo ""
echo "📝 User Details:"
echo "   Email: $USER_EMAIL"
echo "   Object ID: $USER_OBJECT_ID"
echo "   Role: $ROLE_TYPE"
echo ""
echo "✨ The user can now:"
echo "   ✓ Access admin functionality in HT-Management"
echo "   ✓ Impersonate different user roles for testing"
echo "   ✓ View admin testing indicators in the dashboard"
echo ""
echo "🔄 Next Steps:"
echo "   1. Have the user log out and log back into the application"
echo "   2. They should see the Role Switcher in the dashboard header"
echo "   3. They can now test different roles and permissions"
