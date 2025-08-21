import winston from 'winston'

export class LoggerService {
  private logger: winston.Logger

  constructor() {
    const logLevel = process.env.LOG_LEVEL || 'info'
    
    this.logger = winston.createLogger({
      level: logLevel,
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: {
        service: 'cedar-policy-function',
        environment: process.env.NODE_ENV || 'development'
      },
      transports: [
        // Console transport for development
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        }),
        // File transport for production logs
        new winston.transports.File({
          filename: 'logs/cedar-policy-error.log',
          level: 'error',
          maxsize: 5242880, // 5MB
          maxFiles: 5
        }),
        new winston.transports.File({
          filename: 'logs/cedar-policy-combined.log',
          maxsize: 5242880, // 5MB
          maxFiles: 5
        })
      ]
    })

    // Handle uncaught exceptions
    this.logger.exceptions.handle(
      new winston.transports.File({ filename: 'logs/cedar-policy-exceptions.log' })
    )

    // Handle unhandled promise rejections
    this.logger.rejections.handle(
      new winston.transports.File({ filename: 'logs/cedar-policy-rejections.log' })
    )
  }

  /**
   * Log an info message
   */
  info(message: string, meta?: Record<string, any>): void {
    this.logger.info(message, meta)
  }

  /**
   * Log a warning message
   */
  warn(message: string, meta?: Record<string, any>): void {
    this.logger.warn(message, meta)
  }

  /**
   * Log an error message
   */
  error(message: string, meta?: Record<string, any>): void {
    this.logger.error(message, meta)
  }

  /**
   * Log a debug message
   */
  debug(message: string, meta?: Record<string, any>): void {
    this.logger.debug(message, meta)
  }

  /**
   * Log a verbose message
   */
  verbose(message: string, meta?: Record<string, any>): void {
    this.logger.verbose(message, meta)
  }

  /**
   * Log a silly message (lowest level)
   */
  silly(message: string, meta?: Record<string, any>): void {
    this.logger.silly(message, meta)
  }

  /**
   * Create a child logger with additional metadata
   */
  child(meta: Record<string, any>): LoggerService {
    const childLogger = new LoggerService()
    childLogger.logger = this.logger.child(meta)
    return childLogger
  }

  /**
   * Get the underlying winston logger
   */
  getWinstonLogger(): winston.Logger {
    return this.logger
  }

  /**
   * Set the log level dynamically
   */
  setLevel(level: string): void {
    this.logger.level = level
  }

  /**
   * Get current log level
   */
  getLevel(): string {
    return this.logger.level
  }

  /**
   * Check if a log level is enabled
   */
  isLevelEnabled(level: string): boolean {
    return this.logger.isLevelEnabled(level)
  }

  /**
   * Log performance metrics
   */
  logPerformance(operation: string, duration: number, meta?: Record<string, any>): void {
    this.info(`Performance: ${operation} completed in ${duration}ms`, {
      operation,
      duration,
      ...meta
    })
  }

  /**
   * Log security events
   */
  logSecurityEvent(event: string, meta?: Record<string, any>): void {
    this.warn(`Security Event: ${event}`, {
      event_type: 'security',
      ...meta
    })
  }

  /**
   * Log policy evaluation events
   */
  logPolicyEvaluation(
    principal: string,
    action: string,
    resource: string,
    result: boolean,
    meta?: Record<string, any>
  ): void {
    this.info('Policy evaluation', {
      event_type: 'policy_evaluation',
      principal,
      action,
      resource,
      result,
      ...meta
    })
  }

  /**
   * Log cache operations
   */
  logCacheOperation(operation: string, key: string, success: boolean, meta?: Record<string, any>): void {
    this.debug(`Cache ${operation}`, {
      event_type: 'cache_operation',
      operation,
      key,
      success,
      ...meta
    })
  }

  /**
   * Log API requests
   */
  logApiRequest(
    method: string,
    path: string,
    statusCode: number,
    duration: number,
    meta?: Record<string, any>
  ): void {
    this.info('API Request', {
      event_type: 'api_request',
      method,
      path,
      status_code: statusCode,
      duration,
      ...meta
    })
  }

  /**
   * Log errors with context
   */
  logErrorWithContext(
    error: Error,
    context: string,
    meta?: Record<string, any>
  ): void {
    this.error(`Error in ${context}: ${error.message}`, {
      event_type: 'error',
      context,
      error_message: error.message,
      error_stack: error.stack,
      error_name: error.name,
      ...meta
    })
  }

  /**
   * Log startup information
   */
  logStartup(): void {
    this.info('Cedar Policy Function starting up', {
      event_type: 'startup',
      version: process.env.npm_package_version || 'unknown',
      node_version: process.version,
      environment: process.env.NODE_ENV || 'development',
      log_level: this.getLevel()
    })
  }

  /**
   * Log shutdown information
   */
  logShutdown(signal: string): void {
    this.info('Cedar Policy Function shutting down', {
      event_type: 'shutdown',
      signal,
      timestamp: new Date().toISOString()
    })
  }
}
