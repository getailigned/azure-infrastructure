// Private Endpoints module for HT-Management
// Creates private endpoints for all PaaS services

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Private endpoints subnet ID')
param privateEndpointsSubnetId string

@description('Key Vault resource ID')
param keyVaultId string

@description('PostgreSQL server resource ID')
param postgresServerId string

@description('Redis cache resource ID')
param redisId string

@description('Service Bus namespace resource ID')
param serviceBusId string

@description('Cognitive Search service resource ID')
param searchServiceId string

@description('Cosmos DB account resource ID')
param cosmosAccountId string

@description('Container Registry resource ID')
param containerRegistryId string

// Private DNS Zone IDs
@description('Key Vault private DNS zone ID')
param keyVaultPrivateDnsZoneId string

@description('PostgreSQL private DNS zone ID')
param postgresPrivateDnsZoneId string

@description('Redis private DNS zone ID')
param redisPrivateDnsZoneId string

@description('Service Bus private DNS zone ID')
param serviceBusPrivateDnsZoneId string

@description('Search private DNS zone ID')
param searchPrivateDnsZoneId string

// Key Vault Private Endpoint
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-kv-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-kv-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZoneId
        }
      }
    ]
  }
}

// PostgreSQL Private Endpoint
resource postgresPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-postgres-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-postgres-connection'
        properties: {
          privateLinkServiceId: postgresServerId
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
  }
}

resource postgresPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: postgresPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-postgres-database-azure-com'
        properties: {
          privateDnsZoneId: postgresPrivateDnsZoneId
        }
      }
    ]
  }
}

// Redis Private Endpoint
resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-redis-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-redis-connection'
        properties: {
          privateLinkServiceId: redisId
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

resource redisPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: redisPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-redis-cache-windows-net'
        properties: {
          privateDnsZoneId: redisPrivateDnsZoneId
        }
      }
    ]
  }
}

// Service Bus Private Endpoint
resource serviceBusPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-servicebus-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-servicebus-connection'
        properties: {
          privateLinkServiceId: serviceBusId
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
}

resource serviceBusPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: serviceBusPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-servicebus-windows-net'
        properties: {
          privateDnsZoneId: serviceBusPrivateDnsZoneId
        }
      }
    ]
  }
}

// Cognitive Search Private Endpoint
resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-search-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-search-connection'
        properties: {
          privateLinkServiceId: searchServiceId
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource searchPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: searchPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-search-windows-net'
        properties: {
          privateDnsZoneId: searchPrivateDnsZoneId
        }
      }
    ]
  }
}

// Cosmos DB Private Endpoint
resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-cosmos-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-cosmos-connection'
        properties: {
          privateLinkServiceId: cosmosAccountId
          groupIds: [
            'MongoDB'
          ]
        }
      }
    ]
  }
}

// Container Registry Private Endpoint
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${resourceNamePrefix}-acr-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceNamePrefix}-acr-connection'
        properties: {
          privateLinkServiceId: containerRegistryId
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Outputs
output keyVaultPrivateEndpointId string = keyVaultPrivateEndpoint.id
output postgresPrivateEndpointId string = postgresPrivateEndpoint.id
output redisPrivateEndpointId string = redisPrivateEndpoint.id
output serviceBusPrivateEndpointId string = serviceBusPrivateEndpoint.id
output searchPrivateEndpointId string = searchPrivateEndpoint.id
output cosmosPrivateEndpointId string = cosmosPrivateEndpoint.id
output acrPrivateEndpointId string = acrPrivateEndpoint.id
