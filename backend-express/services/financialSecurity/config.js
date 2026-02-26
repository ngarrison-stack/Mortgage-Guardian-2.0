/**
 * Financial Security Service — Configuration & Initialization
 * AWS clients, Redis, Winston logger, and shared constants.
 */

const crypto = require('crypto');
const { promisify } = require('util');
const Redis = require('ioredis');
const winston = require('winston');

// Optional dependencies — these are for future AWS/enterprise deployment.
// The service degrades gracefully when they're not installed.
let AWS, RateLimiterRedis, ElasticsearchTransport;
try { AWS = require('aws-sdk'); } catch { AWS = null; }
try { ({ RateLimiterRedis } = require('rate-limiter-flexible')); } catch { RateLimiterRedis = null; }
try { ({ ElasticsearchTransport } = require('winston-elasticsearch')); } catch { ElasticsearchTransport = null; }

// Initialize AWS services (null when aws-sdk not installed)
const kms = AWS ? new AWS.KMS({ region: process.env.AWS_REGION || 'us-east-1' }) : null;
const secretsManager = AWS ? new AWS.SecretsManager({ region: process.env.AWS_REGION || 'us-east-1' }) : null;
const cloudHSM = AWS ? new AWS.CloudHSMV2({ region: process.env.AWS_REGION || 'us-east-1' }) : null;

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
        ...(ElasticsearchTransport ? [new ElasticsearchTransport({
            level: 'info',
            clientOpts: {
                node: process.env.ELASTICSEARCH_URL || 'https://localhost:9200',
                auth: {
                    username: process.env.ELASTICSEARCH_USER,
                    password: process.env.ELASTICSEARCH_PASSWORD
                }
            },
            index: 'security-audit'
        })] : [])
    ]
});

// Add console logging in development
if (process.env.NODE_ENV === 'development') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple()
    }));
}

module.exports = { kms, secretsManager, cloudHSM, redis, logger };
