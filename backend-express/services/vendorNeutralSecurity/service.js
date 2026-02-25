/**
 * Vendor-Neutral Security — Main Service Class
 * Orchestrator that creates appropriate providers based on configuration.
 */

const winston = require('winston');
const Redis = require('ioredis');
const { RateLimiterMemory, RateLimiterRedis } = require('rate-limiter-flexible');
const path = require('path');
const { NativeEncryptionProvider, HashicorpVaultProvider, HardwareHSMProvider } = require('./encryptionProviders');
const { FilesystemSecretManager, DatabaseSecretManager, KubernetesSecretManager, DockerSecretManager, EnvironmentSecretManager } = require('./secretManagers');
const { InMemorySessionManager, RedisSessionManager } = require('./sessionManagers');

class VendorNeutralSecurityService {
    constructor(config = {}) {
        this.config = {
            secretStorage: config.secretStorage || 'filesystem',
            encryptionProvider: config.encryptionProvider || 'native',
            auditBackend: config.auditBackend || 'local',
            hsmProvider: config.hsmProvider || null,
            ...config
        };

        this.initializeComponents();
    }

    async initializeComponents() {
        this.encryptionProvider = this.createEncryptionProvider();
        this.secretManager = this.createSecretManager();
        this.auditLogger = this.createAuditLogger();
        this.rateLimiter = this.createRateLimiter();
        this.sessionManager = this.createSessionManager();
    }

    createEncryptionProvider() {
        switch (this.config.encryptionProvider) {
            case 'native':
                return new NativeEncryptionProvider();
            case 'hashicorp-vault':
                return new HashicorpVaultProvider(this.config.vaultEndpoint);
            case 'azure-keyvault':
                return new AzureKeyVaultProvider(this.config.azureConfig);
            case 'gcp-kms':
                return new GCPKeyManagementProvider(this.config.gcpConfig);
            case 'hardware-hsm':
                return new HardwareHSMProvider(this.config.hsmConfig);
            default:
                return new NativeEncryptionProvider();
        }
    }

    createSecretManager() {
        switch (this.config.secretStorage) {
            case 'filesystem':
                return new FilesystemSecretManager(this.config.secretsPath);
            case 'database':
                return new DatabaseSecretManager(this.config.dbConnection);
            case 'hashicorp-vault':
                return new HashicorpVaultSecretManager(this.config.vaultEndpoint);
            case 'kubernetes':
                return new KubernetesSecretManager(this.config.k8sNamespace);
            case 'docker-secrets':
                return new DockerSecretManager();
            case 'env':
                return new EnvironmentSecretManager();
            default:
                return new FilesystemSecretManager('./secrets');
        }
    }

    createAuditLogger() {
        const transports = [];

        transports.push(
            new winston.transports.File({
                filename: path.join(this.config.logPath || './logs', 'audit.log'),
                level: 'info',
                format: winston.format.json(),
                maxsize: 5242880,
                maxFiles: 30
            })
        );

        if (this.config.syslogHost) {
            const Syslog = require('winston-syslog').Syslog;
            transports.push(new Syslog({
                host: this.config.syslogHost,
                port: this.config.syslogPort || 514,
                protocol: 'tls4',
                facility: 'auth',
                app_name: 'mortgage-guardian'
            }));
        }

        if (this.config.elasticEndpoint) {
            const { ElasticsearchTransport } = require('winston-elasticsearch');
            transports.push(new ElasticsearchTransport({
                level: 'info',
                clientOpts: {
                    node: this.config.elasticEndpoint,
                    auth: this.config.elasticAuth
                },
                index: 'security-audit'
            }));
        }

        return winston.createLogger({
            level: 'info',
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.json()
            ),
            transports
        });
    }

    createRateLimiter() {
        if (this.config.redisHost) {
            const redis = new Redis({
                host: this.config.redisHost,
                port: this.config.redisPort || 6379,
                password: this.config.redisPassword,
                tls: this.config.redisTLS ? {} : undefined
            });

            return {
                api: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:api',
                    points: 100,
                    duration: 60
                }),
                auth: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:auth',
                    points: 5,
                    duration: 900
                }),
                transaction: new RateLimiterRedis({
                    storeClient: redis,
                    keyPrefix: 'rl:transaction',
                    points: 10,
                    duration: 60
                })
            };
        } else {
            return {
                api: new RateLimiterMemory({
                    points: 100,
                    duration: 60
                }),
                auth: new RateLimiterMemory({
                    points: 5,
                    duration: 900
                }),
                transaction: new RateLimiterMemory({
                    points: 10,
                    duration: 60
                })
            };
        }
    }

    createSessionManager() {
        if (this.config.redisHost) {
            return new RedisSessionManager(this.config);
        } else {
            return new InMemorySessionManager();
        }
    }
}

module.exports = { VendorNeutralSecurityService };
