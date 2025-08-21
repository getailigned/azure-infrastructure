#!/bin/bash
# Deploy Point-to-Site VPN Gateway for HTMA Azure infrastructure
# This script generates certificates and deploys VPN Gateway using Bicep
# 
# Usage:
#   ./deploy-vpn-gateway.sh [enable|disable]
#   
# Examples:
#   ./deploy-vpn-gateway.sh enable   # Deploy VPN Gateway
#   ./deploy-vpn-gateway.sh disable  # Deploy without VPN Gateway (default)

set -e

# Parse command line arguments
ENABLE_VPN=${1:-"disable"}

if [[ "$ENABLE_VPN" != "enable" && "$ENABLE_VPN" != "disable" ]]; then
  echo "❌ Error: Invalid argument '$ENABLE_VPN'"
  echo "Usage: $0 [enable|disable]"
  echo "  enable  - Deploy VPN Gateway (requires certificates)"
  echo "  disable - Deploy infrastructure without VPN Gateway (default)"
  exit 1
fi

# Configuration
RESOURCE_GROUP="rg-htma-dev"
LOCATION="centralus"
ENVIRONMENT="dev"
CERT_DIR="azure/certificates"

echo "🚀 DEPLOYING HTMA INFRASTRUCTURE"
echo "================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Environment: $ENVIRONMENT"
echo "VPN Gateway: $ENABLE_VPN"
echo ""

# Check if Azure CLI is logged in
echo "🔐 Checking Azure CLI authentication..."
az account show > /dev/null 2>&1 || {
  echo "❌ Error: Please login to Azure CLI first"
  echo "Run: az login"
  exit 1
}

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "✅ Using subscription: $SUBSCRIPTION_ID"
echo ""

# Handle VPN certificates based on enable flag
ROOT_CERT_DATA=""

if [[ "$ENABLE_VPN" == "enable" ]]; then
  # Generate VPN certificates if they don't exist
  if [ ! -f "$CERT_DIR/P2SRootCert.b64" ]; then
    echo "🔐 Generating VPN certificates..."
    ./azure/scripts/generate-vpn-certificates.sh
    echo ""
  else
    echo "✅ VPN certificates already exist"
    echo ""
  fi

  # Read root certificate data
  if [ ! -f "$CERT_DIR/P2SRootCert.b64" ]; then
    echo "❌ Error: Root certificate not found at $CERT_DIR/P2SRootCert.b64"
    echo "Please run the certificate generation script first"
    exit 1
  fi

  ROOT_CERT_DATA=$(cat "$CERT_DIR/P2SRootCert.b64")
  echo "✅ Root certificate loaded (${#ROOT_CERT_DATA} characters)"
  echo ""
else
  echo "ℹ️  VPN Gateway disabled - skipping certificate generation"
  ROOT_CERT_DATA="disabled"
  echo ""
fi

# Deploy infrastructure
if [[ "$ENABLE_VPN" == "enable" ]]; then
  echo "🚀 Deploying infrastructure with VPN Gateway..."
  echo "This may take 30-45 minutes to complete..."
else
  echo "🚀 Deploying infrastructure without VPN Gateway..."
  echo "This should complete in a few minutes..."
fi

DEPLOYMENT_NAME="htma-infra-$(date +%Y%m%d-%H%M%S)"

# Convert enable/disable to boolean
VPN_ENABLED="false"
if [[ "$ENABLE_VPN" == "enable" ]]; then
  VPN_ENABLED="true"
fi

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file azure/bicep/main-vpn.bicep \
  --parameters \
    environment="$ENVIRONMENT" \
    location="$LOCATION" \
    enableVpnGateway="$VPN_ENABLED" \
    vpnRootCertData="$ROOT_CERT_DATA" \
    vpnClientAddressPool="172.16.0.0/24" \
  --name "$DEPLOYMENT_NAME" \
  --verbose

# Get deployment outputs
echo ""
echo "📋 Retrieving deployment information..."

if [[ "$ENABLE_VPN" == "enable" ]]; then
  VPN_GATEWAY_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.vpnGatewayName.value" \
    --output tsv)

  VPN_GATEWAY_FQDN=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.vpnGatewayFqdn.value" \
    --output tsv)

  VPN_CLIENT_CONFIG_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query "properties.outputs.vpnClientConfigUrl.value" \
    --output tsv)

  echo ""
  echo "✅ Infrastructure with VPN Gateway deployed successfully!"
  echo "======================================================="
else
  echo ""
  echo "✅ Infrastructure deployed successfully (VPN Gateway disabled)!"
  echo "=============================================================="
fi
if [[ "$ENABLE_VPN" == "enable" ]]; then
  echo ""
  echo "📋 VPN Gateway Information:"
  echo "  Name: $VPN_GATEWAY_NAME"
  echo "  FQDN: $VPN_GATEWAY_FQDN"
  echo "  Client Config URL: $VPN_CLIENT_CONFIG_URL"
  echo ""
  echo "🔑 Certificate Files (keep secure):"
  echo "  Root Certificate: $CERT_DIR/P2SRootCert.crt"
  echo "  Client Certificate: $CERT_DIR/P2SClientCert.p12 (password: htma2025)"
  echo ""
  echo "📱 Client Setup Instructions:"
  echo "1. Install client certificate:"
  echo "   - Windows/Mac: Double-click P2SClientCert.p12 and enter password 'htma2025'"
  echo "   - Linux: Import certificate to certificate store"
  echo ""
  echo "2. Download VPN client configuration:"
  echo "   - Go to Azure Portal > Virtual Network Gateways > $VPN_GATEWAY_NAME"
  echo "   - Click 'Point-to-site configuration' > 'Download VPN client'"
  echo "   - Or use the API URL stored in Key Vault"
  echo ""
  echo "3. Install VPN client:"
  echo "   - Windows: Use Azure VPN Client from Microsoft Store"
  echo "   - Mac: Use Azure VPN Client or built-in VPN"
  echo "   - Linux: Use strongSwan or OpenVPN"
  echo ""
  echo "4. Connect and test:"
  echo "   - Connect to VPN using installed client"
  echo "   - Test database connection: psql -h htma-postgres-dev.postgres.database.azure.com"
  echo ""
  echo "🎯 Database Access After VPN Connection:"
  echo "  Host: htma-postgres-dev.postgres.database.azure.com"
  echo "  Port: 5432"
  echo "  Database: htma_platform"
  echo "  Username: htma_admin"
  echo "  Password: (stored in Key Vault: postgres-connection)"
  echo ""
  echo "⚠️  Security Notes:"
  echo "  - VPN certificates are stored in $CERT_DIR/"
  echo "  - Add azure/certificates/ to .gitignore to prevent accidental commits"
  echo "  - Client certificate password: htma2025"
  echo "  - Root certificate is valid for 10 years"
  echo "  - Client certificate is valid for 1 year"
  echo ""
  echo "🎉 Point-to-Site VPN Gateway is ready for use!"
else
  echo ""
  echo "ℹ️  VPN Gateway Configuration:"
  echo "  Status: Disabled (default)"
  echo "  To enable VPN Gateway: ./azure/scripts/deploy-vpn-gateway.sh enable"
  echo ""
  echo "📋 Current Infrastructure:"
  echo "  - Container Apps Environment"
  echo "  - PostgreSQL Flexible Server"
  echo "  - Key Vault"
  echo "  - Application Gateway"
  echo "  - Static Web App"
  echo ""
  echo "🎯 Database Access:"
  echo "  Currently configured for firewall-based access"
  echo "  Host: htma-postgres-dev.postgres.database.azure.com"
  echo "  Port: 5432"
  echo "  Database: htma_platform"
  echo "  Username: htma_admin"
  echo "  Password: (stored in Key Vault: postgres-connection)"
  echo ""
  echo "🎉 Infrastructure deployment completed successfully!"
fi
