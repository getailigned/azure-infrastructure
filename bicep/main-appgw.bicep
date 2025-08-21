// HT-Management Azure Infrastructure with Application Gateway
// Main Bicep template for deploying Application Gateway

targetScope = 'resourceGroup'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Application name prefix')
param appName string = 'htma'

@description('Azure region for deployment')
param location string = resourceGroup().location

// Existing infrastructure parameters
@description('Existing VNet name')
param vnetName string = 'htma-dev-vnet'



// Container Apps names
@description('Work Item Service Container App name')
param workItemServiceName string = 'htma-work-item-service'

@description('AI Insights Service Container App name') 
param aiInsightsServiceName string = 'htma-ai-insights-service'

@description('Dependency Service Container App name')
param dependencyServiceName string = 'htma-dependency-service'

// Deploy Application Gateway
module applicationGateway 'modules/application-gateway.bicep' = {
  name: 'applicationGateway'
  params: {
    location: location
    environment: environment
    appName: appName
    vnetName: vnetName


    workItemServiceName: workItemServiceName
    aiInsightsServiceName: aiInsightsServiceName
    dependencyServiceName: dependencyServiceName
  }
}

// Outputs
output applicationGatewayName string = applicationGateway.outputs.applicationGatewayName
output applicationGatewayId string = applicationGateway.outputs.applicationGatewayId
output publicIpAddress string = applicationGateway.outputs.publicIpAddress
output publicIpFqdn string = applicationGateway.outputs.publicIpFqdn
output managedIdentityId string = applicationGateway.outputs.managedIdentityId
output managedIdentityPrincipalId string = applicationGateway.outputs.managedIdentityPrincipalId
