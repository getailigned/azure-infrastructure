#!/bin/bash

# Deploy Azure Application Gateway for HT-Management
# This script deploys Application Gateway to replace Express Gateway

set -e  # Exit on any error

# Configuration
RESOURCE_GROUP="rg-htma-dev"
LOCATION="eastus"
DEPLOYMENT_NAME="htma-appgw-deployment-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DEPLOYING AZURE APPLICATION GATEWAY${NC}"
echo "========================================"
echo ""

# Check if we're in the correct directory
if [ ! -f "../bicep/main-appgw.bicep" ]; then
    echo -e "${RED}❌ Error: Please run this script from the azure/scripts directory${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 DEPLOYMENT CONFIGURATION${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""

# Validate the Bicep template
echo -e "${BLUE}🔍 VALIDATING BICEP TEMPLATE${NC}"
echo "Validating Application Gateway template..."
az deployment group validate \
    --resource-group $RESOURCE_GROUP \
    --template-file ../bicep/main-appgw.bicep \
    --parameters environment=dev \
                 appName=htma \
                 location=$LOCATION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Template validation successful${NC}"
else
    echo -e "${RED}❌ Template validation failed${NC}"
    exit 1
fi

echo ""

# Deploy the Application Gateway
echo -e "${BLUE}🚀 DEPLOYING APPLICATION GATEWAY${NC}"
echo "Starting deployment..."

az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --name $DEPLOYMENT_NAME \
    --template-file ../bicep/main-appgw.bicep \
    --parameters environment=dev \
                 appName=htma \
                 location=$LOCATION \
    --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ APPLICATION GATEWAY DEPLOYMENT SUCCESSFUL!${NC}"
    echo ""
    
    # Get deployment outputs
    echo -e "${BLUE}📊 DEPLOYMENT OUTPUTS${NC}"
    APP_GATEWAY_NAME=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query 'properties.outputs.applicationGatewayName.value' --output tsv)
    PUBLIC_IP=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query 'properties.outputs.publicIpAddress.value' --output tsv)
    PUBLIC_FQDN=$(az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME --query 'properties.outputs.publicIpFqdn.value' --output tsv)
    
    echo "Application Gateway Name: $APP_GATEWAY_NAME"
    echo "Public IP Address: $PUBLIC_IP"
    echo "Public FQDN: $PUBLIC_FQDN"
    echo ""
    
    echo -e "${GREEN}🎉 NEXT STEPS:${NC}"
    echo "1. Update DNS records to point api.dev.getailigned.com to: $PUBLIC_IP"
    echo "2. Test API endpoints through Application Gateway"
    echo "3. Update frontend configuration to use Application Gateway"
    echo "4. Consider retiring Express Gateway Container App"
    echo ""
    
else
    echo -e "${RED}❌ Application Gateway deployment failed${NC}"
    echo "Check the deployment logs for details"
    exit 1
fi

echo -e "${BLUE}🔍 CHECKING APPLICATION GATEWAY STATUS${NC}"
az network application-gateway show \
    --resource-group $RESOURCE_GROUP \
    --name $APP_GATEWAY_NAME \
    --query '{name:name,location:location,operationalState:operationalState,provisioningState:provisioningState}' \
    --output table

echo ""
echo -e "${GREEN}✅ Application Gateway deployment completed successfully!${NC}"
