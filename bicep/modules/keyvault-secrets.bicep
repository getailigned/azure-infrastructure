// Key Vault secrets module
// Creates secrets in existing Key Vault

@description('Key Vault name')
param keyVaultName string

@description('PostgreSQL connection string')
@secure()
param postgresConnectionString string

@description('Cosmos DB connection string')  
@secure()
param cosmosConnectionString string

@description('Redis connection string')
@secure()
param redisConnectionString string

@description('Service Bus connection string')
@secure()
param serviceBusConnectionString string

@description('Search service endpoint')
param searchServiceEndpoint string

@description('OpenAI API key')
@secure()
param openAiApiKey string

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// PostgreSQL connection secret
resource postgresConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'postgres-connection'
  properties: {
    value: postgresConnectionString
  }
}

// Cosmos DB connection secret
resource cosmosConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'cosmos-connection'
  properties: {
    value: cosmosConnectionString
  }
}

// Redis connection secret
resource redisConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'redis-connection'
  properties: {
    value: redisConnectionString
  }
}

// Service Bus connection secret
resource serviceBusConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'servicebus-connection'
  properties: {
    value: serviceBusConnectionString
  }
}

// Search service endpoint secret
resource searchConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'search-connection'
  properties: {
    value: searchServiceEndpoint
  }
}

// OpenAI API key secret
resource openAiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'openai-api-key'
  properties: {
    value: openAiApiKey
  }
}
