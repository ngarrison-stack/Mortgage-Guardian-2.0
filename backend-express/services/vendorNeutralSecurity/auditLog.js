/**
 * Vendor-Neutral Security — Immutable Audit Log
 * Blockchain-style hash chain with log integrity verification.
 */

const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');

class ImmutableAuditLog {
    constructor(logPath = './audit') {
        this.logPath = logPath;
        this.currentLogFile = null;
        this.previousHash = null;
        this.initializeLog();
    }

    async initializeLog() {
        await fs.mkdir(this.logPath, { recursive: true, mode: 0o700 });

        const date = new Date().toISOString().split('T')[0];
        this.currentLogFile = path.join(this.logPath, `audit-${date}.log`);

        this.previousHash = await this.getLastHash();
    }

    async logEntry(event, metadata = {}) {
        const entry = {
            id: crypto.randomUUID(),
            timestamp: new Date().toISOString(),
            event,
            metadata,
            previousHash: this.previousHash
        };

        entry.hash = this.calculateHash(entry);

        entry.signature = this.signEntry(entry);

        await fs.appendFile(
            this.currentLogFile,
            JSON.stringify(entry) + '\n',
            { mode: 0o600 }
        );

        this.previousHash = entry.hash;

        return entry;
    }

    calculateHash(entry) {
        const content = JSON.stringify({
            id: entry.id,
            timestamp: entry.timestamp,
            event: entry.event,
            metadata: entry.metadata,
            previousHash: entry.previousHash
        });

        return crypto.createHash('sha512').update(content).digest('hex');
    }

    signEntry(entry) {
        const sign = crypto.createSign('SHA512');
        sign.update(entry.hash);
        return sign.sign('private_key', 'hex');
    }

    async getLastHash() {
        try {
            const content = await fs.readFile(this.currentLogFile, 'utf8');
            const lines = content.trim().split('\n');
            if (lines.length > 0) {
                const lastEntry = JSON.parse(lines[lines.length - 1]);
                return lastEntry.hash;
            }
        } catch {
            // File doesn't exist or is empty
        }
        return null;
    }

    async verifyLog() {
        const content = await fs.readFile(this.currentLogFile, 'utf8');
        const lines = content.trim().split('\n');

        let previousHash = null;

        for (const line of lines) {
            const entry = JSON.parse(line);

            if (entry.previousHash !== previousHash) {
                return false;
            }

            const calculatedHash = this.calculateHash(entry);
            if (calculatedHash !== entry.hash) {
                return false;
            }

            previousHash = entry.hash;
        }

        return true;
    }
}

module.exports = { ImmutableAuditLog };
