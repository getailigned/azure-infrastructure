// Data services module for HT-Management
// Creates PostgreSQL, Cosmos DB, Redis, Service Bus, and Cognitive Search

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

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: '${resourceNamePrefix}-postgres'
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'  // Dev: 1 vCPU, 2GB RAM
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    version: '15'
    storage: {
      storageSizeGB: 32  // Dev: 32GB
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'  // Dev: No HA
    }
    network: {
      publicNetworkAccess: 'Enabled'  // Dev: Allow public access with firewall
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

// PostgreSQL firewall rule for development
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Cosmos DB Account (MongoDB API)
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
        name: 'EnableServerless'  // Dev: Serverless for cost savings
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    publicNetworkAccess: 'Enabled'  // Dev: Allow public access
    networkAclBypass: 'AzureServices'
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
  }
}

// Redis Cache
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: '${resourceNamePrefix}-redis'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: 0  // Dev: C0 (250MB)
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'  // Dev: Allow public access
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// Service Bus Namespace (replaces RabbitMQ)
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: '${resourceNamePrefix}-servicebus'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'  // Dev: Allow public access
    minimumTlsVersion: '1.2'
  }
}

// Service Bus Queues for microservice communication
var queueNames = [
  'work-item-events'
  'dependency-events'
  'ai-insights-requests'
  'notifications'
  'audit-events'
]

resource serviceBusQueues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [for queueName in queueNames: {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'  // 14 days
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enablePartitioning: false
    maxDeliveryCount: 10
  }
}]

// Service Bus Topics for event broadcasting
var topicNames = [
  'system-events'
  'user-events'
  'analytics-events'
]

resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = [for topicName in topicNames: {
  parent: serviceBusNamespace
  name: topicName
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enablePartitioning: false
  }
}]

// Cognitive Search Service (replaces Elasticsearch)
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${resourceNamePrefix}-search'
  location: location
  tags: tags
  sku: {
    name: 'basic'  // Dev: Basic tier
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'  // Dev: Allow public access
    networkRuleSet: {
      ipRules: []
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      apiKeyOnly: {}
    }
  }
}

// Azure OpenAI Service
resource openAiService 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: '${resourceNamePrefix}-openai'
  location: 'eastus'  // OpenAI service availability
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${resourceNamePrefix}-openai'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// OpenAI Model Deployments
resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiService
  name: 'gpt-4o-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    raiPolicyName: 'Microsoft.Default'
    sku: {
      name: 'Standard'
      capacity: 10  // Dev: 10K TPM
    }
  }
}

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiService
  name: 'text-embedding-3-large'
  dependsOn: [gpt4oMiniDeployment]  // Serial deployment required
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
    raiPolicyName: 'Microsoft.Default'
    sku: {
      name: 'Standard'
      capacity: 10  // Dev: 10K TPM
    }
  }
}

// Outputs
output postgresServerName string = postgresServer.name
output postgresConnectionString string = 'Server=${postgresServer.properties.fullyQualifiedDomainName};Database=htma;Port=5432;User Id=${postgresAdminLogin};Password=${postgresAdminPassword};Ssl Mode=Require;'

output cosmosAccountName string = cosmosAccount.name
output cosmosConnectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString

output redisName string = redisCache.name
output redisConnectionString string = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'

output serviceBusNamespace string = serviceBusNamespace.name
output serviceBusConnectionString string = serviceBusNamespace.listKeys().primaryConnectionString

output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchAdminKey string = searchService.listAdminKeys().primaryKey

output openAiServiceName string = openAiService.name
output openAiEndpoint string = openAiService.properties.endpoint
output openAiApiKey string = openAiService.listKeys().key1
