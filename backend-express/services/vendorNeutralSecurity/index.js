/**
 * Vendor-Neutral Financial Security Service
 * Platform-agnostic implementation — works with any infrastructure.
 *
 * Re-exports all classes and functions from sub-modules.
 */

const { VendorNeutralSecurityService } = require('./service');
const { NativeEncryptionProvider, HashicorpVaultProvider, HardwareHSMProvider } = require('./encryptionProviders');
const { FilesystemSecretManager, DatabaseSecretManager, KubernetesSecretManager, DockerSecretManager, EnvironmentSecretManager } = require('./secretManagers');
const { InMemorySessionManager, RedisSessionManager } = require('./sessionManagers');
const { ImmutableAuditLog } = require('./auditLog');
const { ZeroKnowledgeAuth } = require('./zeroKnowledgeAuth');
const { createSecurityMiddleware } = require('./middleware');

module.exports = {
    VendorNeutralSecurityService,
    NativeEncryptionProvider,
    HashicorpVaultProvider,
    HardwareHSMProvider,
    FilesystemSecretManager,
    DatabaseSecretManager,
    KubernetesSecretManager,
    DockerSecretManager,
    EnvironmentSecretManager,
    InMemorySessionManager,
    RedisSessionManager,
    ImmutableAuditLog,
    ZeroKnowledgeAuth,
    createSecurityMiddleware
};
