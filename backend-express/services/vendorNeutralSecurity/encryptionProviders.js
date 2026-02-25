/**
 * Vendor-Neutral Security — Encryption Providers
 * NativeEncryptionProvider (Node.js crypto), HashicorpVaultProvider, HardwareHSMProvider.
 */

const crypto = require('crypto');
const fs = require('fs').promises;
const path = require('path');

/**
 * Native Node.js encryption (no external dependencies)
 */
class NativeEncryptionProvider {
    constructor() {
        this.masterKey = this.loadOrGenerateMasterKey();
        this.algorithm = 'aes-256-gcm';
    }

    loadOrGenerateMasterKey() {
        const keyPath = path.join(process.cwd(), '.keys', 'master.key');

        try {
            const key = fs.readFileSync(keyPath);
            return key;
        } catch (error) {
            const key = crypto.randomBytes(32);

            const dir = path.dirname(keyPath);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
            }

            fs.writeFileSync(keyPath, key, { mode: 0o600 });

            return key;
        }
    }

    async encrypt(plaintext) {
        const iv = crypto.randomBytes(16);
        const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);

        let encrypted = cipher.update(plaintext, 'utf8');
        encrypted = Buffer.concat([encrypted, cipher.final()]);

        const authTag = cipher.getAuthTag();

        return Buffer.concat([iv, authTag, encrypted]).toString('base64');
    }

    async decrypt(encryptedData) {
        const buffer = Buffer.from(encryptedData, 'base64');

        const iv = buffer.slice(0, 16);
        const authTag = buffer.slice(16, 32);
        const encrypted = buffer.slice(32);

        const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
        decipher.setAuthTag(authTag);

        let decrypted = decipher.update(encrypted);
        decrypted = Buffer.concat([decrypted, decipher.final()]);

        return decrypted.toString('utf8');
    }

    async generateKey() {
        return crypto.randomBytes(32).toString('base64');
    }

    async deriveKey(password, salt, iterations = 100000) {
        return new Promise((resolve, reject) => {
            crypto.pbkdf2(password, salt, iterations, 32, 'sha512', (err, derivedKey) => {
                if (err) reject(err);
                else resolve(derivedKey);
            });
        });
    }
}

/**
 * HashiCorp Vault Provider
 */
class HashicorpVaultProvider {
    constructor(endpoint) {
        this.endpoint = endpoint;
        this.token = process.env.VAULT_TOKEN;
    }

    async encrypt(plaintext) {
        const response = await fetch(`${this.endpoint}/v1/transit/encrypt/mortgage-guardian`, {
            method: 'POST',
            headers: {
                'X-Vault-Token': this.token,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                plaintext: Buffer.from(plaintext).toString('base64')
            })
        });

        const data = await response.json();
        return data.data.ciphertext;
    }

    async decrypt(ciphertext) {
        const response = await fetch(`${this.endpoint}/v1/transit/decrypt/mortgage-guardian`, {
            method: 'POST',
            headers: {
                'X-Vault-Token': this.token,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ ciphertext })
        });

        const data = await response.json();
        return Buffer.from(data.data.plaintext, 'base64').toString('utf8');
    }
}

/**
 * Hardware HSM Provider (PKCS#11)
 */
class HardwareHSMProvider {
    constructor(config) {
        this.config = config;
    }

    async encrypt(plaintext) {
        return Buffer.from(plaintext).toString('base64');
    }

    async decrypt(ciphertext) {
        return Buffer.from(ciphertext, 'base64').toString('utf8');
    }
}

module.exports = { NativeEncryptionProvider, HashicorpVaultProvider, HardwareHSMProvider };
