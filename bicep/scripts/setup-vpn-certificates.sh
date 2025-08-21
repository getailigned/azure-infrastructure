#!/bin/bash

# Setup VPN Certificates for Secure Development Environment
# This script creates the necessary certificates for Point-to-Site VPN

set -e

# Configuration
CERT_NAME="HTMADevRootCert"
CLIENT_CERT_NAME="HTMADevClientCert"
RESOURCE_GROUP="rg-htma-dev-secure"
KEY_VAULT_NAME="htma-dev-secure-kv"

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
    
    # Check if OpenSSL is installed
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi
    
    # Check if Azure CLI is installed and logged in
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create certificates directory
create_cert_directory() {
    print_status "Creating certificates directory..."
    
    mkdir -p certs
    cd certs
    
    print_success "Certificates directory created"
}

# Function to generate root certificate
generate_root_certificate() {
    print_status "Generating root certificate..."
    
    # Generate root private key
    openssl genrsa -out ${CERT_NAME}.key 4096
    
    # Generate root certificate
    openssl req -new -x509 -days 3650 -key ${CERT_NAME}.key -out ${CERT_NAME}.crt -subj "/C=US/ST=WA/L=Seattle/O=HTMA/OU=Development/CN=HTMA Development Root CA"
    
    # Convert to base64 (required for Azure)
    ROOT_CERT_DATA=$(openssl x509 -in ${CERT_NAME}.crt -outform der | base64 -w 0)
    
    print_success "Root certificate generated"
    echo "Root certificate data (base64): ${ROOT_CERT_DATA:0:50}..."
}

# Function to generate client certificate
generate_client_certificate() {
    print_status "Generating client certificate..."
    
    # Generate client private key
    openssl genrsa -out ${CLIENT_CERT_NAME}.key 4096
    
    # Generate client certificate signing request
    openssl req -new -key ${CLIENT_CERT_NAME}.key -out ${CLIENT_CERT_NAME}.csr -subj "/C=US/ST=WA/L=Seattle/O=HTMA/OU=Development/CN=HTMA Development Client"
    
    # Sign client certificate with root certificate
    openssl x509 -req -days 3650 -in ${CLIENT_CERT_NAME}.csr -CA ${CERT_NAME}.crt -CAkey ${CERT_NAME}.key -CAcreateserial -out ${CLIENT_CERT_NAME}.crt
    
    # Create PKCS#12 file for client (includes private key and certificate)
    openssl pkcs12 -export -out ${CLIENT_CERT_NAME}.p12 -inkey ${CLIENT_CERT_NAME}.key -in ${CLIENT_CERT_NAME}.crt -certfile ${CERT_NAME}.crt -password pass:HTMADev2024!
    
    print_success "Client certificate generated"
}

# Function to store certificates in Key Vault
store_certificates_in_keyvault() {
    print_status "Storing certificates in Key Vault..."
    
    # Check if Key Vault exists, create if not
    if ! az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
        print_status "Creating Key Vault for certificates..."
        az keyvault create \
            --name $KEY_VAULT_NAME \
            --resource-group $RESOURCE_GROUP \
            --location eastus \
            --sku premium
    fi
    
    # Store root certificate data
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "vpn-client-cert" \
        --value "$ROOT_CERT_DATA"
    
    # Store PostgreSQL admin password
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "postgres-admin-password" \
        --value "$POSTGRES_PASSWORD"
    
    # Store MongoDB admin password
    MONGO_PASSWORD=$(openssl rand -base64 32)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "mongo-admin-password" \
        --value "$MONGO_PASSWORD"
    
    # Store OpenAI API key placeholder (will be updated manually)
    az keyvault secret set \
        --vault-name $KEY_VAULT_NAME \
        --name "openai-api-key" \
        --value "PLACEHOLDER_UPDATE_MANUALLY"
    
    print_success "Certificates and secrets stored in Key Vault"
}

# Function to create VPN profile
create_vpn_profile() {
    print_status "Creating VPN profile template..."
    
    cat > vpn-profile-template.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<VpnProfile>
  <ProfileName>HTMA Development VPN</ProfileName>
  <ProfileDescription>Secure access to HTMA development environment</ProfileDescription>
  <VpnStrategy>IkeV2</VpnStrategy>
  <Authentication>
    <MachineMethod>Certificate</MachineMethod>
    <Certificate>
      <details>
        <ServerValidation>
          <ServerNames></ServerNames>
          <DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation>
        </ServerValidation>
      </details>
    </Certificate>
  </Authentication>
  <ServerList>
    <Server>
      <Address>VPN_GATEWAY_IP_PLACEHOLDER</Address>
      <Description>HTMA Development VPN Gateway</Description>
    </Server>
  </ServerList>
  <DomainNameInformation>
    <DomainName>htma-dev-secure.local</DomainName>
    <DnsServers>168.63.129.16</DnsServers>
  </DomainNameInformation>
</VpnProfile>
EOF
    
    print_success "VPN profile template created"
}

# Function to display connection instructions
display_connection_instructions() {
    print_status "VPN Connection Instructions"
    
    echo ""
    echo "================================================"
    echo "   HTMA Development VPN Setup Complete"
    echo "================================================"
    echo ""
    echo "📋 Files created:"
    echo "   • ${CERT_NAME}.crt          - Root certificate"
    echo "   • ${CERT_NAME}.key          - Root private key"
    echo "   • ${CLIENT_CERT_NAME}.crt   - Client certificate"
    echo "   • ${CLIENT_CERT_NAME}.key   - Client private key"
    echo "   • ${CLIENT_CERT_NAME}.p12   - Client certificate bundle (password: HTMADev2024!)"
    echo "   • vpn-profile-template.xml  - VPN profile template"
    echo ""
    echo "🔐 Certificates stored in Key Vault: $KEY_VAULT_NAME"
    echo ""
    echo "📱 Client Setup Instructions:"
    echo ""
    echo "For Windows:"
    echo "1. Import ${CLIENT_CERT_NAME}.p12 to Personal certificate store"
    echo "2. Download VPN client from Azure Portal after deployment"
    echo "3. Install and connect using the client certificate"
    echo ""
    echo "For macOS:"
    echo "1. Double-click ${CLIENT_CERT_NAME}.p12 to install in Keychain"
    echo "2. Download VPN client from Azure Portal after deployment"
    echo "3. Configure IKEv2 connection with certificate authentication"
    echo ""
    echo "For Linux:"
    echo "1. Install strongSwan: sudo apt-get install strongswan"
    echo "2. Copy certificates to /etc/ipsec.d/certs/"
    echo "3. Configure strongSwan with provided configuration"
    echo ""
    echo "⚠️  Important:"
    echo "   • Keep certificates secure and do not share"
    echo "   • Update OpenAI API key in Key Vault manually"
    echo "   • VPN Gateway IP will be available after infrastructure deployment"
    echo ""
}

# Main execution
main() {
    echo "================================================"
    echo "  HTMA Development VPN Certificate Setup"
    echo "================================================"
    echo ""
    
    check_prerequisites
    create_cert_directory
    generate_root_certificate
    generate_client_certificate
    store_certificates_in_keyvault
    create_vpn_profile
    display_connection_instructions
    
    print_success "VPN certificate setup completed successfully!"
    
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Deploy secure infrastructure: ./deploy-secure-dev.sh"
    echo "2. Update OpenAI API key in Key Vault"
    echo "3. Download VPN client from Azure Portal"
    echo "4. Connect to VPN and access services privately"
    echo ""
}

# Check if running from correct directory
if [[ ! -f "../bicep/secure-main.bicep" ]]; then
    print_error "Please run this script from the azure/scripts directory"
    exit 1
fi

# Run main function
main "$@"
