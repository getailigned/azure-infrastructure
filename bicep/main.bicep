// HT-Management Azure Infrastructure - Development Environment
// Main Bicep template for orchestrating all resources

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Application name prefix')
param appName string = 'htma'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Administrator login for PostgreSQL')
@secure()
param postgresAdminLogin string

@description('Administrator password for PostgreSQL')
@secure()
param postgresAdminPassword string

@description('MongoDB admin username')
@secure()
param mongoAdminUsername string

@description('MongoDB admin password')
@secure()
param mongoAdminPassword string

@description('OpenAI API key')
@secure()
param openAiApiKey string

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
var resourceNamePrefix = '${appName}-${environment}'
var tags = {
  Environment: environment
  Application: appName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
}

// Key Vault for secrets management
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: '${resourceNamePrefix}-kv'
    location: location
    tags: tags
    tenantId: subscription().tenantId
  }
}

// Networking module
module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    vnetName: '${resourceNamePrefix}-vnet'
    location: location
    tags: tags
    environment: environment
  }
}

// Data services module
module dataServices 'modules/data-services.bicep' = {
  name: 'dataServices'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    environment: environment
    subnetId: networking.outputs.dataSubnetId
    postgresAdminLogin: postgresAdminLogin
    postgresAdminPassword: postgresAdminPassword
    mongoAdminUsername: mongoAdminUsername
    mongoAdminPassword: mongoAdminPassword
  }
}

// Application Insights for monitoring
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    appInsightsName: '${resourceNamePrefix}-ai'
    logAnalyticsName: '${resourceNamePrefix}-law'
    location: location
    tags: tags
  }
}

// Real-time Services (Phase 5)
module realtimeServices 'modules/realtime-services.bicep' = {
  name: 'realtimeServices'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environment: environment
    tags: tags
    subnetId: networking.outputs.dataSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    keyVaultName: keyVault.outputs.keyVaultName
  }
  dependsOn: [
    keyVault
    monitoring
    networking
  ]
}

// AI and Search Services (Phase 6)
module aiSearchServices 'modules/ai-search-services.bicep' = {
  name: 'aiSearchServices'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environment: environment
    tags: tags
    subnetId: networking.outputs.dataSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    keyVaultName: keyVault.outputs.keyVaultName
    openAiApiKey: openAiApiKey
  }
  dependsOn: [
    keyVault
    monitoring
    networking
  ]
}

// Notification Services (Google Workspace Integration)
module notificationServices 'modules/notification-services.bicep' = {
  name: 'notificationServices'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    environment: environment
    tags: tags
    subnetId: networking.outputs.dataSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    keyVaultName: keyVault.outputs.keyVaultName
    googleClientId: googleClientId
    googleClientSecret: googleClientSecret
    googleRefreshToken: googleRefreshToken
    notificationFromEmail: notificationFromEmail
    notificationFromName: notificationFromName
  }
  dependsOn: [
    keyVault
    monitoring
    networking
  ]
}

// Enhanced Container Apps with Phase 5-6 Services
module enhancedContainerApps 'modules/enhanced-container-apps.bicep' = {
  name: 'enhancedContainerApps'
  params: {
    containerAppsEnvName: '${resourceNamePrefix}-env'
    location: location
    environment: environment
    tags: tags
    subnetId: networking.outputs.appsSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    keyVaultName: keyVault.outputs.keyVaultName
    signalRConnectionString: realtimeServices.outputs.signalRConnectionString
    redisConnectionString: realtimeServices.outputs.redisConnectionString
    serviceBusConnectionString: realtimeServices.outputs.serviceBusConnectionString
    searchServiceEndpoint: aiSearchServices.outputs.searchServiceEndpoint
    searchServiceAdminKey: aiSearchServices.outputs.searchServiceAdminKey
    openAiEndpoint: aiSearchServices.outputs.openAiEndpoint
    openAiApiKey: aiSearchServices.outputs.openAiApiKey
    postgresConnectionString: dataServices.outputs.postgresConnectionString
    googleClientId: googleClientId
    googleClientSecret: googleClientSecret
    googleRefreshToken: googleRefreshToken
    notificationFromEmail: notificationFromEmail
    notificationFromName: notificationFromName
    communicationConnectionString: notificationServices.outputs.communicationConnectionString
    notificationStorageConnectionString: notificationServices.outputs.storageConnectionString
    eventGridAccessKey: notificationServices.outputs.eventGridTopicId
    eventGridEndpoint: notificationServices.outputs.eventGridEndpoint
  }
  dependsOn: [
    realtimeServices
    aiSearchServices
    dataServices
    monitoring
    notificationServices
  ]
}

// Static Web App for frontend
module staticWebApp 'modules/static-web-app.bicep' = {
  name: 'staticWebApp'
  params: {
    staticWebAppName: '${resourceNamePrefix}-webapp'
    location: 'eastus2' // Static Web Apps limited regions
    tags: tags
    repositoryUrl: 'https://github.com/your-username/HT-Management'
    branch: 'main'
    appLocation: '/frontend'
    buildLocation: '/frontend/.next'
  }
}

// Key Vault secrets module
module keyVaultSecrets 'modules/keyvault-secrets.bicep' = {
  name: 'keyVaultSecrets'
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    postgresConnectionString: dataServices.outputs.postgresConnectionString
    cosmosConnectionString: dataServices.outputs.cosmosConnectionString
    redisConnectionString: dataServices.outputs.redisConnectionString
    serviceBusConnectionString: dataServices.outputs.serviceBusConnectionString
    searchServiceEndpoint: dataServices.outputs.searchServiceEndpoint
    openAiApiKey: openAiApiKey
  }
  dependsOn: [
    keyVault
    dataServices
  ]
}

// Outputs for use in deployment scripts
output resourceGroupName string = resourceGroup().name
output keyVaultName string = keyVault.outputs.keyVaultName

// Container Apps outputs
output containerAppsEnvironmentName string = enhancedContainerApps.outputs.containerAppsEnvironmentName
output websocketServiceUrl string = enhancedContainerApps.outputs.websocketServiceUrl
output searchServiceUrl string = enhancedContainerApps.outputs.searchServiceUrl
output htaBuilderServiceUrl string = enhancedContainerApps.outputs.htaBuilderServiceUrl
output notificationServiceUrl string = enhancedContainerApps.outputs.notificationServiceUrl

// Static Web App
output staticWebAppName string = staticWebApp.outputs.staticWebAppName

// Data Services outputs
output postgresServerName string = dataServices.outputs.postgresServerName
output cosmosAccountName string = dataServices.outputs.cosmosAccountName

// Real-time Services outputs (Phase 5)
output signalRServiceName string = realtimeServices.outputs.signalRServiceName
output redisCacheName string = realtimeServices.outputs.redisCacheName
output serviceBusNamespace string = realtimeServices.outputs.serviceBusNamespace
output eventGridTopicName string = realtimeServices.outputs.eventGridTopicName
output notificationHubName string = realtimeServices.outputs.notificationHubName

// AI & Search Services outputs (Phase 6)
output searchServiceName string = aiSearchServices.outputs.searchServiceName
output openAiAccountName string = aiSearchServices.outputs.openAiAccountName
output storageAccountName string = aiSearchServices.outputs.storageAccountName
output gpt4oMiniDeploymentName string = aiSearchServices.outputs.gpt4oMiniDeploymentName
output gpt35TurboDeploymentName string = aiSearchServices.outputs.gpt35TurboDeploymentName

// Notification Services outputs (Google Workspace Integration)
output communicationServiceName string = notificationServices.outputs.communicationServiceName
output emailServiceName string = notificationServices.outputs.emailServiceName
output notificationEventGridName string = notificationServices.outputs.eventGridTopicName
output notificationStorageAccountName string = notificationServices.outputs.storageAccountName

// Monitoring outputs
output appInsightsName string = monitoring.outputs.appInsightsName
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName

// Networking outputs
output vnetName string = networking.outputs.vnetName
