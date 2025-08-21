// Static Web App module for HT-Management frontend
// Creates Azure Static Web Apps for Next.js frontend deployment

@description('Static Web App name')
param staticWebAppName string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('GitHub repository URL')
param repositoryUrl string

@description('GitHub branch name')
param branch string

@description('App location in repository')
param appLocation string

@description('Build output location')
param buildLocation string

// Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  tags: tags
  sku: {
    name: 'Free'  // Dev: Free tier
    tier: 'Free'
  }
  properties: {
    repositoryUrl: repositoryUrl
    branch: branch
    buildProperties: {
      appLocation: appLocation
      apiLocation: ''  // No API functions for now
      outputLocation: buildLocation
      appBuildCommand: 'npm run build'
      apiBuildCommand: ''
    }
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
    enterpriseGradeCdnStatus: 'Disabled'  // Dev: Standard CDN
  }
}

// Custom domain configuration (will be added later)
// resource customDomain 'Microsoft.Web/staticSites/customDomains@2023-01-01' = {
//   parent: staticWebApp
//   name: 'app.htma.dev'  // Replace with actual domain
//   properties: {
//     validationMethod: 'cname-delegation'
//   }
// }

// Static Web App configuration
resource staticWebAppConfig 'Microsoft.Web/staticSites/config@2023-01-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    NEXT_PUBLIC_API_URL: 'https://htma-dev-gateway.prouddesert-12345678.eastus.azurecontainerapps.io'  // Will be updated
    NEXT_PUBLIC_ENVIRONMENT: 'development'
    NEXT_PUBLIC_APP_NAME: 'HT-Management'
    NEXT_PUBLIC_VERSION: '1.0.0'
  }
}

// Function app settings for API routes (if needed)
resource staticWebAppFunctionSettings 'Microsoft.Web/staticSites/config@2023-01-01' = {
  parent: staticWebApp
  name: 'functionappsettings'
  properties: {
    FUNCTIONS_WORKER_RUNTIME: 'node'
    WEBSITE_NODE_DEFAULT_VERSION: '18.x'
  }
}

// Outputs
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output staticWebAppDefaultHostname string = staticWebApp.properties.defaultHostname
output staticWebAppRepositoryToken string = staticWebApp.properties.repositoryToken
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
