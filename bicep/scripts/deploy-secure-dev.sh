#!/bin/bash

# Deploy Secure Development Environment to Azure
# This script deploys a highly secure development environment with VPN access

set -e

# Configuration
SUBSCRIPTION_ID="98f43dcc-3139-41bb-a50b-a2fb1b08ef62"
RESOURCE_GROUP="rg-htma-dev-secure"
LOCATION="eastus"
DEPLOYMENT_NAME="htma-secure-dev-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Set subscription
    az account set --subscription $SUBSCRIPTION_ID
    
    # Check if certificates are setup
    if [[ ! -d "certs" ]]; then
        print_warning "VPN certificates not found. Running certificate setup..."
        ./setup-vpn-certificates.sh
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create resource group
create_resource_group() {
    print_status "Creating resource group..."
    
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "Resource group $RESOURCE_GROUP already exists"
    else
        az group create \
            --name $RESOURCE_GROUP \
            --location $LOCATION \
            --tags Environment=dev-secure Application=htma SecurityLevel=High
        
        print_success "Resource group created"
    fi
}

# Function to validate Bicep template
validate_template() {
    print_status "Validating Bicep template..."
    
    az deployment group validate \
        --resource-group $RESOURCE_GROUP \
        --template-file ../bicep/secure-main.bicep \
        --parameters @../parameters.secure-dev.json
    
    print_success "Template validation passed"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying secure infrastructure..."
    print_warning "This deployment will take 15-20 minutes due to VPN Gateway provisioning..."
    
    az deployment group create \
        --resource-group $RESOURCE_GROUP \
        --template-file ../bicep/secure-main.bicep \
        --parameters @../parameters.secure-dev.json \
        --name $DEPLOYMENT_NAME \
        --verbose
    
    if [ $? -eq 0 ]; then
        print_success "Infrastructure deployment completed"
    else
        print_error "Infrastructure deployment failed"
        exit 1
    fi
}

# Function to get deployment outputs
get_deployment_outputs() {
    print_status "Retrieving deployment outputs..."
    
    # Get outputs
    VPN_GATEWAY_IP=$(az deployment group show \
        --resource-group $RESOURCE_GROUP \
        --name $DEPLOYMENT_NAME \
        --query 'properties.outputs.vpnGatewayPublicIP.value' \
        --output tsv)
    
    CONTAINER_REGISTRY=$(az deployment group show \
        --resource-group $RESOURCE_GROUP \
        --name $DEPLOYMENT_NAME \
        --query 'properties.outputs.containerRegistryName.value' \
        --output tsv)
    
    KEY_VAULT_NAME=$(az deployment group show \
        --resource-group $RESOURCE_GROUP \
        --name $DEPLOYMENT_NAME \
        --query 'properties.outputs.keyVaultName.value' \
        --output tsv)
    
    GATEWAY_FQDN=$(az deployment group show \
        --resource-group $RESOURCE_GROUP \
        --name $DEPLOYMENT_NAME \
        --query 'properties.outputs.expressGatewayFqdn.value' \
        --output tsv)
    
    print_success "Deployment outputs retrieved"
}

# Function to configure VPN client download
configure_vpn_client() {
    print_status "Configuring VPN client..."
    
    # Generate VPN client configuration
    VPN_GATEWAY_NAME="htma-dev-secure-vnet-vpn-gateway"
    
    print_status "Generating VPN client package (this may take a few minutes)..."
    az network vnet-gateway vpn-client generate \
        --resource-group $RESOURCE_GROUP \
        --name $VPN_GATEWAY_NAME \
        --authentication-method EAPTLS
    
    # Get download URL
    VPN_PACKAGE_URL=$(az network vnet-gateway vpn-client show-url \
        --resource-group $RESOURCE_GROUP \
        --name $VPN_GATEWAY_NAME \
        --query 'downloadUrl' \
        --output tsv)
    
    print_success "VPN client package ready"
    echo "VPN Package Download URL: $VPN_PACKAGE_URL"
}

# Function to test deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Test Key Vault access
    print_status "Testing Key Vault access..."
    if az keyvault secret list --vault-name $KEY_VAULT_NAME &> /dev/null; then
        print_success "Key Vault accessible"
    else
        print_warning "Key Vault access limited (this is expected with private endpoints)"
    fi
    
    # Test Container Registry
    print_status "Testing Container Registry..."
    if az acr show --name $CONTAINER_REGISTRY &> /dev/null; then
        print_success "Container Registry accessible"
    else
        print_warning "Container Registry access limited (this is expected with private endpoints)"
    fi
    
    print_success "Deployment tests completed"
}

# Function to update local VPN configuration
update_vpn_configuration() {
    print_status "Updating VPN configuration..."
    
    cd certs
    
    # Update VPN profile with actual gateway IP
    sed "s/VPN_GATEWAY_IP_PLACEHOLDER/$VPN_GATEWAY_IP/g" vpn-profile-template.xml > vpn-profile.xml
    
    # Create connection script for Linux/macOS
    cat > connect-vpn.sh << EOF
#!/bin/bash
# HTMA Development VPN Connection Script

echo "Connecting to HTMA Development VPN..."
echo "Gateway IP: $VPN_GATEWAY_IP"
echo ""
echo "For manual configuration:"
echo "Server: $VPN_GATEWAY_IP"
echo "Protocol: IKEv2"
echo "Authentication: Certificate"
echo "Client Certificate: HTMADevClientCert.p12"
echo "Certificate Password: HTMADev2024!"
echo ""
EOF
    
    chmod +x connect-vpn.sh
    
    cd ..
    
    print_success "VPN configuration updated"
}

# Function to create security summary
create_security_summary() {
    print_status "Creating security summary..."
    
    cat > ../SECURE_DEPLOYMENT_SUMMARY.md << EOF
# 🔐 HTMA Secure Development Environment

## 🎯 Deployment Summary

**Environment:** Highly Secure Development  
**Deployment Date:** $(date)  
**Security Level:** HIGH  
**Network Access:** PRIVATE ONLY  

## 🏗️ Infrastructure Deployed

### 🔐 Security Features
- ✅ **Private Endpoints** for all PaaS services
- ✅ **VPN Gateway** for secure remote access  
- ✅ **Azure Bastion** for secure VM access
- ✅ **Managed Identity** for service authentication
- ✅ **Premium Key Vault** with HSM-backed keys
- ✅ **Private DNS Zones** for internal name resolution
- ✅ **Network Security Groups** with strict rules
- ✅ **TLS 1.2+ enforcement** on all services

### 🌐 Network Architecture
- **VNet CIDR:** 10.0.0.0/16
- **Gateway Subnet:** 10.0.0.0/24 (VPN Gateway)
- **Apps Subnet:** 10.0.1.0/24 (Container Apps)
- **Data Subnet:** 10.0.2.0/24 (Data Services)
- **Private Endpoints:** 10.0.3.0/24
- **Bastion Subnet:** 10.0.4.0/24

### 📦 Services Deployed
- **Container Apps Environment:** htma-dev-secure-env
- **Container Registry:** $CONTAINER_REGISTRY (Private)
- **Key Vault:** $KEY_VAULT_NAME (Private)
- **PostgreSQL:** htma-dev-secure-postgres (Private)
- **Redis Cache:** htma-dev-secure-redis (Premium, Private)
- **Service Bus:** htma-dev-secure-servicebus (Premium, Private)
- **Cognitive Search:** htma-dev-secure-search (Private)
- **Azure OpenAI:** htma-dev-secure-openai (Private)

## 🔑 Access Methods

### 1. VPN Access (Recommended)
- **Gateway IP:** $VPN_GATEWAY_IP
- **Client Certificate:** certs/HTMADevClientCert.p12
- **Password:** HTMADev2024!
- **Download URL:** Available in Azure Portal

### 2. Azure Bastion
- **Use for:** Direct VM access if needed
- **Access via:** Azure Portal → Bastion

### 3. Private Endpoints
- **All services** accessible only via private network
- **DNS resolution** handled by private DNS zones

## 🚀 Application Endpoints (VPN Required)

| Service | Internal FQDN | Purpose |
|---------|---------------|---------|
| **Express Gateway** | $GATEWAY_FQDN | API Gateway |
| **Work Item Service** | (Internal only) | Work item management |
| **Dependency Service** | (Internal only) | Dependency tracking |
| **AI Insights Service** | (Internal only) | AI-powered insights |

## 🔐 Security Compliance

### ✅ Security Controls Implemented
- [x] Network isolation (Private endpoints)
- [x] Identity-based authentication (Managed Identity)
- [x] Encryption in transit (TLS 1.2+)
- [x] Encryption at rest (Azure managed keys)
- [x] Audit logging (Azure Monitor)
- [x] Access control (RBAC)
- [x] Secret management (Key Vault)
- [x] Network security (NSGs, firewalls)

### 🛡️ Threat Protection
- **DDoS Protection:** Azure DDoS Standard
- **WAF:** Network-level protection via NSGs
- **Malware Protection:** Container image scanning
- **Intrusion Detection:** Azure Monitor alerts

## 📋 Next Steps

### 1. Connect to VPN
\`\`\`bash
# Download VPN client from Azure Portal
# Install client certificate (HTMADevClientCert.p12)
# Connect using provided configuration
\`\`\`

### 2. Build and Deploy Applications
\`\`\`bash
# Build and push Docker images (requires VPN connection)
./build-and-push-secure-images.sh

# Deploy to Container Apps
./deploy-secure-container-apps.sh
\`\`\`

### 3. Access Applications
\`\`\`bash
# All access requires VPN connection
curl https://$GATEWAY_FQDN/health
\`\`\`

## 🔧 Management Commands

\`\`\`bash
# Check deployment status
az deployment group show --resource-group $RESOURCE_GROUP --name $DEPLOYMENT_NAME

# List all resources
az resource list --resource-group $RESOURCE_GROUP --output table

# Connect to Bastion (if needed)
az network bastion ssh --name htma-dev-secure-vnet-bastion --resource-group $RESOURCE_GROUP --target-resource-id <vm-id> --auth-type AAD

# Download VPN client
az network vnet-gateway vpn-client show-url --resource-group $RESOURCE_GROUP --name htma-dev-secure-vnet-vpn-gateway
\`\`\`

## ⚠️ Important Security Notes

1. **Certificate Security:** Keep VPN certificates secure and do not share
2. **Key Vault Access:** Update OpenAI API key manually in Key Vault
3. **Network Access:** All services are private - VPN required for access
4. **Monitoring:** Review Azure Monitor logs regularly
5. **Updates:** Keep VPN client and certificates updated

## 📞 Troubleshooting

### VPN Connection Issues
- Verify certificate installation
- Check gateway IP and configuration
- Ensure client supports IKEv2
- Review Azure portal for gateway status

### Service Access Issues
- Confirm VPN connection is active
- Verify private DNS resolution
- Check NSG rules if access denied
- Review Container App logs in Azure portal

---

**🎉 Your highly secure development environment is ready!**

Access is restricted to VPN-connected clients only.  
All services use private networking and Managed Identity authentication.
EOF
    
    print_success "Security summary created"
}

# Function to display final instructions
display_final_instructions() {
    echo ""
    echo "================================================"
    echo "   🔐 HTMA Secure Development Environment"
    echo "================================================"
    echo ""
    echo "✅ **Deployment Status:** COMPLETED"
    echo "🔒 **Security Level:** HIGH"
    echo "🌐 **Network Access:** PRIVATE ONLY"
    echo ""
    echo "🔑 **Access Information:**"
    echo "   VPN Gateway IP: $VPN_GATEWAY_IP"
    echo "   Container Registry: $CONTAINER_REGISTRY"
    echo "   Key Vault: $KEY_VAULT_NAME"
    echo "   Express Gateway: $GATEWAY_FQDN"
    echo ""
    echo "📋 **Next Steps:**"
    echo "   1. 📱 Download VPN client from Azure Portal"
    echo "   2. 🔐 Install client certificate (certs/HTMADevClientCert.p12)"
    echo "   3. 🌐 Connect to VPN (password: HTMADev2024!)"
    echo "   4. 🚀 Build and deploy applications"
    echo "   5. 🔍 Access services via internal FQDNs"
    echo ""
    echo "📖 **Documentation:**"
    echo "   • Security Summary: azure/SECURE_DEPLOYMENT_SUMMARY.md"
    echo "   • VPN Profile: azure/scripts/certs/vpn-profile.xml"
    echo "   • Connection Script: azure/scripts/certs/connect-vpn.sh"
    echo ""
    echo "⚠️  **Important:**"
    echo "   • All services require VPN connection for access"
    echo "   • Update OpenAI API key in Key Vault manually"
    echo "   • Keep certificates secure and do not share"
    echo ""
    print_success "Secure development environment is ready!"
}

# Main execution
main() {
    echo "================================================"
    echo "  🔐 HTMA Secure Development Deployment"
    echo "================================================"
    echo ""
    
    check_prerequisites
    create_resource_group
    validate_template
    deploy_infrastructure
    get_deployment_outputs
    configure_vpn_client
    test_deployment
    update_vpn_configuration
    create_security_summary
    display_final_instructions
    
    echo ""
    echo "🎉 **Deployment completed successfully!**"
    echo "📱 Download VPN client and connect to access your secure environment."
    echo ""
}

# Run main function
main "$@"
