/**
 * Document Encryption Service
 *
 * Per-user document encryption using AES-256-GCM with HKDF key derivation.
 * Each user gets a unique encryption key derived from a master key + userId,
 * providing cryptographic tenant isolation for document storage.
 *
 * Pack format: iv(12) + authTag(16) + ciphertext(N) in a single Buffer.
 *
 * Dependencies: Node.js crypto module only (zero external dependencies).
 */

const crypto = require('crypto');
const { createLogger } = require('../utils/logger');

const logger = createLogger('encryption');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const AUTH_TAG_LENGTH = 16;
const KEY_LENGTH = 32;
const HKDF_INFO = 'mortgage-guardian-doc-v1';

class DocumentEncryptionService {
  constructor() {
    const hexKey = process.env.DOCUMENT_ENCRYPTION_KEY;
    if (!hexKey) {
      throw new Error(
        'DOCUMENT_ENCRYPTION_KEY environment variable is required. ' +
        'Set it to a 64-character hex string (32 bytes).'
      );
    }
    this.masterKey = Buffer.from(hexKey, 'hex');
    if (this.masterKey.length !== KEY_LENGTH) {
      throw new Error(
        `DOCUMENT_ENCRYPTION_KEY must be exactly 32 bytes (64 hex chars), got ${this.masterKey.length} bytes.`
      );
    }
    logger.debug('Encryption service initialized');
  }

  /**
   * Derive a per-user encryption key from the master key using HKDF-SHA256.
   *
   * @param {string} userId - The user ID used as salt for key derivation
   * @returns {Buffer} 32-byte derived key
   */
  deriveKey(userId) {
    const derived = crypto.hkdfSync(
      'sha256',
      this.masterKey,
      userId,
      HKDF_INFO,
      KEY_LENGTH
    );
    return Buffer.from(derived);
  }

  /**
   * Encrypt a plaintext buffer for a specific user.
   *
   * @param {string} userId - The user ID for key derivation
   * @param {Buffer} plaintextBuffer - The data to encrypt
   * @returns {Buffer} Packed buffer: iv(12) + authTag(16) + ciphertext(N)
   */
  encrypt(userId, plaintextBuffer) {
    const key = this.deriveKey(userId);
    const iv = crypto.randomBytes(IV_LENGTH);

    const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
    const ciphertext = Buffer.concat([
      cipher.update(plaintextBuffer),
      cipher.final()
    ]);
    const authTag = cipher.getAuthTag();

    logger.debug('Document encrypted', {
      userId,
      inputLength: plaintextBuffer.length,
      outputLength: IV_LENGTH + AUTH_TAG_LENGTH + ciphertext.length
    });

    return Buffer.concat([iv, authTag, ciphertext]);
  }

  /**
   * Decrypt a packed encrypted buffer for a specific user.
   *
   * @param {string} userId - The user ID for key derivation
   * @param {Buffer} encryptedBuffer - Packed buffer: iv(12) + authTag(16) + ciphertext(N)
   * @returns {Buffer} Decrypted plaintext
   * @throws {Error} If authentication fails (tampered data or wrong key)
   */
  decrypt(userId, encryptedBuffer) {
    const key = this.deriveKey(userId);

    const iv = encryptedBuffer.subarray(0, IV_LENGTH);
    const authTag = encryptedBuffer.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
    const ciphertext = encryptedBuffer.subarray(IV_LENGTH + AUTH_TAG_LENGTH);

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    const plaintext = Buffer.concat([
      decipher.update(ciphertext),
      decipher.final()
    ]);

    logger.debug('Document decrypted', {
      userId,
      inputLength: encryptedBuffer.length,
      outputLength: plaintext.length
    });

    return plaintext;
  }
}

module.exports = new DocumentEncryptionService();
