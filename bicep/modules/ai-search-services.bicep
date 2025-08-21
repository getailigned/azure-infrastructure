// AI and Search Services Module - Phase 6 Implementation
// OpenAI integration, Cognitive Search, and HTA Builder infrastructure

targetScope = 'resourceGroup'

@description('Resource name prefix')
param resourceNamePrefix string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Subnet ID for private endpoints')
param subnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Key Vault name for storing secrets')
param keyVaultName string

@description('OpenAI API key from external provider')
@secure()
param openAiApiKey string

// Variables
var searchServiceName = '${resourceNamePrefix}-search'
var openAiAccountName = '${resourceNamePrefix}-openai'
var storageAccountName = replace('${resourceNamePrefix}aistorage', '-', '')
var formRecognizerName = '${resourceNamePrefix}-formrecognizer'
var textAnalyticsName = '${resourceNamePrefix}-textanalytics'
var computerVisionName = '${resourceNamePrefix}-vision'

// Azure Cognitive Search for enterprise search capabilities
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'standard' : 'basic'
  }
  properties: {
    replicaCount: environment == 'prod' ? 2 : 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      ipRules: []
      bypass: 'AzurePortal'
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      apiKeyOnly: {}
    }
    semanticSearch: environment == 'prod' ? 'standard' : 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Azure OpenAI Service for AI capabilities
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: openAiAccountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiAccountName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
    apiProperties: {
      statisticsEnabled: false
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// GPT-4o-mini deployment for primary AI model
resource gpt4oMiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiAccount
  name: 'gpt-4o-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    name: 'Standard'
    capacity: environment == 'prod' ? 100 : 50
  }
}

// GPT-3.5-turbo deployment for fallback model
resource gpt35TurboDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiAccount
  name: 'gpt-35-turbo'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0125'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    name: 'Standard'
    capacity: environment == 'prod' ? 50 : 30
  }
  dependsOn: [
    gpt4oMiniDeployment
  ]
}

// Text Embedding model for search and similarity
resource textEmbeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiAccount
  name: 'text-embedding-ada-002'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  sku: {
    name: 'Standard'
    capacity: environment == 'prod' ? 50 : 30
  }
  dependsOn: [
    gpt35TurboDeployment
  ]
}

// Storage Account for AI data and document processing
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// Blob containers for different AI workloads
resource documentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/documents'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}

resource templatesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/templates'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}

resource aiModelsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/ai-models'
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }
}

// Form Recognizer for document analysis
resource formRecognizer 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: formRecognizerName
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: {
    name: environment == 'prod' ? 'S0' : 'F0'
  }
  properties: {
    customSubDomainName: formRecognizerName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Text Analytics for language understanding
resource textAnalytics 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: textAnalyticsName
  location: location
  tags: tags
  kind: 'TextAnalytics'
  sku: {
    name: environment == 'prod' ? 'S' : 'F0'
  }
  properties: {
    customSubDomainName: textAnalyticsName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Computer Vision for image processing
resource computerVision 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: computerVisionName
  location: location
  tags: tags
  kind: 'ComputerVision'
  sku: {
    name: environment == 'prod' ? 'S1' : 'F0'
  }
  properties: {
    customSubDomainName: computerVisionName
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Private endpoints for production environment
resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (environment == 'prod') {
  name: '${searchServiceName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${searchServiceName}-pe-connection'
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}

resource openAiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (environment == 'prod') {
  name: '${openAiAccountName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${openAiAccountName}-pe-connection'
        properties: {
          privateLinkServiceId: openAiAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

// Diagnostic settings for monitoring
resource searchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'search-diagnostics'
  scope: searchService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

resource openAiDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'openai-diagnostics'
  scope: openAiAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 365 : 90
        }
      }
      {
        category: 'RequestResponse'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
      {
        category: 'Trace'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 30 : 7
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// AI service keys are stored in Key Vault by the main template

// Content Safety for AI governance
resource contentSafety 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: '${resourceNamePrefix}-contentsafety'
  location: location
  tags: tags
  kind: 'ContentSafety'
  sku: {
    name: environment == 'prod' ? 'S0' : 'F0'
  }
  properties: {
    customSubDomainName: '${resourceNamePrefix}-contentsafety'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

// Outputs
output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchServiceAdminKey string = searchService.listAdminKeys().primaryKey

output openAiAccountName string = openAiAccount.name
output openAiEndpoint string = openAiAccount.properties.endpoint
output openAiApiKey string = openAiAccount.listKeys().key1

output storageAccountName string = storageAccount.name
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'

output formRecognizerEndpoint string = formRecognizer.properties.endpoint
output textAnalyticsEndpoint string = textAnalytics.properties.endpoint
output computerVisionEndpoint string = computerVision.properties.endpoint

output gpt4oMiniDeploymentName string = gpt4oMiniDeployment.name
output gpt35TurboDeploymentName string = gpt35TurboDeployment.name
output textEmbeddingDeploymentName string = textEmbeddingDeployment.name

output contentSafetyEndpoint string = contentSafety.properties.endpoint
