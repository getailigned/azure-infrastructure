// Secure Data services module for HT-Management
// Creates PostgreSQL, Cosmos DB, Redis, Service Bus, and Cognitive Search with security hardening

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Data subnet ID for private endpoints')
param subnetId string

@description('PostgreSQL administrator login')
@secure()
param postgresAdminLogin string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('MongoDB admin username')
@secure()
param mongoAdminUsername string

@description('MongoDB admin password')
@secure()
param mongoAdminPassword string

// PostgreSQL Flexible Server with security hardening
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: '${resourceNamePrefix}-postgres'
  location: location
  tags: tags
  sku: {
    name: 'Standard_B2s'  // 2 vCPU, 4GB RAM for secure dev
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    version: '15'
    storage: {
      storageSizeGB: 64
      autoGrow: 'Enabled'
      type: 'Premium_LRS'  // Premium storage for better security
    }
    backup: {
      backupRetentionDays: 30  // Extended retention
      geoRedundantBackup: 'Enabled'  // Geographic backup
    }
    highAvailability: {
      mode: 'ZoneRedundant'  // High availability for security
      standbyAvailabilityZone: '2'
    }
    network: {
      publicNetworkAccess: 'Disabled'  // SECURE: No public access
      delegatedSubnetResourceId: subnetId
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
  }
}

// PostgreSQL database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgresServer
  name: 'htma'
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL server configuration for security
resource postgresConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = [
  for config in [
    { name: 'ssl_min_protocol_version', value: 'TLSv1.2' }
    { name: 'log_connections', value: 'on' }
    { name: 'log_disconnections', value: 'on' }
    { name: 'log_checkpoints', value: 'on' }
    { name: 'log_statement', value: 'all' }
    { name: 'log_min_duration_statement', value: '1000' }
  ]: {
    parent: postgresServer
    name: config.name
    properties: {
      value: config.value
      source: 'user-override'
    }
  }
]

// Cosmos DB Account (MongoDB API) with security hardening
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' = {
  name: '${resourceNamePrefix}-cosmos'
  location: location
  tags: tags
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableMongo'
      }
      {
        name: 'MongoDBv3.4'
      }
      {
        name: 'mongoEnableDocLevelTTL'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true  // Zone redundancy for security
      }
    ]
    backupPolicy: {
      type: 'Continuous'  // Point-in-time restore
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    }
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: [
      {
        id: subnetId
        ignoreMissingVNetServiceEndpoint: false
      }
    ]
    ipRules: []  // No IP allowlist
    disableKeyBasedMetadataWriteAccess: true
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false
    networkAclBypass: 'None'
    networkAclBypassResourceIds: []
  }
}

// Cosmos DB MongoDB database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-09-15' = {
  parent: cosmosAccount
  name: 'htma'
  properties: {
    resource: {
      id: 'htma'
    }
    options: {
      throughput: 400  // Minimal throughput for dev
    }
  }
}

// Redis Cache with security hardening
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: '${resourceNamePrefix}-redis'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Premium'  // Premium tier for VNet integration
      family: 'P'
      capacity: 1  // P1 - 6GB cache
    }
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
      'notify-keyspace-events': 'Ex'
      'rdb-backup-enabled': 'true'
      'rdb-backup-frequency': '60'  // Hourly backups
      'rdb-storage-connection-string': ''  // Will be set separately
    }
    enableNonSslPort: false  // SECURE: SSL only
    minimumTlsVersion: '1.2'  // SECURE: TLS 1.2 minimum
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    redisVersion: '6'
    subnetId: subnetId
    staticIP: '10.0.2.10'  // Static IP in data subnet
  }
}

// Service Bus Namespace with security hardening
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: '${resourceNamePrefix}-servicebus'
  location: location
  tags: tags
  sku: {
    name: 'Premium'  // Premium tier for VNet integration
    tier: 'Premium'
    capacity: 1
  }
  properties: {
    minimumTlsVersion: '1.2'  // SECURE: TLS 1.2 minimum
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    disableLocalAuth: false  // Keep SAS for dev, disable in prod
    zoneRedundant: true  // Zone redundancy
    encryption: {
      keySource: 'Microsoft.ServiceBus'  // Can be upgraded to customer-managed
    }
  }
}

// Service Bus Network Rule Set
resource serviceBusNetworkRuleSet 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'default'
  properties: {
    defaultAction: 'Deny'  // SECURE: Deny by default
    virtualNetworkRules: [
      {
        subnet: {
          id: subnetId
        }
        ignoreMissingVnetServiceEndpoint: false
      }
    ]
    ipRules: []  // No IP allowlist
    trustedServiceAccessEnabled: true
  }
}

// Service Bus Queues
resource workItemEventsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'work-item-events'
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'  // 14 days
    lockDuration: 'PT1M'  // 1 minute
    maxDeliveryCount: 10
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    deadLetteringOnMessageExpiration: true
    enablePartitioning: false
  }
}

resource dependencyEventsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'dependency-events'
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
    lockDuration: 'PT1M'
    maxDeliveryCount: 10
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    deadLetteringOnMessageExpiration: true
    enablePartitioning: false
  }
}

resource aiInsightsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'ai-insights-requests'
  properties: {
    maxSizeInMegabytes: 2048  // Larger for AI requests
    defaultMessageTimeToLive: 'P7D'  // 7 days
    lockDuration: 'PT5M'  // 5 minutes for AI processing
    maxDeliveryCount: 5
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    deadLetteringOnMessageExpiration: true
    enablePartitioning: false
  }
}

// Cognitive Search with security hardening
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${resourceNamePrefix}-search'
  location: location
  tags: tags
  sku: {
    name: 'standard'  // Standard tier for VNet integration
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'  // SECURE: No public access
    networkRuleSet: {
      ipRules: []  // No IP allowlist
    }
    disabledDataExfiltrationOptions: [
      'All'  // Prevent data exfiltration
    ]
    authOptions: {
      apiKeyOnly: false  // Enable Azure AD auth
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
    semanticSearch: 'free'
    encryptionWithCmk: {
      enforcement: 'Unspecified'  // Can be upgraded to customer-managed
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Azure OpenAI Service with security hardening
resource openAIService 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: '${resourceNamePrefix}-openai'
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${resourceNamePrefix}-openai'
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    networkAcls: {
      defaultAction: 'Deny'  // SECURE: Deny by default
      virtualNetworkRules: [
        {
          id: subnetId
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
      ipRules: []  // No IP allowlist
    }
    disableLocalAuth: false  // Keep API key for dev, disable in prod
    restrictOutboundNetworkAccess: true
    allowedFqdnList: []
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// OpenAI model deployments
resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAIService
  name: 'gpt-4o-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: 10
  }
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAIService
  name: 'text-embedding-3-large'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: 10
  }
}

// Outputs
output postgresServerId string = postgresServer.id
output postgresServerName string = postgresServer.name
output postgresConnectionString string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=htma;Username=${postgresAdminLogin};Password=${postgresAdminPassword};SSL Mode=Require;'

output cosmosAccountId string = cosmosAccount.id
output cosmosAccountName string = cosmosAccount.name
output cosmosConnectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString

output redisId string = redisCache.id
output redisName string = redisCache.name
output redisConnectionString string = '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'

output serviceBusId string = serviceBusNamespace.id
output serviceBusNamespace string = serviceBusNamespace.name
output serviceBusConnectionString string = serviceBusNamespace.listKeys('RootManageSharedAccessKey').primaryConnectionString

output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchAdminKey string = searchService.listAdminKeys().primaryKey

output openAIServiceId string = openAIService.id
output openAIEndpoint string = openAIService.properties.endpoint
output openAIApiKey string = openAIService.listKeys().key1
