// Enhanced Container Apps Module - Phase 5-6 Services
// WebSocket, Search, and HTA Builder services on Azure Container Apps

targetScope = 'resourceGroup'

@description('Container Apps Environment name')
param containerAppsEnvName string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Environment name')
param environment string

@description('Resource tags')
param tags object

@description('Subnet ID for Container Apps')
param subnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string

@description('Key Vault name for retrieving secrets')
param keyVaultName string

@description('Container registry URL')
param containerRegistryUrl string = 'htmaregistry.azurecr.io'

@description('SignalR connection string')
@secure()
param signalRConnectionString string

@description('Redis connection string')
@secure()
param redisConnectionString string

@description('Service Bus connection string')
@secure()
param serviceBusConnectionString string

@description('Search service endpoint')
param searchServiceEndpoint string

@description('Search service admin key')
@secure()
param searchServiceAdminKey string

@description('OpenAI endpoint')
param openAiEndpoint string

@description('OpenAI API key')
@secure()
param openAiApiKey string

@description('PostgreSQL connection string')
@secure()
param postgresConnectionString string

@description('Google Workspace Client ID')
@secure()
param googleClientId string

@description('Google Workspace Client Secret')
@secure()
param googleClientSecret string

@description('Google Workspace Refresh Token')
@secure()
param googleRefreshToken string

@description('Notification from email')
param notificationFromEmail string

@description('Notification from name')
param notificationFromName string = 'HTMA Platform'

@description('Communication Services connection string')
@secure()
param communicationConnectionString string

@description('Notification storage connection string')
@secure()
param notificationStorageConnectionString string

@description('Event Grid access key')
@secure()
param eventGridAccessKey string

@description('Event Grid endpoint')
param eventGridEndpoint string

// Variables
var webSocketAppName = '${containerAppsEnvName}-websocket'
var searchAppName = '${containerAppsEnvName}-search'
var htaBuilderAppName = '${containerAppsEnvName}-hta-builder'
var notificationAppName = '${containerAppsEnvName}-notification'

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppsEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2021-06-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2021-06-01').primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: false
    }
    zoneRedundant: environment == 'prod' ? true : false
    kedaConfiguration: {}
    daprConfiguration: {
      enabled: true
    }
  }
}

// Managed Identity for accessing Key Vault
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${containerAppsEnvName}-identity'
  location: location
  tags: tags
}

// Key Vault access policy for managed identity
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: managedIdentity.properties.tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// WebSocket Service Container App
resource websocketService 'Microsoft.App/containerapps@2023-05-01' = {
  name: webSocketAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3008
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            'https://*.azurestaticapps.net'
            'https://*.getailigned.com'
            'http://localhost:3000'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          allowCredentials: true
        }
      }
      secrets: [
        {
          name: 'signalr-connection-string'
          value: signalRConnectionString
        }
        {
          name: 'redis-connection-string'
          value: redisConnectionString
        }
        {
          name: 'servicebus-connection-string'
          value: serviceBusConnectionString
        }
        {
          name: 'jwt-secret'
          value: 'htma-websocket-secret-${uniqueString(resourceGroup().id)}'
        }
        {
          name: 'google-client-id'
          value: googleClientId
        }
        {
          name: 'google-client-secret'
          value: googleClientSecret
        }
        {
          name: 'google-refresh-token'
          value: googleRefreshToken
        }
        {
          name: 'notification-from-email'
          value: notificationFromEmail
        }
        {
          name: 'communication-connection-string'
          value: communicationConnectionString
        }
        {
          name: 'notification-storage-connection-string'
          value: notificationStorageConnectionString
        }
        {
          name: 'eventgrid-access-key'
          value: eventGridAccessKey
        }
      ]
      registries: [
        {
          server: containerRegistryUrl
          identity: managedIdentity.id
        }
      ]
      dapr: {
        enabled: true
        appId: 'websocket-service'
        appProtocol: 'http'
        appPort: 3008
      }
    }
    template: {
      containers: [
        {
          image: '${containerRegistryUrl}/htma/websocket-service:latest'
          name: 'websocket-service'
          env: [
            {
              name: 'NODE_ENV'
              value: environment
            }
            {
              name: 'PORT'
              value: '3008'
            }
            {
              name: 'SIGNALR_CONNECTION_STRING'
              secretRef: 'signalr-connection-string'
            }
            {
              name: 'REDIS_CONNECTION_STRING'
              secretRef: 'redis-connection-string'
            }
            {
              name: 'SERVICEBUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection-string'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]
          resources: {
            cpu: json(environment == 'prod' ? '1.0' : '0.5')
            memory: environment == 'prod' ? '2Gi' : '1Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3008
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3008
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 1
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    containerAppsEnvironment
    managedIdentity
  ]
}

// Search Service Container App
resource searchService 'Microsoft.App/containerapps@2023-05-01' = {
  name: searchAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3006
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            'https://*.azurestaticapps.net'
            'https://*.getailigned.com'
            'http://localhost:3000'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          allowCredentials: true
        }
      }
      secrets: [
        {
          name: 'search-endpoint'
          value: searchServiceEndpoint
        }
        {
          name: 'search-admin-key'
          value: searchServiceAdminKey
        }
        {
          name: 'servicebus-connection-string'
          value: serviceBusConnectionString
        }
        {
          name: 'jwt-secret'
          value: 'htma-search-secret-${uniqueString(resourceGroup().id)}'
        }
      ]
      registries: [
        {
          server: containerRegistryUrl
          identity: managedIdentity.id
        }
      ]
      dapr: {
        enabled: true
        appId: 'search-service'
        appProtocol: 'http'
        appPort: 3006
      }
    }
    template: {
      containers: [
        {
          image: '${containerRegistryUrl}/htma/search-service:latest'
          name: 'search-service'
          env: [
            {
              name: 'NODE_ENV'
              value: environment
            }
            {
              name: 'PORT'
              value: '3006'
            }
            {
              name: 'SEARCH_SERVICE_ENDPOINT'
              secretRef: 'search-endpoint'
            }
            {
              name: 'SEARCH_SERVICE_ADMIN_KEY'
              secretRef: 'search-admin-key'
            }
            {
              name: 'SERVICEBUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection-string'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'INDEX_PREFIX'
              value: 'htma-${environment}'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]
          resources: {
            cpu: json(environment == 'prod' ? '1.0' : '0.5')
            memory: environment == 'prod' ? '2Gi' : '1Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3006
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3006
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 1
        maxReplicas: environment == 'prod' ? 8 : 3
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '75'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    containerAppsEnvironment
    managedIdentity
  ]
}

// HTA Builder Service Container App
resource htaBuilderService 'Microsoft.App/containerapps@2023-05-01' = {
  name: htaBuilderAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3007
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            'https://*.azurestaticapps.net'
            'https://*.getailigned.com'
            'http://localhost:3000'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          allowCredentials: true
        }
      }
      secrets: [
        {
          name: 'openai-endpoint'
          value: openAiEndpoint
        }
        {
          name: 'openai-api-key'
          value: openAiApiKey
        }
        {
          name: 'postgres-connection-string'
          value: postgresConnectionString
        }
        {
          name: 'jwt-secret'
          value: 'htma-hta-builder-secret-${uniqueString(resourceGroup().id)}'
        }
      ]
      registries: [
        {
          server: containerRegistryUrl
          identity: managedIdentity.id
        }
      ]
      dapr: {
        enabled: true
        appId: 'hta-builder-service'
        appProtocol: 'http'
        appPort: 3007
      }
    }
    template: {
      containers: [
        {
          image: '${containerRegistryUrl}/htma/hta-builder-service:latest'
          name: 'hta-builder-service'
          env: [
            {
              name: 'NODE_ENV'
              value: environment
            }
            {
              name: 'PORT'
              value: '3007'
            }
            {
              name: 'OPENAI_ENDPOINT'
              secretRef: 'openai-endpoint'
            }
            {
              name: 'OPENAI_API_KEY'
              secretRef: 'openai-api-key'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'postgres-connection-string'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'PRIMARY_AI_MODEL'
              value: 'gpt-4o-mini'
            }
            {
              name: 'FALLBACK_AI_MODEL'
              value: 'gpt-35-turbo'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]
          resources: {
            cpu: json(environment == 'prod' ? '2.0' : '1.0')
            memory: environment == 'prod' ? '4Gi' : '2Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3007
                scheme: 'HTTP'
              }
              initialDelaySeconds: 60
              periodSeconds: 30
              timeoutSeconds: 15
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3007
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 1
        maxReplicas: environment == 'prod' ? 6 : 2
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '80'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    containerAppsEnvironment
    managedIdentity
  ]
}

// Notification Service Container App
resource notificationService 'Microsoft.App/containerapps@2023-05-01' = {
  name: notificationAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3007
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        corsPolicy: {
          allowedOrigins: [
            'https://*.getailigned.com'
            'https://getailigned.com'
            environment == 'dev' ? 'http://localhost:3000' : null
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'PATCH'
            'HEAD'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          allowCredentials: true
        }
      }
      secrets: [
        {
          name: 'postgres-connection-string'
          value: postgresConnectionString
        }
        {
          name: 'redis-connection-string'
          value: redisConnectionString
        }
        {
          name: 'servicebus-connection-string'
          value: serviceBusConnectionString
        }
        {
          name: 'jwt-secret'
          value: 'htma-notification-secret-${uniqueString(resourceGroup().id)}'
        }
        {
          name: 'google-client-id'
          value: googleClientId
        }
        {
          name: 'google-client-secret'
          value: googleClientSecret
        }
        {
          name: 'google-refresh-token'
          value: googleRefreshToken
        }
        {
          name: 'notification-from-email'
          value: notificationFromEmail
        }
        {
          name: 'communication-connection-string'
          value: communicationConnectionString
        }
        {
          name: 'notification-storage-connection-string'
          value: notificationStorageConnectionString
        }
        {
          name: 'eventgrid-access-key'
          value: eventGridAccessKey
        }
      ]
      registries: [
        {
          server: containerRegistryUrl
          identity: managedIdentity.id
        }
      ]
      dapr: {
        enabled: true
        appId: 'notification-service'
        appProtocol: 'http'
        appPort: 3007
      }
    }
    template: {
      containers: [
        {
          name: 'notification-service'
          image: '${containerRegistryUrl}/htma/notification-service:latest'
          env: [
            {
              name: 'NODE_ENV'
              value: environment
            }
            {
              name: 'PORT'
              value: '3007'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'postgres-connection-string'
            }
            {
              name: 'REDIS_URL'
              secretRef: 'redis-connection-string'
            }
            {
              name: 'RABBITMQ_URL'
              secretRef: 'servicebus-connection-string'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'GOOGLE_CLIENT_ID'
              secretRef: 'google-client-id'
            }
            {
              name: 'GOOGLE_CLIENT_SECRET'
              secretRef: 'google-client-secret'
            }
            {
              name: 'GOOGLE_REFRESH_TOKEN'
              secretRef: 'google-refresh-token'
            }
            {
              name: 'GOOGLE_REDIRECT_URI'
              value: 'https://app.getailigned.com/auth/google/callback'
            }
            {
              name: 'NOTIFICATION_FROM_EMAIL'
              secretRef: 'notification-from-email'
            }
            {
              name: 'NOTIFICATION_FROM_NAME'
              value: notificationFromName
            }
            {
              name: 'COMMUNICATION_CONNECTION_STRING'
              secretRef: 'communication-connection-string'
            }
            {
              name: 'NOTIFICATION_STORAGE_CONNECTION_STRING'
              secretRef: 'notification-storage-connection-string'
            }
            {
              name: 'EVENTGRID_ACCESS_KEY'
              secretRef: 'eventgrid-access-key'
            }
            {
              name: 'EVENTGRID_ENDPOINT'
              value: eventGridEndpoint
            }
            {
              name: 'CORS_ORIGIN'
              value: environment == 'prod' ? 'https://app.getailigned.com' : 'http://localhost:3000'
            }
            {
              name: 'NOTIFICATION_RATE_LIMIT'
              value: environment == 'prod' ? '500' : '100'
            }
            {
              name: 'NOTIFICATION_BATCH_SIZE'
              value: '50'
            }
            {
              name: 'NOTIFICATION_RETRY_ATTEMPTS'
              value: '3'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]
          resources: {
            cpu: json(environment == 'prod' ? '1.0' : '0.5')
            memory: environment == 'prod' ? '2Gi' : '1Gi'
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3007
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 3007
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 2 : 1
        maxReplicas: environment == 'prod' ? 10 : 4
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
          {
            name: 'memory-rule'
            custom: {
              type: 'memory'
              metadata: {
                type: 'Utilization'
                value: '80'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    containerAppsEnvironment
    managedIdentity
  ]
}

// Custom domain and SSL certificate management
resource customDomain 'Microsoft.App/managedEnvironments/certificates@2023-05-01' = if (environment == 'prod') {
  parent: containerAppsEnvironment
  name: 'api-getailigned-com'
  properties: {
    certificateType: 'ManagedCertificate'
    subjectName: 'api.getailigned.com'
    validationMethod: 'CNAME'
  }
}

// Outputs
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsEnvironmentFqdn string = containerAppsEnvironment.properties.defaultDomain

output websocketServiceName string = websocketService.name
output websocketServiceFqdn string = websocketService.properties.configuration.ingress.fqdn
output websocketServiceUrl string = 'https://${websocketService.properties.configuration.ingress.fqdn}'

output searchServiceName string = searchService.name
output searchServiceFqdn string = searchService.properties.configuration.ingress.fqdn
output searchServiceUrl string = 'https://${searchService.properties.configuration.ingress.fqdn}'

output htaBuilderServiceName string = htaBuilderService.name
output htaBuilderServiceFqdn string = htaBuilderService.properties.configuration.ingress.fqdn
output htaBuilderServiceUrl string = 'https://${htaBuilderService.properties.configuration.ingress.fqdn}'

output notificationServiceName string = notificationService.name
output notificationServiceFqdn string = notificationService.properties.configuration.ingress.fqdn
output notificationServiceUrl string = 'https://${notificationService.properties.configuration.ingress.fqdn}'

output managedIdentityId string = managedIdentity.id
output managedIdentityClientId string = managedIdentity.properties.clientId
