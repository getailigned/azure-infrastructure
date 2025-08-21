import { app, HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions'
import { CedarPolicyEngine } from './services/cedarPolicyEngine'
import { PolicyCacheService } from './services/policyCacheService'
import { LoggerService } from './services/loggerService'

// Initialize services
const logger = new LoggerService()
const policyCache = new PolicyCacheService()
const cedarEngine = new CedarPolicyEngine(policyCache, logger)

// Cedar Policy Evaluation Function
app.http('evaluatePolicy', {
  methods: ['POST'],
  authLevel: 'anonymous',
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    try {
      const startTime = Date.now()
      
      // Parse request body
      const body = await request.json()
      const { principal, action, resource, context: requestContext } = body

      // Validate required fields
      if (!principal || !action || !resource) {
        logger.warn('Missing required fields in policy evaluation request', { body })
        return {
          status: 400,
          body: JSON.stringify({
            success: false,
            error: 'MISSING_REQUIRED_FIELDS',
            message: 'Principal, action, and resource are required'
          })
        }
      }

      // Extract tenant ID for policy scope
      const tenantId = principal.tenant_id || requestContext?.tenant_id
      if (!tenantId) {
        logger.warn('Missing tenant ID in policy evaluation request', { body })
        return {
          status: 400,
          body: JSON.stringify({
            success: false,
            error: 'MISSING_TENANT_ID',
            message: 'Tenant ID is required for policy evaluation'
          })
        }
      }

      // Evaluate policy using Cedar engine
      const result = await cedarEngine.evaluatePolicy(principal, action, resource, requestContext)
      
      // Record metrics
      const evaluationTime = Date.now() - startTime
      logger.info('Policy evaluation completed', {
        tenantId,
        principal: principal.id,
        action: action.id,
        resource: resource.id,
        result: result.allowed,
        evaluationTime,
        requestId: context.invocationId
      })

      return {
        status: 200,
        body: JSON.stringify({
          success: true,
          allowed: result.allowed,
          policy_id: result.policy_id,
          evaluation_time: evaluationTime,
          request_id: context.invocationId,
          metadata: result.metadata
        })
      }

    } catch (error) {
      logger.error('Policy evaluation failed', {
        error: error instanceof Error ? error.message : 'Unknown error',
        requestId: context.invocationId
      })

      return {
        status: 500,
        body: JSON.stringify({
          success: false,
          error: 'EVALUATION_FAILED',
          message: 'Policy evaluation failed',
          request_id: context.invocationId
        })
      }
    }
  }
})

// Health Check Function
app.http('health', {
  methods: ['GET'],
  authLevel: 'anonymous',
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    try {
      // Check service health
      const cacheHealth = await policyCache.isHealthy()
      const engineHealth = cedarEngine.isHealthy()
      
      const isHealthy = cacheHealth && engineHealth
      
      return {
        status: isHealthy ? 200 : 503,
        body: JSON.stringify({
          status: isHealthy ? 'healthy' : 'unhealthy',
          timestamp: new Date().toISOString(),
          services: {
            policy_cache: cacheHealth ? 'healthy' : 'unhealthy',
            cedar_engine: engineHealth ? 'healthy' : 'unhealthy'
          },
          request_id: context.invocationId
        })
      }
    } catch (error) {
      logger.error('Health check failed', {
        error: error instanceof Error ? error.message : 'Unknown error',
        requestId: context.invocationId
      })

      return {
        status: 503,
        body: JSON.stringify({
          status: 'unhealthy',
          error: 'HEALTH_CHECK_FAILED',
          message: 'Health check failed',
          request_id: context.invocationId
        })
      }
    }
  }
})

// Policy Management Functions
app.http('getPolicies', {
  methods: ['GET'],
  authLevel: 'anonymous',
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    try {
      const tenantId = request.query.get('tenant_id')
      if (!tenantId) {
        return {
          status: 400,
          body: JSON.stringify({
            success: false,
            error: 'MISSING_TENANT_ID',
            message: 'Tenant ID is required'
          })
        }
      }

      const policies = await cedarEngine.getPolicies(tenantId)
      
      return {
        status: 200,
        body: JSON.stringify({
          success: true,
          policies,
          count: policies.length
        })
      }
    } catch (error) {
      logger.error('Failed to get policies', {
        error: error instanceof Error ? error.message : 'Unknown error',
        requestId: context.invocationId
      })

      return {
        status: 500,
        body: JSON.stringify({
          success: false,
          error: 'GET_POLICIES_FAILED',
          message: 'Failed to retrieve policies'
        })
      }
    }
  }
})

app.http('createPolicy', {
  methods: ['POST'],
  authLevel: 'anonymous',
  handler: async (request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> => {
    try {
      const body = await request.json()
      const { policy, tenant_id } = body

      if (!policy || !tenant_id) {
        return {
          status: 400,
          body: JSON.stringify({
            success: false,
            error: 'MISSING_REQUIRED_FIELDS',
            message: 'Policy and tenant_id are required'
          })
        }
      }

      const result = await cedarEngine.createPolicy(policy, tenant_id)
      
      return {
        status: 201,
        body: JSON.stringify({
          success: true,
          policy_id: result.policy_id,
          message: 'Policy created successfully'
        })
      }
    } catch (error) {
      logger.error('Failed to create policy', {
        error: error instanceof Error ? error.message : 'Unknown error',
        requestId: context.invocationId
      })

      return {
        status: 500,
        body: JSON.stringify({
          success: false,
          error: 'CREATE_POLICY_FAILED',
          message: 'Failed to create policy'
        })
      }
    }
  }
})

// Export for testing
export { app }
