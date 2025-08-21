import { createClient, RedisClientType } from 'redis'
import { CedarPolicy } from './cedarPolicyEngine'
import { LoggerService } from './loggerService'

export class PolicyCacheService {
  private client: RedisClientType
  private logger: LoggerService
  private readonly cacheTTL: number
  private readonly cachePrefix: string

  constructor() {
    const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379'
    this.client = createClient({ url: redisUrl })
    this.logger = new LoggerService()
    this.cacheTTL = parseInt(process.env.CEDAR_POLICY_CACHE_TTL || '300') // 5 minutes default
    this.cachePrefix = 'cedar_policy'

    this.setupErrorHandling()
  }

  /**
   * Setup Redis error handling
   */
  private setupErrorHandling(): void {
    this.client.on('error', (error) => {
      this.logger.error('Redis connection error', { error: error.message })
    })

    this.client.on('connect', () => {
      this.logger.info('Redis connected')
    })

    this.client.on('disconnect', () => {
      this.logger.warn('Redis disconnected')
    })
  }

  /**
   * Connect to Redis
   */
  async connect(): Promise<void> {
    try {
      await this.client.connect()
      this.logger.info('Policy cache service connected to Redis')
    } catch (error) {
      this.logger.error('Failed to connect to Redis', {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
      throw error
    }
  }

  /**
   * Disconnect from Redis
   */
  async disconnect(): Promise<void> {
    try {
      await this.client.disconnect()
      this.logger.info('Policy cache service disconnected from Redis')
    } catch (error) {
      this.logger.error('Failed to disconnect from Redis', {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
    }
  }

  /**
   * Get policies for a specific tenant
   */
  async getPolicies(tenantId: string): Promise<CedarPolicy[]> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policies`
      const cachedData = await this.client.get(key)
      
      if (cachedData) {
        const policies = JSON.parse(cachedData) as CedarPolicy[]
        this.logger.debug('Policies retrieved from cache', {
          tenant_id: tenantId,
          count: policies.length
        })
        return policies
      }

      this.logger.debug('No cached policies found', { tenant_id: tenantId })
      return []

    } catch (error) {
      this.logger.error('Failed to get policies from cache', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })
      return []
    }
  }

  /**
   * Set policies for a specific tenant
   */
  async setPolicies(tenantId: string, policies: CedarPolicy[]): Promise<void> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policies`
      const data = JSON.stringify(policies)
      
      await this.client.setEx(key, this.cacheTTL, data)
      
      this.logger.debug('Policies cached successfully', {
        tenant_id: tenantId,
        count: policies.length,
        ttl: this.cacheTTL
      })

    } catch (error) {
      this.logger.error('Failed to cache policies', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })
    }
  }

  /**
   * Get a specific policy by ID
   */
  async getPolicy(tenantId: string, policyId: string): Promise<CedarPolicy | null> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policy:${policyId}`
      const cachedData = await this.client.get(key)
      
      if (cachedData) {
        const policy = JSON.parse(cachedData) as CedarPolicy
        this.logger.debug('Policy retrieved from cache', {
          tenant_id: tenantId,
          policy_id: policyId
        })
        return policy
      }

      this.logger.debug('Policy not found in cache', {
        tenant_id: tenantId,
        policy_id: policyId
      })
      return null

    } catch (error) {
      this.logger.error('Failed to get policy from cache', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId,
        policy_id: policyId
      })
      return null
    }
  }

  /**
   * Set a specific policy
   */
  async setPolicy(tenantId: string, policy: CedarPolicy): Promise<void> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policy:${policy.id}`
      const data = JSON.stringify(policy)
      
      await this.client.setEx(key, this.cacheTTL, data)
      
      this.logger.debug('Policy cached successfully', {
        tenant_id: tenantId,
        policy_id: policy.id,
        ttl: this.cacheTTL
      })

    } catch (error) {
      this.logger.error('Failed to cache policy', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId,
        policy_id: policy.id
      })
    }
  }

  /**
   * Delete a specific policy
   */
  async deletePolicy(tenantId: string, policyId: string): Promise<void> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policy:${policyId}`
      await this.client.del(key)
      
      this.logger.debug('Policy deleted from cache', {
        tenant_id: tenantId,
        policy_id: policyId
      })

    } catch (error) {
      this.logger.error('Failed to delete policy from cache', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId,
        policy_id: policyId
      })
    }
  }

  /**
   * Clear all policies for a tenant
   */
  async clearPolicies(tenantId: string): Promise<void> {
    try {
      const pattern = `${this.cachePrefix}:${tenantId}:*`
      const keys = await this.client.keys(pattern)
      
      if (keys.length > 0) {
        await this.client.del(keys)
        this.logger.debug('All policies cleared for tenant', {
          tenant_id: tenantId,
          keys_cleared: keys.length
        })
      }

    } catch (error) {
      this.logger.error('Failed to clear policies for tenant', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })
    }
  }

  /**
   * Get cache statistics
   */
  async getCacheStats(): Promise<{
    totalKeys: number
    memoryUsage: string
    hitRate: number
    tenantCount: number
  }> {
    try {
      const info = await this.client.info('memory')
      const keys = await this.client.keys(`${this.cachePrefix}:*`)
      
      // Extract memory usage from info
      const memoryMatch = info.match(/used_memory_human:(\S+)/)
      const memoryUsage = memoryMatch ? memoryMatch[1] : 'unknown'
      
      // Count unique tenants
      const tenantIds = new Set<string>()
      keys.forEach(key => {
        const parts = key.split(':')
        if (parts.length >= 2) {
          tenantIds.add(parts[1])
        }
      })

      return {
        totalKeys: keys.length,
        memoryUsage,
        hitRate: 0, // Would need to implement hit tracking
        tenantCount: tenantIds.size
      }

    } catch (error) {
      this.logger.error('Failed to get cache statistics', {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
      
      return {
        totalKeys: 0,
        memoryUsage: 'unknown',
        hitRate: 0,
        tenantCount: 0
      }
    }
  }

  /**
   * Check if the cache service is healthy
   */
  async isHealthy(): Promise<boolean> {
    try {
      // Try to ping Redis
      await this.client.ping()
      return true
    } catch (error) {
      this.logger.error('Cache health check failed', {
        error: error instanceof Error ? error.message : 'Unknown error'
      })
      return false
    }
  }

  /**
   * Refresh cache TTL for a tenant's policies
   */
  async refreshCacheTTL(tenantId: string): Promise<void> {
    try {
      const key = `${this.cachePrefix}:${tenantId}:policies`
      const exists = await this.client.exists(key)
      
      if (exists) {
        await this.client.expire(key, this.cacheTTL)
        this.logger.debug('Cache TTL refreshed', {
          tenant_id: tenantId,
          ttl: this.cacheTTL
        })
      }

    } catch (error) {
      this.logger.error('Failed to refresh cache TTL', {
        error: error instanceof Error ? error.message : 'Unknown error',
        tenant_id: tenantId
      })
    }
  }
}
