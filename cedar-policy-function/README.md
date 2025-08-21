# Cedar Policy Function App

This Azure Function App provides Cedar policy evaluation services for the HTMA platform, integrated with Azure API Gateway for centralized policy enforcement.

## Architecture Overview

The Cedar Policy integration follows this flow:

1. **API Request** → Azure API Gateway
2. **JWT Validation** → Azure API Gateway validates JWT tokens
3. **Policy Evaluation** → API Gateway calls Cedar Policy Function
4. **Access Decision** → Function returns allow/deny decision
5. **Request Processing** → API Gateway enforces the decision

## Features

### Policy Evaluation
- **Work Item Access Control** - Controls who can read, update, and delete work items
- **Lineage Enforcement** - Ensures work items have proper parent relationships
- **Admin Access Control** - Restricts administrative functions to authorized users
- **Tenant Isolation** - Policies are scoped to specific tenants

### Caching
- **Redis Integration** - Policies are cached for performance
- **Configurable TTL** - Cache expiration can be adjusted
- **Automatic Refresh** - Cache TTL is refreshed on access

### Monitoring
- **Health Checks** - Built-in health monitoring endpoints
- **Performance Metrics** - Request duration and policy evaluation timing
- **Structured Logging** - JSON-formatted logs with correlation IDs

## API Endpoints

### POST /api/evaluatePolicy
Evaluates a Cedar policy for authorization decisions.

**Request Body:**
```json
{
  "principal": {
    "id": "user123",
    "tenant_id": "tenant456",
    "roles": ["Manager", "User"]
  },
  "action": {
    "id": "read"
  },
  "resource": {
    "id": "/api/work-items/789",
    "type": "work_item"
  },
  "context": {
    "tenant_id": "tenant456",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

**Response:**
```json
{
  "success": true,
  "allowed": true,
  "policy_id": "work-item-access",
  "evaluation_time": 45,
  "request_id": "req_123",
  "metadata": {
    "reason": "Read access allowed for same tenant"
  }
}
```

### GET /api/health
Health check endpoint for monitoring.

### GET /api/getPolicies?tenant_id={tenantId}
Retrieves policies for a specific tenant.

### POST /api/createPolicy
Creates a new Cedar policy.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `CEDAR_POLICY_CACHE_TTL` | Policy cache TTL in seconds | `300` |
| `LOG_LEVEL` | Logging level | `info` |
| `NODE_ENV` | Environment | `development` |

### Local Development

1. **Install Dependencies:**
   ```bash
   npm install
   ```

2. **Start Redis:**
   ```bash
   docker run -d -p 6379:6379 redis:alpine
   ```

3. **Run Function App:**
   ```bash
   npm start
   ```

4. **Test Endpoints:**
   ```bash
   curl -X POST http://localhost:7071/api/evaluatePolicy \
     -H "Content-Type: application/json" \
     -d '{"principal":{"id":"user1","tenant_id":"tenant1","roles":["User"]},"action":{"id":"read"},"resource":{"id":"/api/work-items/1","type":"work_item"},"context":{"tenant_id":"tenant1","timestamp":"2024-01-01T00:00:00Z"}}'
   ```

## Azure API Gateway Integration

The Cedar Policy Function integrates with Azure API Gateway through custom policies:

### Policy Flow
1. **JWT Validation** - Validates Azure AD JWT tokens
2. **User Context Extraction** - Extracts user information from JWT
3. **Policy Evaluation** - Calls Cedar Policy Function
4. **Access Control** - Enforces policy decisions
5. **Fallback Authorization** - Role-based fallback if Cedar service unavailable

### Policy Configuration
The API Gateway policy includes:
- JWT validation with Azure AD
- User context extraction
- Cedar policy evaluation calls
- Access decision enforcement
- Fallback role-based authorization

## Deployment

### Azure Functions
1. **Build the Function App:**
   ```bash
   npm run build
   ```

2. **Deploy to Azure:**
   ```bash
   func azure functionapp publish htma-cedar-policy
   ```

### Azure API Gateway
1. **Import API Management policies**
2. **Configure JWT validation**
3. **Set up Cedar policy endpoints**
4. **Test policy evaluation**

## Security Considerations

### JWT Validation
- Validates Azure AD JWT tokens
- Checks required claims (aud, iss)
- Extracts user context securely

### Policy Isolation
- Policies are tenant-scoped
- No cross-tenant policy access
- Secure policy storage and caching

### Error Handling
- Fail-secure approach (deny on error)
- Comprehensive error logging
- Fallback authorization mechanisms

## Monitoring and Observability

### Application Insights
- Request telemetry
- Performance metrics
- Error tracking
- Dependency monitoring

### Health Checks
- Redis connectivity
- Policy engine health
- Function app status
- Cache performance

### Logging
- Structured JSON logging
- Correlation IDs
- Performance metrics
- Security events

## Future Enhancements

### Cedar Engine Integration
- Replace simplified engine with actual Cedar policy engine
- Support for complex policy expressions
- Policy validation and testing

### Advanced Caching
- Policy compilation caching
- Result caching for repeated evaluations
- Distributed cache support

### Policy Management
- Policy versioning
- Policy deployment pipelines
- Policy testing framework
- Policy analytics and reporting

## Troubleshooting

### Common Issues

1. **Redis Connection Failed**
   - Check Redis URL configuration
   - Verify Redis service is running
   - Check network connectivity

2. **Policy Evaluation Timeout**
   - Increase function timeout in host.json
   - Check policy complexity
   - Monitor Redis performance

3. **JWT Validation Errors**
   - Verify Azure AD configuration
   - Check token expiration
   - Validate required claims

### Debug Mode
Enable debug logging by setting `LOG_LEVEL=debug` and check the function logs for detailed information.

## Support

For issues and questions:
1. Check the function logs
2. Review Azure Monitor metrics
3. Test individual endpoints
4. Verify configuration settings
