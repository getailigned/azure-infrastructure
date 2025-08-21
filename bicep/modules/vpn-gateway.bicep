// VPN Gateway module for Point-to-Site connectivity
// Enables secure remote access to Azure VNet resources

@description('VPN Gateway name')
param vpnGatewayName string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

// Virtual network resource ID (passed for reference but not directly used in this template)

@description('Gateway subnet resource ID')
param gatewaySubnetId string

@description('VPN client address pool')
param vpnClientAddressPool string = '172.16.0.0/24'

@description('Root certificate name for P2S VPN')
param rootCertName string = 'P2SRootCert'

@description('Root certificate public key data (base64 encoded)')
param rootCertData string

@description('VPN Gateway SKU')
@allowed(['VpnGw1', 'VpnGw2', 'VpnGw3', 'VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ'])
param vpnGatewaySku string = 'VpnGw1'

@description('VPN Gateway generation')
@allowed(['Generation1', 'Generation2'])
param vpnGatewayGeneration string = 'Generation2'

// Public IP for VPN Gateway
resource vpnGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${vpnGatewayName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${vpnGatewayName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// VPN Gateway
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: vpnGatewayName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: vpnGatewayPublicIp.id
          }
        }
      }
    ]
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
    vpnGatewayGeneration: vpnGatewayGeneration
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      vpnClientProtocols: [
        'SSTP'
        'IkeV2'
      ]
      vpnAuthenticationTypes: [
        'Certificate'
      ]
      vpnClientRootCertificates: [
        {
          name: rootCertName
          properties: {
            publicCertData: rootCertData
          }
        }
      ]
    }
  }
}

// Network Security Group rules for VPN Gateway
resource vpnGatewayNsgRules 'Microsoft.Network/networkSecurityGroups/securityRules@2023-09-01' = {
  name: 'AllowVpnGateway'
  parent: vpnGatewayNsg
  properties: {
    description: 'Allow VPN Gateway traffic'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'GatewayManager'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 100
    direction: 'Inbound'
  }
}

// Reference to existing NSG (will be created in networking module)
resource vpnGatewayNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' existing = {
  name: '${environment}-gateway-nsg'
}

// Custom route table for VPN clients
resource vpnRouteTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: '${vpnGatewayName}-routes'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'VNetLocal'
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VnetLocal'
        }
      }
      {
        name: 'Internet'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

@description('VPN Gateway resource ID')
output vpnGatewayId string = vpnGateway.id

@description('VPN Gateway name')
output vpnGatewayName string = vpnGateway.name

@description('VPN Gateway public IP address')
output vpnGatewayPublicIp string = vpnGatewayPublicIp.properties.ipAddress

@description('VPN Gateway FQDN')
output vpnGatewayFqdn string = vpnGatewayPublicIp.properties.dnsSettings.fqdn

@description('VPN client configuration URL')
output vpnClientConfigUrl string = '${az.environment().resourceManager}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/virtualNetworkGateways/${vpnGateway.name}/generatevpnclientpackage?api-version=2023-09-01'

@description('VPN Gateway route table ID')
output routeTableId string = vpnRouteTable.id
