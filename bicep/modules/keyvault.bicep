// Key Vault module for HT-Management
// Stores secrets, certificates, and keys securely

@description('Key Vault name')
param keyVaultName string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Azure AD tenant ID')
param tenantId string

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7  // Dev: Shorter retention
    enablePurgeProtection: true   // Required: Cannot be disabled
    publicNetworkAccess: 'Enabled'  // Dev: Allow public access
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: '00000000-0000-0000-0000-000000000000'  // Will be updated with actual deployment identity
        permissions: {
          keys: [
            'get'
            'list'
            'create'
            'update'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          certificates: [
            'get'
            'list'
            'create'
            'update'
            'delete'
            'recover'
            'backup'
            'restore'
            'managecontacts'
            'manageissuers'
            'getissuers'
            'listissuers'
            'setissuers'
            'deleteissuers'
          ]
        }
      }
    ]
  }
}

// Diagnostic settings for Key Vault (commented out for now)
// resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'default'
//   scope: keyVault
//   properties: {
//     logs: [
//       {
//         categoryGroup: 'allLogs'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//         retentionPolicy: {
//           enabled: true
//           days: 30
//         }
//       }
//     ]
//   }
// }

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
// output keyVaultResource resource = keyVault  // Commented out due to experimental feature requirement
