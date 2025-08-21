# Azure Integration & Deployment Guide

## 🎯 Overview

This guide walks you through deploying the HT-Management platform to Microsoft Azure using Azure Container Apps, Service Bus, Redis Cache, Cognitive Search, and OpenAI.

## 🏗️ Architecture

### Azure Services Used

| Service | Purpose | Local Equivalent |
|---------|---------|------------------|
| **Azure Container Apps** | Microservice hosting | Docker Compose |
| **Azure Service Bus** | Message queuing | RabbitMQ |
| **Azure Cache for Redis** | Caching & sessions | Redis |
| **Azure Cognitive Search** | Search & analytics | Elasticsearch |
| **Azure OpenAI** | AI insights | OpenAI API |
| **Azure Key Vault** | Secret management | Environment variables |
| **Azure Container Registry** | Image storage | Local Docker |
| **Application Insights** | Monitoring | Console logs |

### Microservices Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │────│  Express Gateway │────│ Azure Services │
│   (Next.js)     │    │   (API Gateway)  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │Work Item    │  │Dependency   │  │AI Insights  │
    │Service      │  │Service      │  │Service      │
    └─────────────┘  └─────────────┘  └─────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Azure CLI installed and logged in
- Docker Desktop running
- Node.js 18+ installed
- Access to Azure subscription

### 1. One-Click Deployment

```bash
# Clone and setup
git clone <repository>
cd HT-Management

# Deploy Azure infrastructure
./azure/scripts/deploy-dev.sh

# Build and push Docker images
./azure/scripts/build-and-push-images.sh

# Deploy container apps
./azure/scripts/deploy-container-apps.sh
```

### 2. Verify Deployment

```bash
# Check Container App status
az containerapp list --resource-group rg-htma-dev --output table

# Test endpoints
curl https://htma-express-gateway.kindpond-12345678.eastus.azurecontainerapps.io/health
```

## 📋 Detailed Setup

### Step 1: Azure Infrastructure Setup

The infrastructure is defined in Bicep templates and deployed automatically:

```bash
# Deploy all Azure resources
az deployment group create \
  --resource-group rg-htma-dev \
  --template-file azure/bicep/main.bicep \
  --parameters @azure/parameters.dev.json
```

**Resources Created:**
- Resource Group: `rg-htma-dev`
- Key Vault: `htma-dev-kv`
- Service Bus: `htma-dev-servicebus`
- Redis Cache: `htma-dev-redis`
- Cognitive Search: `htma-dev-search`
- OpenAI Service: `htma-dev-openai`
- Container Registry: `htmadevacr3898`
- Container Apps Environment: `htma-dev-container-env`

### Step 2: Application Configuration

The applications are configured to use Azure services instead of local infrastructure:

#### Key Vault Integration
```typescript
// Services retrieve secrets from Key Vault at runtime
const keyVault = new AzureKeyVaultService({
  vaultName: 'htma-dev-kv',
  vaultUri: 'https://htma-dev-kv.vault.azure.net/'
});

const apiKey = await keyVault.getSecret('openai-api-key');
```

#### Service Bus Messaging
```typescript
// Replace RabbitMQ with Azure Service Bus
const serviceBus = new AzureServiceBusService(connectionString);
await serviceBus.sendMessage('work-item-events', message);
```

#### Redis Caching
```typescript
// Connect to Azure Redis Cache
const redis = new AzureRedisService({
  host: 'htma-dev-redis.redis.cache.windows.net',
  port: 6380,
  ssl: true
});
```

### Step 3: Container Build & Push

Build Docker images and push to Azure Container Registry:

```bash
# Login to ACR
az acr login --name htmadevacr3898

# Build all services
docker build -t htmadevacr3898.azurecr.io/htma/work-item-service:latest services/work-item-service/
docker build -t htmadevacr3898.azurecr.io/htma/dependency-service:latest services/dependency-service/
docker build -t htmadevacr3898.azurecr.io/htma/ai-insights-service:latest services/ai-insights-service/
docker build -t htmadevacr3898.azurecr.io/htma/express-gateway:latest services/express-gateway/

# Push to ACR
docker push htmadevacr3898.azurecr.io/htma/work-item-service:latest
docker push htmadevacr3898.azurecr.io/htma/dependency-service:latest
docker push htmadevacr3898.azurecr.io/htma/ai-insights-service:latest
docker push htmadevacr3898.azurecr.io/htma/express-gateway:latest
```

### Step 4: Container Apps Deployment

Deploy to Azure Container Apps:

```bash
# Update each Container App
az containerapp update \
  --name htma-work-item-service \
  --resource-group rg-htma-dev \
  --image htmadevacr3898.azurecr.io/htma/work-item-service:latest

az containerapp update \
  --name htma-dependency-service \
  --resource-group rg-htma-dev \
  --image htmadevacr3898.azurecr.io/htma/dependency-service:latest

az containerapp update \
  --name htma-ai-insights-service \
  --resource-group rg-htma-dev \
  --image htmadevacr3898.azurecr.io/htma/ai-insights-service:latest

az containerapp update \
  --name htma-express-gateway \
  --resource-group rg-htma-dev \
  --image htmadevacr3898.azurecr.io/htma/express-gateway:latest
```

## 🔐 Security & Configuration

### Environment Variables

Container Apps are configured with environment variables that reference Azure services:

```bash
NODE_ENV=development
AZURE_KEY_VAULT_URI=https://htma-dev-kv.vault.azure.net/
AZURE_SERVICE_BUS_NAMESPACE=htma-dev-servicebus
AZURE_REDIS_HOST=htma-dev-redis.redis.cache.windows.net
AZURE_OPENAI_ENDPOINT=https://htma-dev-openai.openai.azure.com/
```

### Secrets Management

Sensitive values are stored in Azure Key Vault:

| Secret Name | Purpose |
|-------------|---------|
| `servicebus-connection` | Service Bus connection string |
| `redis-connection` | Redis connection string |
| `search-admin-key` | Cognitive Search admin key |
| `openai-api-key` | Azure OpenAI API key |
| `acr-username` | Container Registry username |
| `acr-password` | Container Registry password |

### Authentication

Azure Managed Identity is used for authentication between services:

```typescript
// Services authenticate automatically using Managed Identity
const credential = new DefaultAzureCredential();
const client = new SecretClient(keyVaultUri, credential);
```

## 📊 Monitoring & Observability

### Application Insights

All services send telemetry to Application Insights:

```typescript
// Automatic instrumentation
const appInsights = require('applicationinsights');
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING);
appInsights.start();
```

### Health Checks

Each service exposes health check endpoints:

```bash
# Check service health
curl https://htma-work-item-service.kindpond-12345678.eastus.azurecontainerapps.io/health
curl https://htma-dependency-service.kindpond-12345678.eastus.azurecontainerapps.io/health
curl https://htma-ai-insights-service.kindpond-12345678.eastus.azurecontainerapps.io/health
curl https://htma-express-gateway.kindpond-12345678.eastus.azurecontainerapps.io/health
```

### Logging

View application logs:

```bash
# View logs for specific service
az containerapp logs show \
  --name htma-work-item-service \
  --resource-group rg-htma-dev \
  --tail 50

# Follow logs in real-time
az containerapp logs show \
  --name htma-ai-insights-service \
  --resource-group rg-htma-dev \
  --follow
```

## 🔧 Local Development with Azure Services

Use Azure services during local development:

```bash
# Run locally with Azure integration
docker-compose -f docker-compose.azure.yml up --build

# Or run individual services
cd services/ai-insights-service
npm run dev
```

### Environment Setup

Create local environment file:

```bash
# Copy Azure environment template
cp services/ai-insights-service/azure.env services/ai-insights-service/.env

# Login to Azure for local development
az login
```

## 🚀 Scaling & Performance

### Auto-scaling

Container Apps can scale automatically:

```bash
# Configure auto-scaling
az containerapp update \
  --name htma-work-item-service \
  --resource-group rg-htma-dev \
  --min-replicas 1 \
  --max-replicas 10 \
  --scale-rule-name "http-rule" \
  --scale-rule-type "http" \
  --scale-rule-metadata "concurrentRequests=50"
```

### Resource Limits

Configure CPU and memory limits:

```bash
# Update resource allocation
az containerapp update \
  --name htma-ai-insights-service \
  --resource-group rg-htma-dev \
  --cpu 1.0 \
  --memory 2.0Gi
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Key Vault Access Denied
```bash
# Grant access to Key Vault
az keyvault set-policy \
  --name htma-dev-kv \
  --object-id $(az account show --query user.objectId -o tsv) \
  --secret-permissions get list set
```

#### 2. Container App Deployment Failed
```bash
# Check deployment logs
az containerapp logs show --name htma-work-item-service --resource-group rg-htma-dev

# Restart container app
az containerapp restart --name htma-work-item-service --resource-group rg-htma-dev
```

#### 3. Service Bus Connection Issues
```bash
# Verify Service Bus namespace
az servicebus namespace show --name htma-dev-servicebus --resource-group rg-htma-dev

# Check queue status
az servicebus queue show --namespace-name htma-dev-servicebus --name work-item-events --resource-group rg-htma-dev
```

### Debug Commands

```bash
# List all resources
az resource list --resource-group rg-htma-dev --output table

# Check Container App environment
az containerapp env show --name htma-dev-container-env --resource-group rg-htma-dev

# View Key Vault secrets
az keyvault secret list --vault-name htma-dev-kv --output table

# Test connectivity
az network vnet list --resource-group rg-htma-dev
```

## 📈 Performance Monitoring

### Metrics Dashboard

View performance metrics in Azure Portal:
- Application Insights → Performance
- Container Apps → Metrics
- Service Bus → Metrics
- Redis Cache → Metrics

### Key Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| Response Time | > 2s | Scale up |
| Error Rate | > 5% | Investigate logs |
| CPU Usage | > 80% | Scale out |
| Memory Usage | > 85% | Increase memory |
| Queue Length | > 100 | Scale processors |

## 🔄 CI/CD Pipeline

### GitHub Actions (Optional)

Create automated deployment pipeline:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Azure
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Build and push images
        run: ./azure/scripts/build-and-push-images.sh
      - name: Deploy to Container Apps
        run: ./azure/scripts/deploy-container-apps.sh
```

## 📞 Support

### Resources

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Azure Service Bus Documentation](https://docs.microsoft.com/azure/service-bus/)
- [Azure OpenAI Documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)

### Commands Reference

```bash
# Quick deployment
./azure/scripts/deploy-dev.sh && ./azure/scripts/build-and-push-images.sh && ./azure/scripts/deploy-container-apps.sh

# Check all services
az containerapp list --resource-group rg-htma-dev --query '[].{Name:name,Status:properties.runningStatus,FQDN:properties.configuration.ingress.fqdn}' --output table

# Clean up resources
az group delete --name rg-htma-dev --yes --no-wait
```

---

🎉 **Your HT-Management platform is now running on Azure with enterprise-grade scalability, security, and monitoring!**
