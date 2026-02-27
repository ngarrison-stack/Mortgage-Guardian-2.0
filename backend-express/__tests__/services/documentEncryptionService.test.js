/**
 * Document Encryption Service Tests
 *
 * TDD RED phase: All tests written before implementation.
 * Tests cover round-trip encrypt/decrypt, key derivation correctness,
 * tamper detection (AES-256-GCM authentication), edge cases, and pack format.
 */

const crypto = require('crypto');

// Generate a deterministic test master key (32 bytes hex-encoded)
const TEST_MASTER_KEY = crypto.randomBytes(32).toString('hex');

// Set env var BEFORE requiring the service
beforeAll(() => {
  process.env.DOCUMENT_ENCRYPTION_KEY = TEST_MASTER_KEY;
});

afterAll(() => {
  delete process.env.DOCUMENT_ENCRYPTION_KEY;
});

// Require after env is set (lazy require inside tests to handle missing-env test)
let encryptionService;
function getService() {
  if (!encryptionService) {
    encryptionService = require('../../services/documentEncryptionService');
  }
  return encryptionService;
}

describe('DocumentEncryptionService', () => {
  const userId = 'user-abc-123';
  const otherUserId = 'user-xyz-789';

  // 1. Round-trip encrypt/decrypt returns original data
  test('encrypt then decrypt returns original data (round-trip)', () => {
    const service = getService();
    const plaintext = Buffer.from('Hello, mortgage documents!');

    const encrypted = service.encrypt(userId, plaintext);
    const decrypted = service.decrypt(userId, encrypted);

    expect(decrypted).toEqual(plaintext);
  });

  // 2. Different users get different derived keys
  test('different users get different derived keys', () => {
    const service = getService();
    const key1 = service.deriveKey(userId);
    const key2 = service.deriveKey(otherUserId);

    expect(Buffer.isBuffer(key1)).toBe(true);
    expect(Buffer.isBuffer(key2)).toBe(true);
    expect(key1.length).toBe(32);
    expect(key2.length).toBe(32);
    expect(key1.equals(key2)).toBe(false);
  });

  // 3. Same user always gets same derived key (deterministic)
  test('same user always gets same derived key (deterministic)', () => {
    const service = getService();
    const key1 = service.deriveKey(userId);
    const key2 = service.deriveKey(userId);

    expect(key1.equals(key2)).toBe(true);
  });

  // 4. Tampered ciphertext throws authentication error
  test('tampered ciphertext throws authentication error', () => {
    const service = getService();
    const plaintext = Buffer.from('Sensitive mortgage data');
    const encrypted = service.encrypt(userId, plaintext);

    // Tamper with ciphertext portion (after iv[12] + authTag[16] = byte 28+)
    const tampered = Buffer.from(encrypted);
    if (tampered.length > 28) {
      tampered[28] ^= 0xff; // flip bits in first ciphertext byte
    }

    expect(() => service.decrypt(userId, tampered)).toThrow();
  });

  // 5. Tampered authTag throws authentication error
  test('tampered authTag throws authentication error', () => {
    const service = getService();
    const plaintext = Buffer.from('Sensitive mortgage data');
    const encrypted = service.encrypt(userId, plaintext);

    // Tamper with authTag portion (bytes 12-27)
    const tampered = Buffer.from(encrypted);
    tampered[12] ^= 0xff; // flip bits in first authTag byte

    expect(() => service.decrypt(userId, tampered)).toThrow();
  });

  // 6. Wrong userId for decrypt throws error (wrong key)
  test('wrong userId for decrypt throws error', () => {
    const service = getService();
    const plaintext = Buffer.from('User-specific document');
    const encrypted = service.encrypt(userId, plaintext);

    // Attempt to decrypt with different user's key
    expect(() => service.decrypt(otherUserId, encrypted)).toThrow();
  });

  // 7. Missing DOCUMENT_ENCRYPTION_KEY env var throws descriptive error
  test('missing DOCUMENT_ENCRYPTION_KEY env var throws descriptive error', () => {
    const savedKey = process.env.DOCUMENT_ENCRYPTION_KEY;
    delete process.env.DOCUMENT_ENCRYPTION_KEY;

    try {
      // Use jest.isolateModules for a clean require without cache
      let loadError = null;
      jest.isolateModules(() => {
        try {
          require('../../services/documentEncryptionService');
        } catch (err) {
          loadError = err;
        }
      });

      expect(loadError).not.toBeNull();
      expect(loadError.message).toMatch(/DOCUMENT_ENCRYPTION_KEY/);
    } finally {
      process.env.DOCUMENT_ENCRYPTION_KEY = savedKey;
    }
  });

  // 8. Empty buffer encrypt/decrypt works (0-byte files)
  test('empty buffer encrypt/decrypt works', () => {
    const service = getService();
    const plaintext = Buffer.alloc(0);

    const encrypted = service.encrypt(userId, plaintext);
    const decrypted = service.decrypt(userId, encrypted);

    expect(decrypted).toEqual(plaintext);
    expect(decrypted.length).toBe(0);
  });

  // 9. Large buffer (1MB) encrypt/decrypt works correctly
  test('large buffer (1MB) encrypt/decrypt works correctly', () => {
    const service = getService();
    const plaintext = crypto.randomBytes(1024 * 1024); // 1MB

    const encrypted = service.encrypt(userId, plaintext);
    const decrypted = service.decrypt(userId, encrypted);

    expect(decrypted).toEqual(plaintext);
  });

  // 10. Encrypted output is different from plaintext (not passthrough)
  test('encrypted output differs from plaintext', () => {
    const service = getService();
    const plaintext = Buffer.from('This should be encrypted, not passed through');

    const encrypted = service.encrypt(userId, plaintext);

    // The encrypted output should not contain the plaintext as-is
    expect(encrypted.equals(plaintext)).toBe(false);
    // Also verify the ciphertext portion (after iv+authTag) differs
    const ciphertextPortion = encrypted.subarray(28);
    expect(ciphertextPortion.equals(plaintext)).toBe(false);
  });

  // 11. Pack format: output length = 12 (iv) + 16 (authTag) + plaintext.length (GCM no padding)
  test('pack format length = 12 + 16 + plaintext.length', () => {
    const service = getService();

    // Test with various plaintext sizes
    const sizes = [0, 1, 16, 100, 1000];

    for (const size of sizes) {
      const plaintext = crypto.randomBytes(size);
      const encrypted = service.encrypt(userId, plaintext);

      const expectedLength = 12 + 16 + size;
      expect(encrypted.length).toBe(expectedLength);
    }
  });
});
