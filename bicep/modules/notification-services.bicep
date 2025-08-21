// Notification Services Module - Email and Communication Infrastructure
// Communication Services, Event Grid, and Storage for notification system

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

@description('Google Workspace OAuth2 Client ID')
@secure()
param googleClientId string

@description('Google Workspace OAuth2 Client Secret')
@secure()
param googleClientSecret string

@description('Google Workspace Refresh Token')
@secure()
param googleRefreshToken string

@description('Notification sender email address')
param notificationFromEmail string

@description('Notification sender name')
param notificationFromName string = 'HTMA Platform'

// Variables
var communicationServiceName = '${resourceNamePrefix}-communication'
var emailServiceName = '${resourceNamePrefix}-email'
var eventGridTopicName = '${resourceNamePrefix}-notifications'
var storageAccountName = replace('${resourceNamePrefix}notif', '-', '')
var appInsightsName = '${resourceNamePrefix}-notification-insights'

// Azure Communication Services for backup email delivery
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: communicationServiceName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: 'United States'
    linkedDomains: []
  }
}

// Email Communication Service for backup email delivery
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: emailServiceName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: 'United States'
  }
}

// Azure managed domain for email service
resource emailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: 'azuremanageddomain'
  location: 'global'
  properties: {
    domainManagement: 'AzureManaged'
  }
}

// Link Communication Service to Email Service
resource communicationEmailLink 'Microsoft.Communication/communicationServices/emailDomains@2023-04-01' = {
  parent: communicationService
  name: emailDomain.name
  properties: {
    emailDomainResourceId: emailDomain.id
  }
}

// Azure Event Grid for notification event distribution
resource notificationEventGrid 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: eventGridTopicName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Enabled'
    dataResidencyBoundary: 'WithinRegion'
  }
}

// Azure Storage Account for notification templates and attachments
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
    }
  }
}

// Blob container for email templates
resource templateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/email-templates'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'email-templates'
      environment: environment
    }
  }
}

// Blob container for email attachments
resource attachmentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/email-attachments'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'email-attachments'
      environment: environment
    }
  }
}

// Application Insights for notification service monitoring
resource notificationAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Get reference to existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Google Workspace OAuth2 secrets
resource googleClientIdSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'google-client-id'
  properties: {
    value: googleClientId
    attributes: {
      enabled: true
    }
    contentType: 'Google Workspace OAuth2 Client ID'
  }
}

resource googleClientSecretSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'google-client-secret'
  properties: {
    value: googleClientSecret
    attributes: {
      enabled: true
    }
    contentType: 'Google Workspace OAuth2 Client Secret'
  }
}

resource googleRefreshTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'google-refresh-token'
  properties: {
    value: googleRefreshToken
    attributes: {
      enabled: true
    }
    contentType: 'Google Workspace OAuth2 Refresh Token'
  }
}

// Notification configuration secrets
resource notificationFromEmailSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'notification-from-email'
  properties: {
    value: notificationFromEmail
    attributes: {
      enabled: true
    }
    contentType: 'Notification sender email address'
  }
}

resource notificationFromNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'notification-from-name'
  properties: {
    value: notificationFromName
    attributes: {
      enabled: true
    }
    contentType: 'Notification sender name'
  }
}

// Azure service connection string secrets
resource communicationConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'communication-connection-string'
  properties: {
    value: communicationService.listKeys().primaryConnectionString
    attributes: {
      enabled: true
    }
    contentType: 'Azure Communication Services connection string'
  }
}

resource storageConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'notification-storage-connection-string'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
    attributes: {
      enabled: true
    }
    contentType: 'Notification storage account connection string'
  }
}

resource eventGridAccessKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'notification-eventgrid-access-key'
  properties: {
    value: notificationEventGrid.listKeys().key1
    attributes: {
      enabled: true
    }
    contentType: 'Event Grid access key for notifications'
  }
}

// Private endpoint for storage account (production only)
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (environment == 'prod') {
  name: '${storageAccount.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccount.name}-pe-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (environment == 'prod') {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-core-windows-net'
        properties: {
          privateDnsZoneId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
        }
      }
    ]
  }
}

// Diagnostic settings for monitoring and logging
resource communicationDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: communicationService
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource eventGridDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: notificationEventGrid
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Communication Services outputs
output communicationServiceName string = communicationService.name
output communicationServiceId string = communicationService.id
output communicationConnectionString string = communicationService.listKeys().primaryConnectionString
output emailServiceName string = emailService.name
output emailServiceId string = emailService.id
output emailDomainName string = emailDomain.name

// Event Grid outputs
output eventGridTopicName string = notificationEventGrid.name
output eventGridTopicId string = notificationEventGrid.id
output eventGridEndpoint string = notificationEventGrid.properties.endpoint

// Storage Account outputs
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output storageConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'

// Application Insights outputs
output notificationAppInsightsName string = notificationAppInsights.name
output notificationAppInsightsId string = notificationAppInsights.id
output notificationAppInsightsInstrumentationKey string = notificationAppInsights.properties.InstrumentationKey
output notificationAppInsightsConnectionString string = notificationAppInsights.properties.ConnectionString

// Key Vault secret URIs for Google Workspace integration
output googleClientIdSecretUri string = googleClientIdSecret.properties.secretUri
output googleClientSecretSecretUri string = googleClientSecretSecret.properties.secretUri
output googleRefreshTokenSecretUri string = googleRefreshTokenSecret.properties.secretUri
output notificationFromEmailSecretUri string = notificationFromEmailSecret.properties.secretUri
output notificationFromNameSecretUri string = notificationFromNameSecret.properties.secretUri
