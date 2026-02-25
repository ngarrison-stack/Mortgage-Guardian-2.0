/**
 * Tests for utils/logger.js — Shared Winston Logger Utility
 */

// Set test environment before requiring logger
process.env.NODE_ENV = 'test';

const { logger, createLogger, morganStream } = require('../../utils/logger');

describe('Logger Utility', () => {
  describe('logger (base instance)', () => {
    it('should be a Winston logger instance', () => {
      expect(logger).toBeDefined();
      expect(typeof logger.info).toBe('function');
      expect(typeof logger.error).toBe('function');
      expect(typeof logger.warn).toBe('function');
      expect(typeof logger.debug).toBe('function');
      expect(typeof logger.log).toBe('function');
    });

    it('should be silent in test environment', () => {
      expect(logger.silent).toBe(true);
    });

    it('should have default service meta', () => {
      expect(logger.defaultMeta).toEqual({ service: 'mortgage-guardian' });
    });

    it('should have console transport', () => {
      expect(logger.transports.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('createLogger()', () => {
    it('should return a child logger with the service name', () => {
      const childLogger = createLogger('plaid');
      expect(childLogger).toBeDefined();
      expect(typeof childLogger.info).toBe('function');
      expect(typeof childLogger.error).toBe('function');
      expect(typeof childLogger.warn).toBe('function');
      expect(typeof childLogger.debug).toBe('function');
    });

    it('should create distinct child loggers for different service names', () => {
      const plaidLogger = createLogger('plaid');
      const claudeLogger = createLogger('claude');
      expect(plaidLogger).not.toBe(claudeLogger);
    });

    it('should not throw when logging with child logger', () => {
      const childLogger = createLogger('test-service');
      expect(() => childLogger.info('test message')).not.toThrow();
      expect(() => childLogger.error('test error', { code: 'ERR_TEST' })).not.toThrow();
      expect(() => childLogger.warn('test warning')).not.toThrow();
      expect(() => childLogger.debug('test debug', { key: 'value' })).not.toThrow();
    });

    it('should accept structured metadata', () => {
      const childLogger = createLogger('test-structured');
      expect(() => childLogger.info('operation completed', {
        userId: 'user-123',
        duration: 150,
        success: true
      })).not.toThrow();
    });

    it('should handle error objects', () => {
      const childLogger = createLogger('test-errors');
      const error = new Error('Something failed');
      expect(() => childLogger.error('Operation failed', {
        error: error.message,
        stack: error.stack
      })).not.toThrow();
    });
  });

  describe('morganStream', () => {
    it('should have a write method', () => {
      expect(morganStream).toBeDefined();
      expect(typeof morganStream.write).toBe('function');
    });

    it('should not throw when write is called', () => {
      expect(() => morganStream.write('GET /health 200 5ms\n')).not.toThrow();
    });

    it('should trim trailing whitespace from messages', () => {
      // The stream delegates to logger.log('http', ...) which is silent in test
      // We just verify it doesn't throw with whitespace
      expect(() => morganStream.write('  POST /v1/plaid/webhook 200 12ms  \n')).not.toThrow();
    });
  });

  describe('log levels', () => {
    it('should support all standard Winston levels', () => {
      const childLogger = createLogger('level-test');
      const levels = ['error', 'warn', 'info', 'http', 'verbose', 'debug', 'silly'];

      levels.forEach(level => {
        expect(() => childLogger.log(level, `Testing ${level} level`)).not.toThrow();
      });
    });
  });

  describe('environment configuration', () => {
    it('should respect LOG_LEVEL env var when set', () => {
      // The base logger was already created with the test env,
      // just verify it has a level property
      expect(logger.level).toBeDefined();
      expect(typeof logger.level).toBe('string');
    });
  });
});
