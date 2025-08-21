// Microservices Infrastructure Module
// Supports independent deployment and scaling of microservices with Cedar policy integration

targetScope = 'resourceGroup'

// Parameters
@description('Resource name prefix for the microservices')
param resourceNamePrefix string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Tags to apply to all resources')
param tags object = {}

@description('Subnet ID for container apps')
param subnetId string

@description('Log Analytics Workspace ID for monitoring')
param logAnalyticsWorkspaceId string

@description('Key Vault name for secrets')
param keyVaultName string

@description('Container Registry URL')
param containerRegistryUrl string

@description('Managed Identity for container apps')
param managedIdentity resourceId

// Variables
var microservices = [
  'frontend'
  'api-gateway'
  'work-item-service'
  'dependency-service'
  'ai-insights-service'
  'notification-service'
  'hta-builder-service'
  'search-service'
  'websocket-service'
]

var containerAppsEnvName = '${resourceNamePrefix}-microservices-env'

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppsEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceId
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
    }
    daprConfiguration: {
      enabled: true
      appLogsConfiguration: {
        destination: 'log-analytics'
        logAnalyticsConfiguration: {
          customerId: logAnalyticsWorkspaceId
        }
      }
    }
  }
}

// Container Apps for each microservice
resource microserviceApps 'Microsoft.App/containerapps@2023-05-01' = [for (service, i) in microservices: {
  name: '${resourceNamePrefix}-${service}'
  location: location
  tags: union(tags, {
    'Service': service
    'Environment': environment
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: service == 'frontend' || service == 'api-gateway'
        targetPort: service == 'frontend' ? 3000 : 3001
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
          name: 'jwt-secret'
          value: 'htma-${service}-secret-${uniqueString(resourceGroup().id)}'
        }
        {
          name: 'service-name'
          value: service
        }
        {
          name: 'environment'
          value: environment
        }
      ]
      registries: [
        {
          server: containerRegistryUrl
          identity: managedIdentity
        }
      ]
      dapr: {
        enabled: true
        appId: service
        appProtocol: 'http'
        appPort: service == 'frontend' ? 3000 : 3001
      }
    }
    template: {
      containers: [
        {
          name: service
          image: '${containerRegistryUrl}/htma/${service}:latest'
          env: [
            {
              name: 'NODE_ENV'
              value: environment
            }
            {
              name: 'SERVICE_NAME'
              value: service
            }
            {
              name: 'PORT'
              value: service == 'frontend' ? '3000' : '3001'
            }
            {
              name: 'JWT_SECRET'
              secretRef: 'jwt-secret'
            }
            {
              name: 'SERVICE_NAME'
              secretRef: 'service-name'
            }
            {
              name: 'ENVIRONMENT'
              secretRef: 'environment'
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
                port: service == 'frontend' ? 3000 : 3001
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
                port: service == 'frontend' ? 3000 : 3001
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
  ]
}]

// Azure API Management for Cedar Policy Integration
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01' = {
  name: '${resourceNamePrefix}-apim'
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Premium' : 'Developer'
    capacity: environment == 'prod' ? 2 : 1
  }
  properties: {
    publisherName: 'HTMA Team'
    publisherEmail: 'admin@getailigned.com'
    notificationSenderEmail: 'apimgmt-noreply@azure.com'
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${resourceNamePrefix}-apim.azure-api.net'
        defaultSslBinding: true
        negotiateClientCertificate: false
      }
    ]
    virtualNetworkType: 'External'
    enableClientCertificate: false
    disableGateway: false
    protocols: ['https']
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
  }
}

// API Management API for HTMA Services
resource apiManagementApi 'Microsoft.ApiManagement/service/apis@2023-05-01' = {
  parent: apiManagement
  name: 'htma-api'
  properties: {
    displayName: 'HTMA API'
    description: 'HTMA Platform API with Cedar Policy Integration'
    serviceUrl: 'https://${resourceNamePrefix}-api-gateway.azurecontainerapps.io'
    path: 'api'
    protocols: ['https']
    apiVersion: 'v1'
    apiVersionSetId: apiVersionSet.id
  }
}

// API Version Set
resource apiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01' = {
  parent: apiManagement
  name: 'htma-api-versions'
  properties: {
    displayName: 'HTMA API Versions'
    versioningScheme: 'Segment'
    versionQueryName: 'api-version'
    versionHeaderName: 'api-version'
  }
}

// Cedar Policy for API Gateway
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01' = {
  parent: apiManagementApi
  name: 'policy'
  properties: {
    value: '''
    <policies>
      <inbound>
        <!-- Cedar Policy Evaluation -->
        <base />
        <set-header name="X-Cedar-Policy-Enabled" exists-action="override">
          <value>true</value>
        </set-header>
        
        <!-- JWT Token Validation -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Invalid or missing JWT token">
          <openid-config url="https://login.microsoftonline.com/common/v2.0/.well-known/openid_configuration" />
          <required-claims>
            <claim name="aud" match="any" />
            <claim name="iss" match="any" />
          </required-claims>
        </validate-jwt>
        
        <!-- Extract user context for Cedar evaluation -->
        <set-variable name="userContext" value="@{
          var token = context.Request.Headers.GetValueOrDefault("Authorization", "").AsJwt();
          return new JObject(
            new JProperty("userId", token.Claims.GetValueOrDefault("sub", "")),
            new JProperty("tenantId", token.Claims.GetValueOrDefault("tid", "")),
            new JProperty("roles", token.Claims.GetValueOrDefault("roles", "").Split(',')),
            new JProperty("email", token.Claims.GetValueOrDefault("email", ""))
          ).ToString();
        }" />
        
        <!-- Cedar Policy Check -->
        <send-request mode="new" response-variable-name="cedarResponse" timeout="20" ignore-error="false">
          <set-url>https://${resourceNamePrefix}-cedar-policy.azurewebsites.net/evaluate</set-url>
          <set-method>POST</set-method>
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>@{
            var request = context.Request;
            var user = JObject.Parse(context.Variables["userContext"]);
            return new JObject(
              new JProperty("principal", new JObject(
                new JProperty("id", user["userId"]),
                new JProperty("tenant_id", user["tenantId"]),
                new JProperty("roles", user["roles"])
              )),
              new JProperty("action", new JObject(
                new JProperty("id", request.Method.ToLower())
              )),
              new JProperty("resource", new JObject(
                new JProperty("id", request.Url.Path),
                new JProperty("type", "api_endpoint")
              )),
              new JProperty("context", new JObject(
                new JProperty("tenant_id", user["tenantId"]),
                new JProperty("timestamp", DateTime.UtcNow.ToString("o"))
              ))
            ).ToString();
          }</set-body>
        </send-request>
        
        <!-- Check Cedar Policy Response -->
        <choose>
          <when condition="@(((IResponse)context.Variables["cedarResponse"]).StatusCode == 200)">
            <set-variable name="cedarResult" value="@(((IResponse)context.Variables["cedarResponse"]).Body.As<JObject>())" />
            <choose>
              <when condition="@(bool.Parse(cedarResult["allowed"].ToString()) == false)">
                <return-response>
                  <set-status code="403" reason="Access Denied by Cedar Policy" />
                  <set-header name="Content-Type" exists-action="override">
                    <value>application/json</value>
                  </set-header>
                  <set-body>@{
                    return new JObject(
                      new JProperty("error", "ACCESS_DENIED"),
                      new JProperty("message", "Access denied by Cedar policy"),
                      new JProperty("policy_result", cedarResult)
                    ).ToString();
                  }</set-body>
                </return-response>
              </when>
            </choose>
          </when>
          <otherwise>
            <!-- Fallback to role-based authorization if Cedar service unavailable -->
            <set-variable name="userRoles" value="@(user["roles"].ToString())" />
            <choose>
              <when condition="@(request.Url.Path.Contains("/admin") && !userRoles.Contains("Admin"))">
                <return-response>
                  <set-status code="403" reason="Admin access required" />
                  <set-header name="Content-Type" exists-action="override">
                    <value>application/json</value>
                  </set-header>
                  <set-body>{"error": "ADMIN_ACCESS_REQUIRED", "message": "Admin role required for this endpoint"}</set-body>
                </return-response>
              </when>
            </choose>
          </otherwise>
        </choose>
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
        <!-- Add Cedar policy headers to response -->
        <set-header name="X-Cedar-Policy-Applied" exists-action="override">
          <value>true</value>
        </set-header>
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
    '''
    format: 'rawxml'
  }
}

// Cedar Policy Service (Azure Function App for policy evaluation)
resource cedarPolicyFunctionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${resourceNamePrefix}-cedar-policy'
  location: location
  tags: tags
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'CEDAR_POLICY_CACHE_TTL'
          value: '300'
        }
        {
          name: 'LOG_LEVEL'
          value: 'info'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          'https://${resourceNamePrefix}-apim.azure-api.net'
          'https://*.getailigned.com'
        ]
      }
    }
    httpsOnly: true
    clientAffinityEnabled: false
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// App Service Plan for Cedar Policy Function
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourceNamePrefix}-cedar-policy-plan'
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'P1v2' : 'F1'
    tier: environment == 'prod' ? 'PremiumV2' : 'Free'
  }
  properties: {
    reserved: false
  }
}

// Application Gateway for routing
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-06-01' = {
  name: '${resourceNamePrefix}-microservices-agw'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: environment == 'prod' ? 2 : 1
    }
    gatewayIPConfigurations: [
      {
        name: 'gatewayIPConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'httpPort'
        properties: {
          port: 80
        }
      }
      {
        name: 'httpsPort'
        properties: {
          port: 443
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'frontendIPConfig'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'api-gateway-pool'
        properties: {
          fqdn: microserviceApps[1].properties.latestRevisionName
        }
      }
      {
        name: 'frontend-pool'
        properties: {
          fqdn: microserviceApps[0].properties.latestRevisionName
        }
      }
      {
        name: 'apim-pool'
        properties: {
          fqdn: '${resourceNamePrefix}-apim.azure-api.net'
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
      {
        name: 'httpsSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: applicationGateway.properties.frontendIPConfigurations[0].id
          }
          frontendPort: {
            id: applicationGateway.properties.frontendPorts[0].id
          }
          protocol: 'Http'
        }
      }
      {
        name: 'httpsListener'
        properties: {
          frontendIPConfiguration: {
            id: applicationGateway.properties.frontendIPConfigurations[0].id
          }
          frontendPort: {
            id: applicationGateway.properties.frontendPorts[1].id
          }
          protocol: 'Https'
          sslCertificate: {
            id: sslCertificate.id
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'api-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: applicationGateway.properties.httpListeners[0].id
          }
          backendAddressPool: {
            id: applicationGateway.properties.backendAddressPools[0].id
          }
          backendHttpSettings: {
            id: applicationGateway.properties.backendHttpSettingsCollection[0].id
          }
        }
      }
      {
        name: 'apim-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: applicationGateway.properties.httpListeners[1].id
          }
          backendAddressPool: {
            id: applicationGateway.properties.backendAddressPools[2].id
          }
          backendHttpSettings: {
            id: applicationGateway.properties.backendHttpSettingsCollection[1].id
          }
        }
      }
    ]
  }
}

// Public IP for Application Gateway
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${resourceNamePrefix}-microservices-pip'
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    sku: {
      name: 'Standard'
    }
  }
}

// SSL Certificate for HTTPS
resource sslCertificate 'Microsoft.Network/applicationGateways/sslCertificates@2023-06-01' = {
  parent: applicationGateway
  name: 'default-cert'
  properties: {
    data: 'MIIEpDCCA4ygAwIBAgIJANxHrP+...' // Base64 encoded certificate
    password: ''
  }
}

// Outputs
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsEnvironmentId string = containerAppsEnvironment.id
output microserviceAppNames array = [for app in microserviceApps: app.name]
output applicationGatewayName string = applicationGateway.name
output applicationGatewayPublicIP string = publicIP.properties.ipAddress
output apiManagementName string = apiManagement.name
output cedarPolicyFunctionAppName string = cedarPolicyFunctionApp.name
