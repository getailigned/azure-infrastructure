// Container Apps module for HT-Management
// Creates Container Apps Environment for microservices

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

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppsEnvName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: false  // Dev: External load balancer
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
    ]
  }
}

// Container Registry for storing images
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${replace(replace(containerAppsEnvName, '-', ''), '_', '')}acr${uniqueString(resourceGroup().id)}'  // ACR names must be globally unique
  location: location
  tags: tags
  sku: {
    name: 'Basic'  // Dev: Basic tier
  }
  properties: {
    adminUserEnabled: true  // Dev: Enable admin user for simplicity
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Shared environment variables for all container apps
var sharedEnvironmentVariables = [
  {
    name: 'ENVIRONMENT'
    value: 'development'
  }
  {
    name: 'LOG_LEVEL'
    value: 'info'
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
  }
]

// Work Item Service Container App
resource workItemServiceApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-work-item-svc'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false  // Internal only
        targetPort: 3001
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'work-item-service'
          image: '${containerRegistry.properties.loginServer}/htma/work-item-service:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(sharedEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3001'
            }
            {
              name: 'SERVICE_NAME'
              value: 'work-item-service'
            }
            {
              name: 'ALLOW_DEMO_DATA'
              value: 'true'
            }
            {
              name: 'ALLOW_DEMO_TOKEN'
              value: 'true'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3001
              }
              initialDelaySeconds: 30
              periodSeconds: 10
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3001
              }
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3  // Dev: Limited scaling
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '10'
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
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 3002
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'dependency-service'
          image: '${containerRegistry.properties.loginServer}/htma/dependency-service:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(sharedEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3002'
            }
            {
              name: 'SERVICE_NAME'
              value: 'dependency-service'
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
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// AI Insights Service Container App
resource aiInsightsServiceApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-ai-insights-svc'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 3003
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-insights-service'
          image: '${containerRegistry.properties.loginServer}/htma/ai-insights-service:latest'
          resources: {
            cpu: json('1')
            memory: '2Gi'  // More resources for AI processing
          }
          env: concat(sharedEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3003'
            }
            {
              name: 'SERVICE_NAME'
              value: 'ai-insights-service'
            }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 3003
              }
              initialDelaySeconds: 60  // Longer for AI service
              periodSeconds: 15
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 3003
              }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5  // Higher scaling for AI workloads
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '5'  // Lower concurrency for AI processing
              }
            }
          }
        ]
      }
    }
  }
}

// Express Gateway Container App
resource expressGatewayApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${containerAppsEnvName}-gateway'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true  // External facing gateway
        targetPort: 3000
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'express-gateway'
          image: '${containerRegistry.properties.loginServer}/htma/express-gateway:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(sharedEnvironmentVariables, [
            {
              name: 'PORT'
              value: '3000'
            }
            {
              name: 'SERVICE_NAME'
              value: 'express-gateway'
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
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '20'
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
output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output expressGatewayFqdn string = expressGatewayApp.properties.configuration.ingress.fqdn
output workItemServiceFqdn string = workItemServiceApp.properties.configuration.ingress.fqdn
output dependencyServiceFqdn string = dependencyServiceApp.properties.configuration.ingress.fqdn
output aiInsightsServiceFqdn string = aiInsightsServiceApp.properties.configuration.ingress.fqdn
