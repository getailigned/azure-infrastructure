# Docker Deployment Guide for HTMA Platform

This guide covers the deployment of HTMA microservices using Docker and Azure Container Registry (ACR).

## 🚀 **Prerequisites**

- Docker installed and running
- Azure CLI installed and configured
- Access to Azure Container Registry
- HTMA microservices source code

## 📋 **Step-by-Step Deployment**

### **Step 1: Authenticate with Azure Container Registry**

```bash
# Option A: Using Azure CLI (recommended)
az acr login --name <your-acr-name>

# Option B: Using Docker login with stored credentials
docker login <your-acr-name>.azurecr.io -u <your-acr-username> -p <your-acr-password>
```

### **Step 2: Build and Tag Images**

```bash
# Navigate to your project root
cd /path/to/your/project

# Build each microservice image
docker build -t <your-acr-name>.azurecr.io/htma/work-item-service:latest services/work-item-service/
docker build -t <your-acr-name>.azurecr.io/htma/dependency-service:latest services/dependency-service/
docker build -t <your-acr-name>.azurecr.io/htma/ai-insights-service:latest services/ai-insights-service/
docker build -t <your-acr-name>.azurecr.io/htma/express-gateway:latest services/express-gateway/
```

### **Step 3: Push Images to ACR**

```bash
# Push all microservice images
docker push <your-acr-name>.azurecr.io/htma/work-item-service:latest
docker push <your-acr-name>.azurecr.io/htma/dependency-service:latest
docker push <your-acr-name>.azurecr.io/htma/ai-insights-service:latest
docker push <your-acr-name>.azurecr.io/htma/express-gateway:latest
```

### **Step 4: Verify Images**

```bash
# List repositories in ACR
az acr repository list --name <your-acr-name> --output table

# List tags for a specific repository
az acr repository show-tags --name <your-acr-name> --repository htma/work-item-service --output table
```

## 📝 **Required Dockerfiles**

Make sure each service has a `Dockerfile`. Here are templates:

### **Work Item Service Dockerfile**
```dockerfile
# services/work-item-service/Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

CMD ["npm", "start"]
```

## 🔧 **Environment Configuration**

### **Environment Variables**
Each service requires specific environment variables. Create `.env` files for each service:

```bash
# services/work-item-service/.env
NODE_ENV=production
PORT=3001
DATABASE_URL=postgresql://user:password@host:port/database
REDIS_URL=redis://host:port
LOG_LEVEL=info
```

## 🚀 **Production Deployment**

### **Azure Container Apps**
For production deployment, use Azure Container Apps:

```bash
# Deploy to Azure Container Apps
az containerapp create \
  --name htma-work-item-service \
  --resource-group htma-rg \
  --image <your-acr-name>.azurecr.io/htma/work-item-service:latest \
  --target-port 3001 \
  --ingress external \
  --registry-server <your-acr-name>.azurecr.io \
  --registry-username <your-acr-username> \
  --registry-password <your-acr-password>
```

## 🔍 **Monitoring and Health Checks**

### **Health Check Endpoints**
Each service should expose a health check endpoint:

```typescript
// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0'
  });
});
```

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Image Build Failures**
   - Check Dockerfile syntax
   - Verify all required files are present
   - Check for syntax errors in source code

2. **Container Startup Failures**
   - Check environment variables
   - Verify database connectivity
   - Check port conflicts

### **Debug Commands**

```bash
# Check container logs
docker logs <container-id>

# Execute commands in running container
docker exec -it <container-id> /bin/sh

# Check container resource usage
docker stats
```

## 📚 **Additional Resources**

- [Docker Documentation](https://docs.docker.com/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
