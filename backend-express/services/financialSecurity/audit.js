/**
 * Financial Security Service — Audit Logging
 * Immutable audit log with hash chain and KMS signing.
 */

const crypto = require('crypto');
const { kms, logger } = require('./config');

module.exports = {
    /**
     * Create immutable audit log entry
     */
    async auditLog(eventType, data) {
        const entry = {
            id: crypto.randomUUID(),
            timestamp: new Date().toISOString(),
            eventType,
            data,
            hash: null,
            previousHash: null
        };

        const previousEntry = await this.getLastAuditEntry();
        if (previousEntry) {
            entry.previousHash = previousEntry.hash;
        }

        entry.hash = this.calculateHash(entry);

        entry.signature = await this.signAuditEntry(entry);

        await Promise.all([
            this.storeAuditInDatabase(entry),
            this.storeAuditInS3(entry),
            this.sendToSIEM(entry)
        ]);

        logger.info('Audit log entry created', { eventType, id: entry.id });

        return entry;
    },

    calculateHash(entry) {
        const content = JSON.stringify({
            id: entry.id,
            timestamp: entry.timestamp,
            eventType: entry.eventType,
            data: entry.data,
            previousHash: entry.previousHash
        });

        return crypto
            .createHash('sha512')
            .update(content)
            .digest('hex');
    },

    async signAuditEntry(entry) {
        const params = {
            KeyId: process.env.KMS_SIGNING_KEY_ID,
            Message: Buffer.from(entry.hash),
            MessageType: 'DIGEST',
            SigningAlgorithm: 'ECDSA_SHA_512'
        };

        const result = await kms.sign(params).promise();
        return result.Signature.toString('base64');
    }
};
