// HT-Management Azure Infrastructure - Secure Development Environment
// Main Bicep template with enhanced security and private networking

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev-secure'

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

@description('VPN client certificate data (base64)')
@secure()
param vpnClientCertData string

@description('Current user object ID for Key Vault access')
param userObjectId string

// Variables
var resourceNamePrefix = '${appName}-${environment}'
var tags = {
  Environment: environment
  Application: appName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  SecurityLevel: 'High'
  DataClassification: 'Confidential'
}

// Secure Networking with VPN Gateway and Private DNS
module secureNetworking 'modules/secure-networking.bicep' = {
  name: 'secureNetworking'
  params: {
    vnetName: '${resourceNamePrefix}-vnet'
    location: location
    tags: tags
    environment: environment
    vpnClientCertData: vpnClientCertData
  }
}

// Enhanced Key Vault with private access only
module secureKeyVault 'modules/secure-keyvault.bicep' = {
  name: 'secureKeyVault'
  params: {
    keyVaultName: '${resourceNamePrefix}-kv'
    location: location
    tags: tags
    tenantId: subscription().tenantId
    subnetId: secureNetworking.outputs.dataSubnetId
    userObjectId: userObjectId
  }
}

// Secure data services with private endpoints
module secureDataServices 'modules/secure-data-services.bicep' = {
  name: 'secureDataServices'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    environment: environment
    subnetId: secureNetworking.outputs.dataSubnetId
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

// Secure Container Apps with Managed Identity
module secureContainerApps 'modules/secure-container-apps.bicep' = {
  name: 'secureContainerApps'
  params: {
    containerAppsEnvName: '${resourceNamePrefix}-env'
    location: location
    tags: tags
    subnetId: secureNetworking.outputs.appsSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    keyVaultUri: secureKeyVault.outputs.keyVaultUri
  }
}

// Private Endpoints for all services
module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'privateEndpoints'
  params: {
    resourceNamePrefix: resourceNamePrefix
    location: location
    tags: tags
    privateEndpointsSubnetId: secureNetworking.outputs.privateEndpointsSubnetId
    keyVaultId: secureKeyVault.outputs.keyVaultId
    postgresServerId: secureDataServices.outputs.postgresServerId
    redisId: secureDataServices.outputs.redisId
    serviceBusId: secureDataServices.outputs.serviceBusId
    searchServiceId: secureDataServices.outputs.searchServiceId
    cosmosAccountId: secureDataServices.outputs.cosmosAccountId
    containerRegistryId: secureContainerApps.outputs.containerRegistryId
    keyVaultPrivateDnsZoneId: secureNetworking.outputs.keyVaultPrivateDnsZoneId
    postgresPrivateDnsZoneId: secureNetworking.outputs.postgresPrivateDnsZoneId
    redisPrivateDnsZoneId: secureNetworking.outputs.redisPrivateDnsZoneId
    serviceBusPrivateDnsZoneId: secureNetworking.outputs.serviceBusPrivateDnsZoneId
    searchPrivateDnsZoneId: secureNetworking.outputs.searchPrivateDnsZoneId
  }
  dependsOn: [
    secureKeyVault
    secureDataServices
    secureContainerApps
  ]
}

// Key Vault secrets module (will use private endpoint)
module keyVaultSecrets 'modules/keyvault-secrets.bicep' = {
  name: 'keyVaultSecrets'
  params: {
    keyVaultName: secureKeyVault.outputs.keyVaultName
    postgresConnectionString: secureDataServices.outputs.postgresConnectionString
    cosmosConnectionString: secureDataServices.outputs.cosmosConnectionString
    redisConnectionString: secureDataServices.outputs.redisConnectionString
    serviceBusConnectionString: secureDataServices.outputs.serviceBusConnectionString
    searchServiceEndpoint: secureDataServices.outputs.searchServiceEndpoint
    openAiApiKey: openAiApiKey
  }
  dependsOn: [
    secureKeyVault
    secureDataServices
    privateEndpoints
  ]
}

// Role assignments for Managed Identities
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
}

resource workItemServiceKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'workitem-keyvault-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: secureContainerApps.outputs.workItemServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
    secureKeyVault
  ]
}

resource dependencyServiceKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'dependency-keyvault-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: secureContainerApps.outputs.dependencyServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
    secureKeyVault
  ]
}

resource aiInsightsServiceKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'ai-insights-keyvault-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: secureContainerApps.outputs.aiInsightsServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
    secureKeyVault
  ]
}

resource expressGatewayKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'gateway-keyvault-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: secureContainerApps.outputs.expressGatewayPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
    secureKeyVault
  ]
}

// Container Registry access for Container Apps
resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
}

resource workItemServiceAcrAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'workitem-acr-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: secureContainerApps.outputs.workItemServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
  ]
}

resource dependencyServiceAcrAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'dependency-acr-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: secureContainerApps.outputs.dependencyServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
  ]
}

resource aiInsightsServiceAcrAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'ai-insights-acr-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: secureContainerApps.outputs.aiInsightsServicePrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
  ]
}

resource expressGatewayAcrAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'gateway-acr-access')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRole.id
    principalId: secureContainerApps.outputs.expressGatewayPrincipalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    secureContainerApps
  ]
}

// Outputs for deployment scripts
output resourceGroupName string = resourceGroup().name
output keyVaultName string = secureKeyVault.outputs.keyVaultName
output keyVaultUri string = secureKeyVault.outputs.keyVaultUri
output containerAppsEnvironmentName string = secureContainerApps.outputs.containerAppsEnvironmentName
output containerRegistryName string = secureContainerApps.outputs.containerRegistryName
output containerRegistryLoginServer string = secureContainerApps.outputs.containerRegistryLoginServer

// Secure endpoints (internal only)
output expressGatewayFqdn string = secureContainerApps.outputs.expressGatewayFqdn
output workItemServiceFqdn string = secureContainerApps.outputs.workItemServiceFqdn
output dependencyServiceFqdn string = secureContainerApps.outputs.dependencyServiceFqdn
output aiInsightsServiceFqdn string = secureContainerApps.outputs.aiInsightsServiceFqdn

// VPN and Bastion access
output vpnGatewayPublicIP string = secureNetworking.outputs.vpnGatewayPublicIP
output bastionHostId string = secureNetworking.outputs.bastionId
output vnetName string = secureNetworking.outputs.vnetName

// Security information
output securityLevel string = 'HIGH'
output networkAccess string = 'PRIVATE_ONLY'
output authenticationMethod string = 'MANAGED_IDENTITY'
output encryptionStatus string = 'ENABLED'
