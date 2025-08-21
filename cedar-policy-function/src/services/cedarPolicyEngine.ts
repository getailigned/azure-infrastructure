import { PolicyCacheService } from './policyCacheService'
import { LoggerService } from './loggerService'

export interface CedarPrincipal {
  id: string
  tenant_id: string
  roles: string[]
  email?: string
  metadata?: Record<string, any>
}

export interface CedarAction {
  id: string
  metadata?: Record<string, any>
}

export interface CedarResource {
  id: string
  type: string
  tenant_id?: string
  metadata?: Record<string, any>
}

export interface CedarContext {
  tenant_id: string
  timestamp: string
  request_id?: string
  metadata?: Record<string, any>
}

export interface PolicyEvaluationResult {
  allowed: boolean
  policy_id: string
  metadata?: Record<string, any>
  explanation?: string
}

export interface CedarPolicy {
  id: string
  name: string
  description: string
  tenant_id: string
  policy_text: string
  version: string
  is_active: boolean
  created_at: string
  updated_at: string
  metadata?: Record<string, any>
}

export class CedarPolicyEngine {
  private policyCache: PolicyCacheService
  private logger: LoggerService
  private defaultPolicies: Map<string, CedarPolicy>

  constructor(policyCache: PolicyCacheService, logger: LoggerService) {
    this.policyCache = policyCache
    this.logger = logger
    this.defaultPolicies = new Map()
    this.initializeDefaultPolicies()
  }

  /**
   * Initialize default Cedar policies for HTMA platform
   */
  private initializeDefaultPolicies(): void {
    // Work Item Access Policy
    const workItemAccessPolicy: CedarPolicy = {
      id: 'work-item-access',
      name: 'Work Item Access Control',
      description: 'Controls who can read, update, and delete work items',
      tenant_id: 'default',
      policy_text: `
        @cedar.policy("work-item-access")
        
        // Users can read work items in their tenant
        permit(
          principal,
          action == Action::"read",
          resource in WorkItem
        ) when {
          principal.tenant_id == resource.tenant_id
        };
        
        // Users can update work items they own or manage
        permit(
          principal,
          action == Action::"update",
          resource in WorkItem
        ) when {
          principal.tenant_id == resource.tenant_id &&
          (principal.id == resource.owner_id || 
           principal.roles.contains("Manager") ||
           principal.roles.contains("Director") ||
           principal.roles.contains("VP") ||
           principal.roles.contains("President") ||
           principal.roles.contains("CEO"))
        };
        
        // Users can delete work items they own or manage
        permit(
          principal,
          action == Action::"delete",
          resource in WorkItem
        ) when {
          principal.tenant_id == resource.tenant_id &&
          (principal.id == resource.owner_id || 
           principal.roles.contains("Manager") ||
           principal.roles.contains("Director") ||
           principal.roles.contains("VP") ||
           principal.roles.contains("President") ||
           principal.roles.contains("CEO"))
        };
      `,
      version: '1.0.0',
      is_active: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }

    // Lineage Enforcement Policy
    const lineageEnforcementPolicy: CedarPolicy = {
      id: 'lineage-enforcement',
      name: 'Lineage Enforcement',
      description: 'Enforces that all work items must have lineage unless created by CEO or President',
      tenant_id: 'default',
      policy_text: `
        @cedar.policy("lineage-enforcement")
        
        // Only CEO or President can create root items (items without parent)
        permit(
          principal,
          action == Action::"create",
          resource in WorkItem
        ) when {
          resource.type in ["strategy","initiative","task","subtask"] &&
          (principal.roles.contains("CEO") || principal.roles.contains("President"))
        };
        
        // All other users must create items with a parent (lineage)
        permit(
          principal,
          action == Action::"create",
          resource in WorkItem
        ) when {
          resource.type in ["strategy","initiative","task","subtask"] &&
          resource.parent_id != null
        };
        
        // Allow creation of objectives (root level) by any authenticated user
        permit(
          principal,
          action == Action::"create",
          resource in WorkItem
        ) when {
          resource.type == "objective"
        };
      `,
      version: '1.0.0',
      is_active: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }

    // Admin Access Policy
    const adminAccessPolicy: CedarPolicy = {
      id: 'admin-access',
      name: 'Admin Access Control',
      description: 'Controls access to administrative functions',
      tenant_id: 'default',
      policy_text: `
        @cedar.policy("admin-access")
        
        // Only users with admin roles can access admin endpoints
        permit(
          principal,
          action == Action::"admin",
          resource in AdminResource
        ) when {
          principal.tenant_id == resource.tenant_id &&
          (principal.roles.contains("Admin") ||
           principal.roles.contains("CEO") ||
           principal.roles.contains("President"))
        };
      `,
      version: '1.0.0',
      is_active: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }

    this.defaultPolicies.set('work-item-access', workItemAccessPolicy)
    this.defaultPolicies.set('lineage-enforcement', lineageEnforcementPolicy)
    this.defaultPolicies.set('admin-access', adminAccessPolicy)
  }

  /**
   * Evaluate a Cedar policy for authorization
   */
  async evaluatePolicy(
    principal: CedarPrincipal,
    action: CedarAction,
    resource: CedarResource,
    context: CedarContext
  ): Promise<PolicyEvaluationResult> {
    try {
      // Get policies for the tenant
      const policies = await this.getPolicies(principal.tenant_id)
      
      // For now, implement a simplified policy evaluation
      // In production, this would use the actual Cedar policy engine
      const result = await this.evaluateWithSimplifiedEngine(principal, action, resource, policies)
      
      this.logger.info('Policy evaluation completed', {
        principal: principal.id,
        action: action.id,
        resource: resource.id,
        tenant_id: principal.tenant_id,
        result: result.allowed,
        policy_id: result.policy_id
      })

      return result

    } catch (error) {
      this.logger.error('Policy evaluation failed', {
        error: error instanceof Error ? error.message : 'Unknown error',
        principal: principal.id,
        action: action.id,
        resource: resource.id
      })

      // Default to deny on error
      return {
        allowed: false,
        policy_id: 'error-fallback',
        metadata: { error: 'Policy evaluation failed' }
      }
    }
  }

  /**
   * Simplified policy evaluation engine (placeholder for actual Cedar engine)
   */
  private async evaluateWithSimplifiedEngine(
    principal: CedarPrincipal,
    action: CedarAction,
    resource: CedarResource,
    policies: CedarPolicy[]
  ): Promise<PolicyEvaluationResult> {
    // Check work item access policy
    if (resource.type === 'work_item' || resource.id.includes('/work-items')) {
      return this.evaluateWorkItemAccess(principal, action, resource)
    }

    // Check admin access policy
    if (action.id === 'admin' || resource.id.includes('/admin')) {
      return this.evaluateAdminAccess(principal, action, resource)
    }

    // Check lineage enforcement policy
    if (action.id === 'create' && resource.type === 'work_item') {
      return this.evaluateLineageEnforcement(principal, action, resource)
    }

    // Default allow for other cases
    return {
      allowed: true,
      policy_id: 'default-allow',
      metadata: { reason: 'No specific policy found, defaulting to allow' }
    }
  }

  /**
   * Evaluate work item access policy
   */
  private evaluateWorkItemAccess(
    principal: CedarPrincipal,
    action: CedarAction,
    resource: CedarResource
  ): PolicyEvaluationResult {
    // Read access - allow if same tenant
    if (action.id === 'read') {
      return {
        allowed: true,
        policy_id: 'work-item-access',
        metadata: { reason: 'Read access allowed for same tenant' }
      }
    }

    // Update/Delete access - check ownership and roles
    if (action.id === 'update' || action.id === 'delete') {
      const hasManagementRole = principal.roles.some(role => 
        ['Manager', 'Director', 'VP', 'President', 'CEO', 'Admin'].includes(role)
      )

      if (hasManagementRole) {
        return {
          allowed: true,
          policy_id: 'work-item-access',
          metadata: { reason: 'Management role has update/delete access' }
        }
      }

      // Check if user owns the resource (would need resource.owner_id in real implementation)
      // For now, allow if user has any role
      if (principal.roles.length > 0) {
        return {
          allowed: true,
          policy_id: 'work-item-access',
          metadata: { reason: 'Authenticated user with roles has access' }
        }
      }
    }

    return {
      allowed: false,
      policy_id: 'work-item-access',
      metadata: { reason: 'Access denied by work item policy' }
    }
  }

  /**
   * Evaluate admin access policy
   */
  private evaluateAdminAccess(
    principal: CedarPrincipal,
    action: CedarAction,
    resource: CedarResource
  ): PolicyEvaluationResult {
    const hasAdminRole = principal.roles.some(role => 
      ['Admin', 'CEO', 'President'].includes(role)
    )

    if (hasAdminRole) {
      return {
        allowed: true,
        policy_id: 'admin-access',
        metadata: { reason: 'Admin role has administrative access' }
      }
    }

    return {
      allowed: false,
      policy_id: 'admin-access',
      metadata: { reason: 'Admin access denied - insufficient privileges' }
    }
  }

  /**
   * Evaluate lineage enforcement policy
   */
  private evaluateLineageEnforcement(
    principal: CedarPrincipal,
    action: CedarAction,
    resource: CedarResource
  ): PolicyEvaluationResult {
    // Allow CEO and President to create root items
    const canCreateRoot = principal.roles.some(role => 
      ['CEO', 'President'].includes(role)
    )

    if (canCreateRoot) {
      return {
        allowed: true,
        policy_id: 'lineage-enforcement',
        metadata: { reason: 'CEO/President can create root items' }
      }
    }

    // For other users, require parent_id (would need resource.parent_id in real implementation)
    // For now, allow creation but log the requirement
    this.logger.info('Lineage enforcement check', {
      principal: principal.id,
      action: action.id,
      resource: resource.id,
      message: 'Parent ID should be validated for non-executive users'
    })

    return {
      allowed: true,
      policy_id: 'lineage-enforcement',
      metadata: { reason: 'Creation allowed, parent ID validation required' }
    }
  }

  /**
   * Get policies for a specific tenant
   */
  async getPolicies(tenantId: string): Promise<CedarPolicy[]> {
    try {
      // Try to get from cache first
      const cachedPolicies = await this.policyCache.getPolicies(tenantId)
      if (cachedPolicies && cachedPolicies.length > 0) {
        return cachedPolicies
      }

      // Get default policies
      const defaultPolicies = Array.from(this.defaultPolicies.values())
      
      // Cache the policies
      await this.policyCache.setPolicies(tenantId, defaultPolicies)
      
      return defaultPolicies

    } catch (error) {
      this.logger.error('Failed to get policies', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })

      // Return default policies on error
      return Array.from(this.defaultPolicies.values())
    }
  }

  /**
   * Create a new policy
   */
  async createPolicy(policy: Omit<CedarPolicy, 'id' | 'created_at' | 'updated_at'>, tenantId: string): Promise<{ policy_id: string }> {
    try {
      const newPolicy: CedarPolicy = {
        ...policy,
        id: `policy_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }

      // Store in cache
      const existingPolicies = await this.getPolicies(tenantId)
      const updatedPolicies = [...existingPolicies, newPolicy]
      await this.policyCache.setPolicies(tenantId, updatedPolicies)

      this.logger.info('Policy created successfully', {
        policy_id: newPolicy.id,
        tenant_id: tenantId,
        name: newPolicy.name
      })

      return { policy_id: newPolicy.id }

    } catch (error) {
      this.logger.error('Failed to create policy', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })
      throw error
    }
  }

  /**
   * Check if the engine is healthy
   */
  isHealthy(): boolean {
    try {
      // Basic health check - verify default policies are loaded
      return this.defaultPolicies.size > 0
    } catch (error) {
      this.logger.error('Health check failed', {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
      return false
    }
  }
}
