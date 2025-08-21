// Main Bicep template for HTMA Azure infrastructure with Point-to-Site VPN Gateway
// This template extends the existing infrastructure with secure VPN connectivity

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Application name')
param appName string = 'htma'

@description('Root certificate public key data for VPN (base64 encoded) - required only when enableVpnGateway=true')
@secure()
param vpnRootCertData string = 'disabled'

@description('Enable VPN Gateway deployment - set to true only when VPN access is needed')
param enableVpnGateway bool = false

@description('VPN client address pool')
param vpnClientAddressPool string = '172.16.0.0/24'

// Common variables
var resourcePrefix = '${appName}-${environment}'
var tags = {
  Application: appName
  Environment: environment
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  LastDeployed: '2025-08-17'
}

// Existing VNet (reference)
resource existingVnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: '${resourcePrefix}-vnet'
}

// Get gateway subnet reference
var gatewaySubnetId = '${existingVnet.id}/subnets/gateway-subnet'

// Deploy VPN Gateway
module vpnGateway 'modules/vpn-gateway.bicep' = if (enableVpnGateway) {
  name: 'vpnGateway-${uniqueString(resourceGroup().id)}'
  params: {
    vpnGatewayName: '${resourcePrefix}-vpn-gw'
    location: location
    tags: tags
    environment: environment
    gatewaySubnetId: gatewaySubnetId
    vpnClientAddressPool: vpnClientAddressPool
    rootCertName: 'P2SRootCert'
    rootCertData: vpnRootCertData
    vpnGatewaySku: 'VpnGw1'
    vpnGatewayGeneration: 'Generation2'
  }
}

// Update existing Key Vault with VPN configuration
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: '${resourcePrefix}-kv'
}

// Store VPN Gateway information in Key Vault
resource vpnGatewaySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (enableVpnGateway) {
  parent: existingKeyVault
  name: 'vpn-gateway-fqdn'
  properties: {
    value: enableVpnGateway ? vpnGateway.outputs.vpnGatewayFqdn : ''
    attributes: {
      enabled: true
    }
  }
}

resource vpnClientConfigSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (enableVpnGateway) {
  parent: existingKeyVault
  name: 'vpn-client-config-url'
  properties: {
    value: enableVpnGateway ? vpnGateway.outputs.vpnClientConfigUrl : ''
    attributes: {
      enabled: true
    }
  }
}

// Outputs
@description('VPN Gateway name')
output vpnGatewayName string = enableVpnGateway ? vpnGateway.outputs.vpnGatewayName : ''

@description('VPN Gateway public IP')
output vpnGatewayPublicIp string = enableVpnGateway ? vpnGateway.outputs.vpnGatewayPublicIp : ''

@description('VPN Gateway FQDN')
output vpnGatewayFqdn string = enableVpnGateway ? vpnGateway.outputs.vpnGatewayFqdn : ''

@description('VPN client configuration download URL')
output vpnClientConfigUrl string = enableVpnGateway ? vpnGateway.outputs.vpnClientConfigUrl : ''

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('VPN client address pool')
output vpnClientAddressPool string = vpnClientAddressPool

@description('Instructions for VPN setup')
output setupInstructions string = '''
VPN Gateway Deployment Complete!

Next Steps:
1. Generate and install client certificates on your machine
2. Download VPN client configuration from Azure Portal or use the URL in Key Vault
3. Install Azure VPN Client or use built-in VPN client
4. Connect to VPN and access database at private IP

Database Access:
- PostgreSQL will be accessible at its private endpoint within the VNet
- Use standard PostgreSQL connection strings once connected to VPN
- All VNet resources (Container Apps, databases) are accessible through VPN

Configuration stored in Key Vault:
- vpn-gateway-fqdn: VPN Gateway FQDN
- vpn-client-config-url: Download URL for VPN client configuration
'''
