// Secure Container Apps module for HT-Management
// Enhanced security configuration with Managed Identity and private networking

@description('Container Apps Environment name')
param containerAppsEnvName string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Apps subnet ID')
param subnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('Key Vault URI for secret references')
param keyVaultUri string

// Container Apps Environment with enhanced security
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppsEnvName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true  // SECURE: Internal load balancer only
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    daprAIInstrumentationKey: appInsightsInstrumentationKey
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'Dedicated-D4'
        workloadProfileType: 'D4'  // Dedicated profile for better security isolation
        minimumCount: 0
        maximumCount: 3
      }
    ]
  }
}

// Container Registry with enhanced security
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${replace(replace(containerAppsEnvName, '-', ''), '_', '')}acr${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Premium'  // SECURE: Premium tier for private endpoints and advanced features
  }
  properties: {
    adminUserEnabled: false  // SECURE: Disable admin user, use Managed Identity
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'  // Zone redundancy for high availability
    encryption: {
      status: 'enabled'
      keyVaultProperties: {
        identity: ''  // Will be set with customer-managed key
      }
    }
    trustPolicy: {
      type: 'Notary'
      status: 'enabled'  // SECURE: Enable content trust
    }
    quarantinePolicy: {
      status: 'enabled'  // SECURE: Quarantine untrusted images
    }
    retentionPolicy: {
      days: 30
      status: 'enabled'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Shared environment variables for all container apps (secure references)
var secureEnvironmentVariables = [
  {
    name: 'ENVIRONMENT'
    value: 'development-secure'
  }
  {
    name: 'LOG_LEVEL'
    value: 'info'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
  }
  {
    name: 'AZURE_KEY_VAULT_URI'
    value: keyVaultUri
  }
  {
    name: 'AZURE_CLIENT_ID'
    secretRef: 'azure-client-id'
  }
]

// Work Item Service Container App with enhanced security
resource workItemServiceApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-work-item-svc'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'  // SECURE: Managed Identity
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false  // SECURE: Internal only
        targetPort: 3001
        allowInsecure: false  // SECURE: HTTPS only
        clientCertificateMode: 'accept'  // Accept client certificates
        corsPolicy: {
          allowedOrigins: ['https://*.azurecontainerapps.io']  // SECURE: Restrict CORS
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE']
          allowedHeaders: ['*']
          allowCredentials: true
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      secrets: [
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVaultUri}secrets/azure-client-id'
          identity: 'system'
        }
        {
          name: 'postgres-connection'
          keyVaultUrl: '${keyVaultUri}secrets/postgres-connection'
          identity: 'system'
        }
        {
          name: 'redis-connection'
          keyVaultUrl: '${keyVaultUri}secrets/redis-connection'
          identity: 'system'
        }
        {
          name: 'servicebus-connection'
          keyVaultUrl: '${keyVaultUri}secrets/servicebus-connection'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'work-item-service'
          image: '${containerRegistry.properties.loginServer}/htma/work-item-service:latest'
          resources: {
            cpu: json('1')  // Increased resources for secure operations
            memory: '2Gi'
          }
          env: concat(secureEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3001'
            }
            {
              name: 'SERVICE_NAME'
              value: 'work-item-service'
            }
            {
              name: 'POSTGRES_CONNECTION_STRING'
              secretRef: 'postgres-connection'
            }
            {
              name: 'REDIS_CONNECTION_STRING'
              secretRef: 'redis-connection'
            }
            {
              name: 'SERVICE_BUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3001
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 10
              timeoutSeconds: 5
              successThreshold: 1
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3001
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 5
              timeoutSeconds: 3
              successThreshold: 1
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 3001
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              successThreshold: 1
              failureThreshold: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: 2  // SECURE: Always have replicas for availability
        maxReplicas: 10
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
          {
            name: 'cpu-usage'
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
}

// Dependency Service Container App
resource dependencyServiceApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-dependency-svc'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 3002
        allowInsecure: false
        clientCertificateMode: 'accept'
        corsPolicy: {
          allowedOrigins: ['https://*.azurecontainerapps.io']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE']
          allowedHeaders: ['*']
          allowCredentials: true
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      secrets: [
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVaultUri}secrets/azure-client-id'
          identity: 'system'
        }
        {
          name: 'postgres-connection'
          keyVaultUrl: '${keyVaultUri}secrets/postgres-connection'
          identity: 'system'
        }
        {
          name: 'redis-connection'
          keyVaultUrl: '${keyVaultUri}secrets/redis-connection'
          identity: 'system'
        }
        {
          name: 'servicebus-connection'
          keyVaultUrl: '${keyVaultUri}secrets/servicebus-connection'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'dependency-service'
          image: '${containerRegistry.properties.loginServer}/htma/dependency-service:latest'
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          env: concat(secureEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3002'
            }
            {
              name: 'SERVICE_NAME'
              value: 'dependency-service'
            }
            {
              name: 'POSTGRES_CONNECTION_STRING'
              secretRef: 'postgres-connection'
            }
            {
              name: 'REDIS_CONNECTION_STRING'
              secretRef: 'redis-connection'
            }
            {
              name: 'SERVICE_BUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3002
              }
              initialDelaySeconds: 30
              periodSeconds: 10
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3002
              }
              initialDelaySeconds: 10
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 2
        maxReplicas: 8
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '25'
              }
            }
          }
        ]
      }
    }
  }
}

// AI Insights Service Container App (Dedicated workload profile for security)
resource aiInsightsServiceApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-ai-insights-svc'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Dedicated-D4'  // SECURE: Dedicated profile for AI workloads
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 3003
        allowInsecure: false
        clientCertificateMode: 'require'  // SECURE: Require client certificates for AI service
        corsPolicy: {
          allowedOrigins: ['https://*.azurecontainerapps.io']
          allowedMethods: ['POST']  // SECURE: Only allow POST for AI requests
          allowedHeaders: ['Content-Type', 'Authorization']
          allowCredentials: true
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      secrets: [
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVaultUri}secrets/azure-client-id'
          identity: 'system'
        }
        {
          name: 'openai-api-key'
          keyVaultUrl: '${keyVaultUri}secrets/openai-api-key'
          identity: 'system'
        }
        {
          name: 'redis-connection'
          keyVaultUrl: '${keyVaultUri}secrets/redis-connection'
          identity: 'system'
        }
        {
          name: 'servicebus-connection'
          keyVaultUrl: '${keyVaultUri}secrets/servicebus-connection'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-insights-service'
          image: '${containerRegistry.properties.loginServer}/htma/ai-insights-service:latest'
          resources: {
            cpu: json('2')  // Higher resources for AI processing
            memory: '4Gi'
          }
          env: concat(secureEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3003'
            }
            {
              name: 'SERVICE_NAME'
              value: 'ai-insights-service'
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'openai-api-key'
            }
            {
              name: 'REDIS_CONNECTION_STRING'
              secretRef: 'redis-connection'
            }
            {
              name: 'SERVICE_BUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3003
              }
              initialDelaySeconds: 60
              periodSeconds: 30  // Longer intervals for AI service
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3003
              }
              initialDelaySeconds: 30
              periodSeconds: 15
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1  // AI service can scale to zero when not needed
        maxReplicas: 5
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '3'  // SECURE: Lower concurrency for AI processing
              }
            }
          }
        ]
      }
    }
  }
}

// Express Gateway Container App (Application Gateway alternative)
resource expressGatewayApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-gateway'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false  // SECURE: Internal only, accessed via VPN/Bastion
        targetPort: 3000
        allowInsecure: false
        clientCertificateMode: 'accept'
        corsPolicy: {
          allowedOrigins: ['*']  // Will be restricted in production
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: true
        }
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      secrets: [
        {
          name: 'azure-client-id'
          keyVaultUrl: '${keyVaultUri}secrets/azure-client-id'
          identity: 'system'
        }
        {
          name: 'jwt-secret'
          keyVaultUrl: '${keyVaultUri}secrets/jwt-secret'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'express-gateway'
          image: '${containerRegistry.properties.loginServer}/htma/express-gateway:latest'
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          env: concat(secureEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3000'
            }
            {
              name: 'SERVICE_NAME'
              value: 'express-gateway'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'WORK_ITEM_SERVICE_URL'
              value: 'https://${workItemServiceApp.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'DEPENDENCY_SERVICE_URL'
              value: 'https://${dependencyServiceApp.properties.configuration.ingress.fqdn}'
            }
            {
              name: 'AI_INSIGHTS_SERVICE_URL'
              value: 'https://${aiInsightsServiceApp.properties.configuration.ingress.fqdn}'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3000
              }
              initialDelaySeconds: 30
              periodSeconds: 10
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3000
              }
              initialDelaySeconds: 10
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 2  // Always available for gateway
        maxReplicas: 10
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerRegistryId string = containerRegistry.id
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

// Service FQDNs (internal only)
output expressGatewayFqdn string = expressGatewayApp.properties.configuration.ingress.fqdn
output workItemServiceFqdn string = workItemServiceApp.properties.configuration.ingress.fqdn
output dependencyServiceFqdn string = dependencyServiceApp.properties.configuration.ingress.fqdn
output aiInsightsServiceFqdn string = aiInsightsServiceApp.properties.configuration.ingress.fqdn

// Managed Identity Principal IDs for RBAC
output workItemServicePrincipalId string = workItemServiceApp.identity.principalId
output dependencyServicePrincipalId string = dependencyServiceApp.identity.principalId
output aiInsightsServicePrincipalId string = aiInsightsServiceApp.identity.principalId
output expressGatewayPrincipalId string = expressGatewayApp.identity.principalId
output containerRegistryPrincipalId string = containerRegistry.identity.principalId
