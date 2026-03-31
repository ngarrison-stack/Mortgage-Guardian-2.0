const fs = require('fs').promises;
const path = require('path');
const { createLogger } = require('../utils/logger');
const logger = createLogger('document');

// Lazy-loaded encryption service — only initialized when DOCUMENT_ENCRYPTION_KEY is set.
// Cannot require at module load because the constructor throws if the env var is missing,
// and we need graceful degradation for dev environments without encryption configured.
let _encryptionService = null;
let _encryptionWarningLogged = false;

function getEncryptionService() {
  if (_encryptionService) return _encryptionService;

  if (!process.env.DOCUMENT_ENCRYPTION_KEY) {
    if (!_encryptionWarningLogged) {
      logger.warn('DOCUMENT_ENCRYPTION_KEY not set — documents will be stored unencrypted');
      _encryptionWarningLogged = true;
    }
    return null;
  }

  try {
    _encryptionService = require('./documentEncryptionService');
    return _encryptionService;
  } catch (err) {
    logger.error('Failed to initialize encryption service', { error: err.message });
    return null;
  }
}

// Lazy-loaded db module — only initialized when DATABASE_URL is set
let _db = null;
function getDb() {
  if (_db) return _db;
  if (!process.env.DATABASE_URL) return null;
  _db = require('../db');
  logger.info('Database client initialized');
  return _db;
}

// Resolve the upload directory for local file storage
function getUploadDir() {
  return process.env.UPLOAD_DIR || './uploads';
}

class DocumentService {
  constructor() {
    this.mockDocuments = new Map(); // In-memory storage for mock mode
  }

  /**
   * Validate that a storage path is safe and belongs to the authenticated user.
   * Defense-in-depth: even though paths are constructed internally, this guards
   * against future code changes that might pass untrusted paths.
   *
   * @param {string} userId - The authenticated user's ID
   * @param {string} storagePath - The storage path to validate
   * @throws {Error} If the path is invalid or does not belong to the user
   */
  validateStoragePath(userId, storagePath) {
    const expectedPrefix = `documents/${userId}/`;

    // Reject directory traversal attempts
    if (storagePath.includes('..')) {
      logger.warn('Path traversal attempt detected', { userId, storagePath });
      throw new Error('Invalid storage path: directory traversal not allowed');
    }

    // Reject double-slash injection
    if (storagePath.includes('//')) {
      logger.warn('Double-slash injection attempt detected', { userId, storagePath });
      throw new Error('Invalid storage path: invalid path format');
    }

    // Verify path starts with expected user-scoped prefix
    if (!storagePath.startsWith(expectedPrefix)) {
      logger.warn('Storage path userId mismatch', { userId, storagePath, expectedPrefix });
      throw new Error('Invalid storage path: user path mismatch');
    }
  }

  /**
   * Resolve a local filesystem path for a document.
   */
  _localPath(userId, documentId) {
    return path.join(getUploadDir(), userId, documentId);
  }

  /**
   * Upload document to local filesystem and save metadata to database
   */
  async uploadDocument({ documentId, userId, fileName, documentType, content, analysisResults, metadata }) {
    // Use mock storage if database not configured
    if (!process.env.DATABASE_URL) {
      return this.mockUploadDocument({ documentId, userId, fileName, documentType, content, analysisResults, metadata });
    }

    try {
      const db = getDb();

      // 1. Upload file content to local filesystem
      const storagePath = `documents/${userId}/${documentId}`;
      this.validateStoragePath(userId, storagePath);
      const fileBuffer = Buffer.from(content, 'base64');

      // Encrypt file buffer if encryption is configured
      const encryptionService = getEncryptionService();
      let uploadBuffer;
      let encrypted = false;
      if (encryptionService) {
        uploadBuffer = encryptionService.encrypt(userId, fileBuffer);
        encrypted = true;
        logger.debug('Document encrypted for upload', { documentId, userId });
      } else {
        uploadBuffer = fileBuffer;
      }

      const filePath = this._localPath(userId, documentId);
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(filePath, uploadBuffer);

      // 2. Save metadata to database
      const now = new Date().toISOString();
      const result = await db.query(
        `INSERT INTO documents (document_id, user_id, file_name, document_type, analysis_results, metadata, storage_path, encrypted, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING *`,
        [
          documentId,
          userId,
          fileName,
          documentType,
          analysisResults ? JSON.stringify(analysisResults) : null,
          JSON.stringify(metadata || {}),
          storagePath,
          encrypted,
          now,
          now
        ]
      );

      const dbData = result.rows[0];

      return {
        documentId,
        storagePath,
        metadata: dbData
      };

    } catch (error) {
      logger.error('Document upload error', { error: error.message, documentId });
      throw error;
    }
  }

  /**
   * Get all documents for a user
   */
  async getDocumentsByUser({ userId, limit = 50, offset = 0 }) {
    if (!process.env.DATABASE_URL) {
      return this.mockGetDocumentsByUser({ userId, limit, offset });
    }

    try {
      const db = getDb();
      const result = await db.query(
        `SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
        [userId, limit, offset]
      );

      return result.rows || [];

    } catch (error) {
      logger.error('Get documents error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get a specific document
   */
  async getDocument({ documentId, userId }) {
    if (!process.env.DATABASE_URL) {
      return this.mockGetDocument({ documentId, userId });
    }

    try {
      const db = getDb();

      // Get metadata from database
      const result = await db.query(
        `SELECT * FROM documents WHERE document_id = $1 AND user_id = $2`,
        [documentId, userId]
      );

      const metadata = result.rows[0];

      if (!metadata) {
        return null;
      }

      // Validate storage path before downloading
      this.validateStoragePath(userId, metadata.storage_path);

      // Get file from local filesystem
      let buffer;
      try {
        const filePath = this._localPath(userId, documentId);
        buffer = await fs.readFile(filePath);
      } catch (readErr) {
        logger.warn('Could not download file', { error: readErr.message, documentId });
        // Return metadata even if file download fails
        return metadata;
      }

      // Decrypt if the document was stored encrypted
      if (metadata.encrypted) {
        const encryptionService = getEncryptionService();
        if (encryptionService) {
          buffer = encryptionService.decrypt(userId, buffer);
          logger.debug('Document decrypted for download', { documentId, userId });
        } else {
          logger.error('Document is encrypted but encryption service unavailable', { documentId });
          throw new Error('Cannot decrypt document: encryption service unavailable');
        }
      }

      const contentBase64 = buffer.toString('base64');

      return {
        ...metadata,
        content: contentBase64
      };

    } catch (error) {
      logger.error('Get document error', { error: error.message, documentId });
      throw error;
    }
  }

  /**
   * Delete a document
   */
  async deleteDocument({ documentId, userId }) {
    if (!process.env.DATABASE_URL) {
      return this.mockDeleteDocument({ documentId, userId });
    }

    try {
      const db = getDb();

      // Get document metadata first
      const result = await db.query(
        `SELECT storage_path FROM documents WHERE document_id = $1 AND user_id = $2`,
        [documentId, userId]
      );

      const doc = result.rows[0];

      if (!doc) {
        throw new Error('Document not found');
      }

      // Validate storage path before deleting
      this.validateStoragePath(userId, doc.storage_path);

      // Delete from local filesystem
      try {
        const filePath = this._localPath(userId, documentId);
        await fs.unlink(filePath);
      } catch (unlinkErr) {
        logger.warn('Storage deletion error', { error: unlinkErr.message, documentId });
      }

      // Delete from database
      await db.query(
        `DELETE FROM documents WHERE document_id = $1 AND user_id = $2`,
        [documentId, userId]
      );

      return { success: true };

    } catch (error) {
      logger.error('Delete document error', { error: error.message, documentId });
      throw error;
    }
  }

  // ============================================
  // MOCK DATA MANAGEMENT
  // ============================================

  /**
   * Clear all mock data. Useful for test teardown and manual cleanup.
   */
  clearMockData() {
    this.mockDocuments.clear();
    logger.debug('Mock document data cleared', { reason: 'manual cleanup' });
  }

  /**
   * Safety valve: if mock documents Map exceeds 500 entries, log a warning
   * and evict the oldest 100 entries (by Map insertion order).
   */
  _enforceMockSizeLimit() {
    if (this.mockDocuments.size > 500) {
      logger.warn('Mock document store exceeded 500 entries, evicting oldest 100', {
        currentSize: this.mockDocuments.size
      });
      const keys = [...this.mockDocuments.keys()].slice(0, 100);
      for (const key of keys) {
        this.mockDocuments.delete(key);
      }
    }
  }

  // ============================================
  // MOCK METHODS (used when Supabase not configured)
  // ============================================

  mockUploadDocument({ documentId, userId, fileName, documentType, content, analysisResults, metadata }) {
    const storagePath = `mock://${userId}/${documentId}`;
    this.mockDocuments.set(documentId, {
      document_id: documentId,
      user_id: userId,
      file_name: fileName,
      document_type: documentType,
      content,
      analysis_results: analysisResults,
      metadata,
      storage_path: storagePath,
      created_at: new Date().toISOString()
    });

    this._enforceMockSizeLimit();
    logger.debug('Mock: uploaded document', { documentId, userId });
    return { documentId, storagePath };
  }

  mockGetDocumentsByUser({ userId }) {
    const userDocs = Array.from(this.mockDocuments.values())
      .filter(doc => doc.user_id === userId);
    logger.debug('Mock: retrieved documents', { count: userDocs.length, userId });
    return userDocs;
  }

  mockGetDocument({ documentId, userId }) {
    const doc = this.mockDocuments.get(documentId);
    if (doc && doc.user_id === userId) {
      logger.debug('Mock: retrieved document', { documentId });
      return doc;
    }
    return null;
  }

  mockDeleteDocument({ documentId, userId }) {
    const doc = this.mockDocuments.get(documentId);
    if (doc && doc.user_id === userId) {
      this.mockDocuments.delete(documentId);
      logger.debug('Mock: deleted document', { documentId });
      return { success: true };
    }
    throw new Error('Document not found');
  }

  // Helper methods
  getContentType(fileName) {
    const ext = fileName.split('.').pop().toLowerCase();
    const contentTypes = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'heic': 'image/heic',
      'txt': 'text/plain'
    };
    return contentTypes[ext] || 'application/octet-stream';
  }
}

module.exports = new DocumentService();
