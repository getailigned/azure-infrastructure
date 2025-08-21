# Point-to-Site VPN Gateway for HTMA Azure Infrastructure (Optional)

This document describes the **optional** Point-to-Site VPN Gateway setup for secure remote access to Azure VNet resources, including the PostgreSQL database.

> **Note**: VPN Gateway deployment is **disabled by default** to reduce costs and complexity. Enable only when secure database access is needed.

## 🏗️ Architecture Overview

The VPN Gateway provides secure, encrypted connectivity from client machines to the Azure Virtual Network, enabling:

- **Direct database access** to PostgreSQL without public firewall rules
- **Secure development environment** access to all VNet resources
- **Certificate-based authentication** for enterprise-grade security
- **Cross-platform support** for Windows, Mac, and Linux clients

### Network Configuration

- **VNet Address Space**: `10.0.0.0/16`
- **Gateway Subnet**: `10.0.3.0/24`
- **VPN Client Pool**: `172.16.0.0/24`
- **VPN Gateway SKU**: VpnGw1 (Generation 2)

## 🚀 Deployment

### Prerequisites

- Azure CLI installed and authenticated
- OpenSSL for certificate generation
- Appropriate Azure permissions (Network Contributor)

### Quick Deploy

```bash
# Deploy infrastructure WITHOUT VPN Gateway (default - recommended for most use cases)
./azure/scripts/deploy-vpn-gateway.sh disable

# Deploy infrastructure WITH VPN Gateway (only when secure database access needed)
./azure/scripts/deploy-vpn-gateway.sh enable
```

### Manual Deployment Steps

1. **Generate Certificates**:
   ```bash
   ./azure/scripts/generate-vpn-certificates.sh
   ```

2. **Deploy Infrastructure**:
   ```bash
   az deployment group create \
     --resource-group rg-htma-dev \
     --template-file azure/bicep/main-vpn.bicep \
     --parameters vpnRootCertData="$(cat azure/certificates/P2SRootCert.b64)"
   ```

## 🔐 Certificate Management

### Certificate Files

| File | Purpose | Security Level |
|------|---------|----------------|
| `P2SRootCert.crt` | Root certificate (public) | Public |
| `P2SRootCert.key` | Root private key | **CRITICAL** |
| `P2SRootCert.b64` | Azure configuration | Public |
| `P2SClientCert.p12` | Client certificate bundle | **SENSITIVE** |

### Security Notes

- **Root private key** (`*.key`): Never share or commit to version control
- **Client bundle** (`*.p12`): Distribute securely to authorized users only
- **Default password**: `htma2025` (change for production)
- **Certificate validity**: Root (10 years), Client (1 year)

## 📱 Client Setup

### Windows

1. **Install Certificate**:
   - Double-click `P2SClientCert.p12`
   - Enter password: `htma2025`
   - Install to "Personal" certificate store

2. **Install VPN Client**:
   - Download "Azure VPN Client" from Microsoft Store
   - Or download configuration from Azure Portal

3. **Connect**:
   - Import VPN profile
   - Click "Connect"

### macOS

1. **Install Certificate**:
   ```bash
   open azure/certificates/P2SClientCert.p12
   # Enter password: htma2025
   ```

2. **Install VPN Client**:
   - Download "Azure VPN Client" from App Store
   - Or use built-in VPN client

3. **Connect**:
   - Import VPN profile
   - Connect using certificate authentication

### Linux

1. **Install Certificate**:
   ```bash
   # Extract certificate and key
   openssl pkcs12 -in P2SClientCert.p12 -clcerts -nokeys -out client.crt
   openssl pkcs12 -in P2SClientCert.p12 -nocerts -nodes -out client.key
   ```

2. **Install strongSwan**:
   ```bash
   sudo apt install strongswan strongswan-pki
   ```

3. **Configure and Connect**:
   - Use extracted certificates with strongSwan
   - Or use NetworkManager VPN plugin

## 🎯 Database Access

### Connection Details

Once connected to VPN, access the database directly:

```bash
# Get database password from Key Vault
DB_PASSWORD=$(az keyvault secret show --vault-name htma-dev-kv --name postgres-connection --query value --output tsv | sed -n 's/.*password=\([^;]*\).*/\1/p')

# Connect to PostgreSQL
psql "host=htma-postgres-dev.postgres.database.azure.com port=5432 dbname=htma_platform user=htma_admin password=$DB_PASSWORD sslmode=require"
```

### Connection Parameters

- **Host**: `htma-postgres-dev.postgres.database.azure.com`
- **Port**: `5432`
- **Database**: `htma_platform`
- **Username**: `htma_admin`
- **Password**: Stored in Key Vault (`postgres-connection`)
- **SSL Mode**: `require`

## 🛠️ Management Operations

### Download VPN Client Configuration

```bash
# Via Azure CLI
az network vnet-gateway vpn-client generate \
  --resource-group rg-htma-dev \
  --name htma-dev-vpn-gw

# Via Azure Portal
# Navigate to Virtual Network Gateways > htma-dev-vpn-gw > Point-to-site configuration
```

### Add New Client Certificates

```bash
# Generate new client certificate
openssl genrsa -out NewClient.key 4096
openssl req -new -key NewClient.key -out NewClient.csr -subj "/C=US/ST=WA/L=Seattle/O=HTMA/OU=Development/CN=NewClient"
openssl x509 -req -in NewClient.csr -CA P2SRootCert.crt -CAkey P2SRootCert.key -CAcreateserial -out NewClient.crt -days 365

# Create PKCS#12 bundle
openssl pkcs12 -export -out NewClient.p12 -inkey NewClient.key -in NewClient.crt -certfile P2SRootCert.crt
```

### Revoke Client Certificates

```bash
# Add certificate to revocation list in Azure Portal
az network vnet-gateway revoked-cert create \
  --resource-group rg-htma-dev \
  --gateway-name htma-dev-vpn-gw \
  --name RevokedClient \
  --thumbprint <certificate-thumbprint>
```

## 🔍 Troubleshooting

### Common Issues

1. **Connection Fails**:
   - Verify certificate is installed correctly
   - Check VPN client configuration
   - Ensure Azure VPN Client is latest version

2. **Database Connection Refused**:
   - Confirm VPN is connected (`ip route` should show 10.0.0.0/16)
   - Verify PostgreSQL firewall rules allow VNet access
   - Check SSL requirements

3. **Certificate Errors**:
   - Verify certificate hasn't expired
   - Check certificate is in correct store (Personal for Windows)
   - Ensure root certificate matches Azure configuration

### Diagnostic Commands

```bash
# Check VPN connection status
ip route | grep 10.0.0.0

# Test VNet connectivity
ping 10.0.1.1

# Test database connectivity
telnet htma-postgres-dev.postgres.database.azure.com 5432
```

## 💰 Cost Optimization

### VPN Gateway Costs

- **VpnGw1**: ~$142/month (24/7 operation)
- **Public IP**: ~$3.65/month
- **Data Transfer**: Variable based on usage

### Cost-Saving Options

1. **Scheduled Operations**: Start/stop gateway for development hours only
2. **Shared Access**: Use single VPN for multiple developers
3. **Alternative**: Consider Azure Bastion for occasional access

## 🔄 Maintenance

### Regular Tasks

- **Certificate Renewal**: Client certificates expire annually
- **Security Review**: Audit connected clients quarterly
- **Cost Review**: Monitor usage and optimize SKU if needed
- **Backup**: Maintain secure backup of root certificate and key

### Automation

```bash
# Automated certificate renewal (cron job)
0 0 1 * * /path/to/renew-certificates.sh

# Cost monitoring alert
az monitor metrics alert create \
  --name vpn-gateway-cost-alert \
  --resource-group rg-htma-dev \
  --condition "Total > 200"
```

## 📚 Resources

- [Azure VPN Gateway Documentation](https://docs.microsoft.com/en-us/azure/vpn-gateway/)
- [Point-to-Site Configuration](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal)
- [Certificate Authentication](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site)

---

**Security Notice**: This setup provides production-ready security for development and administrative access. For production workloads, consider additional security measures such as conditional access policies and multi-factor authentication.
