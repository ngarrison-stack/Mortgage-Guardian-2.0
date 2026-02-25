/**
 * Financial Security Service — Configuration & Initialization
 * AWS clients, Redis, Winston logger, and shared constants.
 */

const crypto = require('crypto');
const AWS = require('aws-sdk');
const { promisify } = require('util');
const { RateLimiterRedis } = require('rate-limiter-flexible');
const Redis = require('ioredis');
const winston = require('winston');
const { ElasticsearchTransport } = require('winston-elasticsearch');

// Initialize AWS services
const kms = new AWS.KMS({ region: process.env.AWS_REGION || 'us-east-1' });
const secretsManager = new AWS.SecretsManager({ region: process.env.AWS_REGION || 'us-east-1' });
const cloudHSM = new AWS.CloudHSMV2({ region: process.env.AWS_REGION || 'us-east-1' });

// Initialize Redis for session management and rate limiting
const redis = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
    enableTLSForSentinelMode: true,
    tls: {
        rejectUnauthorized: true
    },
    retryStrategy: (times) => Math.min(times * 50, 2000)
});

// Configure secure logging with audit trail
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'financial-security' },
    transports: [
        new winston.transports.File({
            filename: '/var/log/mortgage-guardian/security-error.log',
            level: 'error',
            maxsize: 5242880,
            maxFiles: 5
        }),
        new winston.transports.File({
            filename: '/var/log/mortgage-guardian/security-audit.log',
            level: 'info',
            maxsize: 5242880,
            maxFiles: 30
        }),
        new ElasticsearchTransport({
            level: 'info',
            clientOpts: {
                node: process.env.ELASTICSEARCH_URL || 'https://localhost:9200',
                auth: {
                    username: process.env.ELASTICSEARCH_USER,
                    password: process.env.ELASTICSEARCH_PASSWORD
                }
            },
            index: 'security-audit'
        })
    ]
});

// Add console logging in development
if (process.env.NODE_ENV === 'development') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

module.exports = { kms, secretsManager, cloudHSM, redis, logger };
