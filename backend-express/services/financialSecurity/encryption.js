/**
 * Financial Security Service — Encryption Methods
 * HSM/KMS encrypt and decrypt operations.
 */

const { kms, logger } = require('./config');

module.exports = {
    /**
     * Encrypt with HSM or KMS
     */
    async encryptWithHSM(plaintext) {
        try {
            if (this.hsmClient) {
                return await this.encryptWithCloudHSM(plaintext);
            } else {
                return await this.encryptWithKMS(plaintext);
            }
        } catch (error) {
            logger.error('Encryption failed', error);
            throw new Error('Failed to encrypt data');
        }
    },

    /**
     * Encrypt with AWS KMS
     */
    async encryptWithKMS(plaintext) {
        const params = {
            KeyId: process.env.KMS_KEY_ID,
            Plaintext: plaintext,
            EncryptionContext: {
                service: 'mortgage-guardian',
                purpose: 'credential-encryption',
                timestamp: new Date().toISOString()
            }
        };

        const result = await kms.encrypt(params).promise();
        return result.CiphertextBlob.toString('base64');
    },

    /**
     * Decrypt with HSM or KMS
     */
    async decryptWithHSM(ciphertext) {
        try {
            if (this.hsmClient) {
                return await this.decryptWithCloudHSM(ciphertext);
            } else {
                return await this.decryptWithKMS(ciphertext);
            }
        } catch (error) {
            logger.error('Decryption failed', error);
            throw new Error('Failed to decrypt data');
        }
    },

    /**
     * Decrypt with AWS KMS
     */
    async decryptWithKMS(ciphertext) {
        const params = {
            CiphertextBlob: Buffer.from(ciphertext, 'base64'),
            EncryptionContext: {
                service: 'mortgage-guardian',
                purpose: 'credential-encryption'
            }
        };

        const result = await kms.decrypt(params).promise();
        return result.Plaintext.toString();
    }
};
