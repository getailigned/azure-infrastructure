// Real-time Services Module - Phase 5 Implementation
// WebSocket service with SignalR, Redis Cache, and Service Bus for real-time capabilities

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

// Variables
var signalRName = '${resourceNamePrefix}-signalr'
var redisCacheName = '${resourceNamePrefix}-redis'
var serviceBusName = '${resourceNamePrefix}-servicebus'
var eventGridTopicName = '${resourceNamePrefix}-events'
var notificationHubName = '${resourceNamePrefix}-notificationhub'

// Azure SignalR Service for WebSocket functionality
resource signalRService 'Microsoft.SignalRService/signalR@2023-02-01' = {
  name: signalRName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard_S1' : 'Free_F1'
    tier: environment == 'prod' ? 'Standard' : 'Free'
    capacity: environment == 'prod' ? 1 : 1
  }
  kind: 'SignalR'
  properties: {
    features: [
      {
        flag: 'ServiceMode'
        value: 'Default'
      }
      {
        flag: 'EnableConnectivityLogs'
        value: 'true'
      }
      {
        flag: 'EnableMessagingLogs'
        value: 'true'
      }
      {
        flag: 'EnableLiveTrace'
        value: 'true'
      }
    ]
    cors: {
      allowedOrigins: [
        'https://*.azurestaticapps.net'
        'https://*.getailigned.com'
        'http://localhost:3000'
      ]
    }
    serverless: {
      connectionTimeoutInSeconds: 30
    }
    tls: {
      clientCertEnabled: false
    }
    networkACLs: {
      defaultAction: 'Allow'
      publicNetwork: {
        allow: [
          'ServerConnection'
          'ClientConnection'
          'RESTAPI'
          'Trace'
        ]
      }
      privateEndpoints: []
    }
  }
}

// Redis Cache for session storage and real-time data
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: environment == 'prod' ? 'Standard' : 'Basic'
      family: 'C'
      capacity: environment == 'prod' ? 1 : 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
      'maxmemory-delta': '10'
      'maxmemory-reserved': '10'
    }
    redisVersion: '6'
  }
}

// Service Bus for message queuing and event handling
resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard' : 'Basic'
    tier: environment == 'prod' ? 'Standard' : 'Basic'
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    zoneRedundant: environment == 'prod' ? true : false
  }
}

// Service Bus Topics for different event types
resource workItemEventsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: 'work-item-events'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    supportOrdering: true
    enablePartitioning: false
  }
}

resource dependencyEventsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: 'dependency-events'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    supportOrdering: true
    enablePartitioning: false
  }
}

resource notificationEventsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: 'notification-events'
  properties: {
    maxMessageSizeInKilobytes: 256
    defaultMessageTimeToLive: 'P7D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    enableBatchedOperations: true
    supportOrdering: false
    enablePartitioning: false
  }
}

// WebSocket Service Subscription
resource websocketSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: workItemEventsTopic
  name: 'websocket-service'
  properties: {
    isClientAffine: false
    lockDuration: 'PT1M'
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnFilterEvaluationExceptions: true
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 3
    enableBatchedOperations: true
  }
}

// Search Service Subscription
resource searchSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: workItemEventsTopic
  name: 'search-service'
  properties: {
    isClientAffine: false
    lockDuration: 'PT5M'
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnFilterEvaluationExceptions: true
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 5
    enableBatchedOperations: true
  }
}

// Event Grid Topic for system-wide events
resource eventGridTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: eventGridTopicName
  location: location
  tags: tags
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Enabled'
    eventTypeInfo: {
      kind: 'inline'
      inlineEventTypes: {
        'HTMA.WorkItem.Created': {
          description: 'Work item created event'
          displayName: 'Work Item Created'
          documentationUrl: 'https://docs.getailigned.com/events/work-item-created'
          dataSchemaUrl: 'https://docs.getailigned.com/schemas/work-item-event.json'
        }
        'HTMA.WorkItem.Updated': {
          description: 'Work item updated event'
          displayName: 'Work Item Updated'
          documentationUrl: 'https://docs.getailigned.com/events/work-item-updated'
          dataSchemaUrl: 'https://docs.getailigned.com/schemas/work-item-event.json'
        }
        'HTMA.Dependency.Changed': {
          description: 'Dependency relationship changed'
          displayName: 'Dependency Changed'
          documentationUrl: 'https://docs.getailigned.com/events/dependency-changed'
          dataSchemaUrl: 'https://docs.getailigned.com/schemas/dependency-event.json'
        }
        'HTMA.Notification.Critical': {
          description: 'Critical system notification'
          displayName: 'Critical Notification'
          documentationUrl: 'https://docs.getailigned.com/events/critical-notification'
          dataSchemaUrl: 'https://docs.getailigned.com/schemas/notification-event.json'
        }
      }
    }
  }
}

// Notification Hubs for mobile push notifications
resource notificationHubNamespace 'Microsoft.NotificationHubs/namespaces@2023-09-01' = {
  name: '${resourceNamePrefix}-notifications'
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard' : 'Free'
  }
  properties: {
    namespaceType: 'NotificationHub'
  }
}

resource notificationHub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-09-01' = {
  parent: notificationHubNamespace
  name: notificationHubName
  location: location
  properties: {
    authorizationRules: []
    apnsCredential: {
      properties: {
        endpoint: environment == 'prod' ? 'https://api.push.apple.com:443/3/device' : 'https://api.sandbox.push.apple.com:443/3/device'
      }
    }
  }
}

// Diagnostic settings for monitoring
resource signalRDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'signalr-diagnostics'
  scope: signalRService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AllLogs'
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

resource redisDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'redis-diagnostics'
  scope: redisCache
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
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

resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'servicebus-diagnostics'
  scope: serviceBus
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'OperationalLogs'
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

// Connection strings are stored in Key Vault by the main template

// Outputs
output signalRServiceName string = signalRService.name
output signalRConnectionString string = signalRService.listKeys().primaryConnectionString
output signalRHostname string = signalRService.properties.hostName

output redisCacheName string = redisCache.name
output redisConnectionString string = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
output redisHostname string = redisCache.properties.hostName

output serviceBusNamespace string = serviceBus.name
output serviceBusConnectionString string = serviceBus.listKeys('RootManageSharedAccessKey').primaryConnectionString

output eventGridTopicName string = eventGridTopic.name
output eventGridEndpoint string = eventGridTopic.properties.endpoint
output eventGridAccessKey string = eventGridTopic.listKeys().key1

output notificationHubName string = notificationHub.name
output notificationHubConnectionString string = notificationHub.listKeys().primaryConnectionString
