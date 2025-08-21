// Secure Key Vault module for HT-Management
// Enhanced security configuration with private access only

@description('Key Vault name')
param keyVaultName string

@description('Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Azure AD tenant ID')
param tenantId string

@description('Data subnet ID for private endpoint access')
param subnetId string

@description('User object ID for access policy')
param userObjectId string

// Key Vault with enhanced security
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'premium'  // SECURE: Premium tier for HSM-backed keys
    }
    enabledForDeployment: false  // SECURE: Disable VM deployment access
    enabledForDiskEncryption: false  // SECURE: Disable disk encryption access
    enabledForTemplateDeployment: true  // Keep for infrastructure deployment
    enableSoftDelete: true
    softDeleteRetentionInDays: 90  // SECURE: Extended retention (7-90 days)
    enablePurgeProtection: true
    enableRbacAuthorization: true  // SECURE: Use RBAC instead of access policies
    publicNetworkAccess: 'Disabled'  // SECURE: No public access
    networkAcls: {
      defaultAction: 'Deny'  // SECURE: Deny all by default
      bypass: 'AzureServices'
      ipRules: []  // No IP allowlist
      virtualNetworkRules: [
        {
          id: subnetId
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    // Create data encryption key for advanced security
    createMode: 'default'
  }
}

// Key for data encryption (customer-managed encryption)
resource dataEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'htma-data-encryption-key'
  properties: {
    keySize: 2048
    kty: 'RSA'
    keyOps: [
      'encrypt'
      'decrypt'
      'sign'
      'verify'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: true
      exportable: false  // SECURE: Key cannot be exported
    }
  }
}

// Key for backup encryption
resource backupEncryptionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: 'htma-backup-encryption-key'
  properties: {
    keySize: 2048
    kty: 'RSA'
    keyOps: [
      'encrypt'
      'decrypt'
      'wrapKey'
      'unwrapKey'
    ]
    attributes: {
      enabled: true
      exportable: false
    }
  }
}

// Diagnostic settings for Key Vault audit logging
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 365  // SECURE: One year retention for audit logs
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90  // SECURE: 90 days for all logs
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output dataEncryptionKeyId string = dataEncryptionKey.id
output dataEncryptionKeyUri string = dataEncryptionKey.properties.keyUri
output backupEncryptionKeyId string = backupEncryptionKey.id
output backupEncryptionKeyUri string = backupEncryptionKey.properties.keyUri
