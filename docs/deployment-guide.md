# Azure Development Deployment Guide

## 🚀 HT-Management Azure Development Environment Setup

This guide walks you through deploying the HT-Management platform to Azure for development.

### Prerequisites Checklist

- [ ] Azure subscription with Contributor access
- [ ] Azure CLI installed (`brew install azure-cli` on macOS)
- [ ] Git repository access
- [ ] OpenAI API key

### 📋 Step-by-Step Deployment

#### Step 1: Verify Azure CLI Installation

```bash
# Check if Azure CLI is installed
az --version

# If not installed, install it:
# macOS: brew install azure-cli
# Windows: Download from https://aka.ms/installazurecliwindows
```

#### Step 2: Login to Azure

```bash
# Login to your Azure account
az login

# List available subscriptions
az account list --output table

# Set your preferred subscription
az account set --subscription "your-subscription-id"

# Verify current subscription
az account show
```

#### Step 3: Prepare Deployment Parameters

You'll need these parameters during deployment:

- **PostgreSQL Admin Username**: Choose a secure username (not 'admin', 'root', etc.)
- **PostgreSQL Admin Password**: Strong password (8+ chars, mixed case, numbers, symbols)
- **MongoDB Admin Username**: Secure username for MongoDB
- **MongoDB Admin Password**: Strong password for MongoDB  
- **OpenAI API Key**: Your OpenAI API key for AI services

#### Step 4: Run Deployment Script

```bash
# Navigate to project directory
cd /Users/wyattfrelot/HT-Management

# Run the deployment script
./azure/scripts/deploy-dev.sh
```

The script will:
1. ✅ Check prerequisites
2. ✅ Prompt for deployment parameters
3. ✅ Create resource group
4. ✅ Validate Bicep templates
5. ✅ Deploy infrastructure (15-20 minutes)
6. ✅ Configure secrets in Key Vault
7. ✅ Generate environment configuration

### 🏗️ Infrastructure Components Being Deployed

| Component | Azure Service | Purpose |
|-----------|---------------|---------|
| **Database** | PostgreSQL Flexible Server | Primary transactional data |
| **Document Store** | Cosmos DB (MongoDB API) | AI responses, analytics |
| **Cache** | Azure Cache for Redis | Session storage, caching |
| **Search** | Azure Cognitive Search | Full-text search, analytics |
| **Messaging** | Azure Service Bus | Inter-service communication |
| **AI Services** | Azure OpenAI | GPT-4o-mini, embeddings |
| **Compute** | Azure Container Apps | Microservices hosting |
| **Frontend** | Azure Static Web Apps | Next.js frontend |
| **Monitoring** | Application Insights | Logging, metrics, alerts |
| **Security** | Azure Key Vault | Secrets management |

### 💰 Expected Costs (Development)

| Service | Monthly Cost (USD) |
|---------|-------------------|
| PostgreSQL (Basic) | ~$25 |
| Cosmos DB (Serverless) | ~$10 |
| Redis (Standard C0) | ~$16 |
| Cognitive Search (Basic) | ~$100 |
| Service Bus (Standard) | ~$10 |
| Azure OpenAI | ~$50-200 |
| Container Apps | ~$20 |
| Static Web Apps | Free |
| Application Insights | ~$5 |
| Key Vault | ~$1 |
| **Total** | **~$237-387** |

### 🔧 Post-Deployment Steps

After successful deployment:

#### 1. Verify Infrastructure
```bash
# List all resources
az resource list --resource-group rg-htma-dev --output table

# Check Key Vault secrets
az keyvault secret list --vault-name htma-dev-kv --output table
```

#### 2. Set Up Database Schema
```bash
# Use the generated .env.azure file
source .env.azure

# Run database migrations (manual step)
# Connect to PostgreSQL and run schema scripts
```

#### 3. Build and Deploy Container Images
The deployment creates the infrastructure but containers need to be built:

```bash
# Build services (next phase)
# docker build -t htma/work-item-service:latest services/work-item-service/
# docker build -t htma/dependency-service:latest services/dependency-service/
# docker build -t htma/ai-insights-service:latest services/ai-insights-service/
# docker build -t htma/express-gateway:latest services/express-gateway/
```

### 🚨 Troubleshooting

#### Common Issues:

**1. Deployment Fails - Resource Names**
```bash
# Resource names must be globally unique
# Script automatically generates unique names with timestamps
```

**2. Insufficient Permissions**
```bash
# Ensure you have Contributor role on subscription
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

**3. Quota Limits**
```bash
# Check regional quota limits
az vm list-usage --location eastus --output table
```

**4. OpenAI Service Availability**
```bash
# OpenAI service is only available in certain regions
# Script deploys to East US for availability
```

### 🔗 Useful Commands

```bash
# View deployment status
az deployment group show --resource-group rg-htma-dev --name [deployment-name]

# View Container Apps
az containerapp list --resource-group rg-htma-dev --output table

# View Static Web App
az staticwebapp show --resource-group rg-htma-dev --name htma-dev-webapp

# View Key Vault secrets
az keyvault secret list --vault-name htma-dev-kv

# Monitor deployment logs
az monitor activity-log list --resource-group rg-htma-dev
```

### 🔄 Clean Up (If Needed)

To remove all resources:
```bash
# Delete entire resource group (careful!)
az group delete --name rg-htma-dev --yes --no-wait
```

### 📞 Support

If you encounter issues:
1. Check Azure Activity Log for error details
2. Verify subscription limits and quotas
3. Ensure all prerequisites are met
4. Check regional service availability

---

**Ready to deploy?** Run `./azure/scripts/deploy-dev.sh` when you're prepared!
