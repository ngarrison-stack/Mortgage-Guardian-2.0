const { createClient } = require('@supabase/supabase-js');
const { createLogger } = require('../utils/logger');
const logger = createLogger('document');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (supabaseUrl && supabaseServiceKey) {
  supabase = createClient(supabaseUrl, supabaseServiceKey);
  logger.info('Supabase client initialized');
} else {
  logger.warn('Supabase not configured - document storage will use mock service');
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
   * Upload document to Supabase Storage and save metadata to database
   */
  async uploadDocument({ documentId, userId, fileName, documentType, content, analysisResults, metadata }) {
    // Use mock storage if Supabase not configured
    if (!supabase) {
      return this.mockUploadDocument({ documentId, userId, fileName, documentType, content, analysisResults, metadata });
    }

    try {
      // 1. Upload file content to Supabase Storage
      const storagePath = `documents/${userId}/${documentId}`;
      this.validateStoragePath(userId, storagePath);
      const fileBuffer = Buffer.from(content, 'base64');

      const { data: storageData, error: storageError } = await supabase.storage
        .from('documents')
        .upload(storagePath, fileBuffer, {
          contentType: this.getContentType(fileName),
          upsert: true
        });

      if (storageError) {
        throw new Error(`Storage error: ${storageError.message}`);
      }

      // 2. Save metadata to database
      const { data: dbData, error: dbError } = await supabase
        .from('documents')
        .insert({
          document_id: documentId,
          user_id: userId,
          file_name: fileName,
          document_type: documentType,
          analysis_results: analysisResults || null,
          metadata: metadata || {},
          storage_path: storagePath,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single();

      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }

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
    if (!supabase) {
      return this.mockGetDocumentsByUser({ userId, limit, offset });
    }

    try {
      const { data, error } = await supabase
        .from('documents')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      return data || [];

    } catch (error) {
      logger.error('Get documents error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get a specific document
   */
  async getDocument({ documentId, userId }) {
    if (!supabase) {
      return this.mockGetDocument({ documentId, userId });
    }

    try {
      // Get metadata from database
      const { data: metadata, error: dbError } = await supabase
        .from('documents')
        .select('*')
        .eq('document_id', documentId)
        .eq('user_id', userId)
        .single();

      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }

      if (!metadata) {
        return null;
      }

      // Validate storage path before downloading
      this.validateStoragePath(userId, metadata.storage_path);

      // Get file from storage
      const { data: fileData, error: storageError } = await supabase.storage
        .from('documents')
        .download(metadata.storage_path);

      if (storageError) {
        logger.warn('Could not download file', { error: storageError.message, documentId });
        // Return metadata even if file download fails
        return metadata;
      }

      // Convert file to base64
      const arrayBuffer = await fileData.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);
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
    if (!supabase) {
      return this.mockDeleteDocument({ documentId, userId });
    }

    try {
      // Get document metadata first
      const { data: doc } = await supabase
        .from('documents')
        .select('storage_path')
        .eq('document_id', documentId)
        .eq('user_id', userId)
        .single();

      if (!doc) {
        throw new Error('Document not found');
      }

      // Validate storage path before deleting
      this.validateStoragePath(userId, doc.storage_path);

      // Delete from storage
      const { error: storageError } = await supabase.storage
        .from('documents')
        .remove([doc.storage_path]);

      if (storageError) {
        logger.warn('Storage deletion error', { error: storageError.message, documentId });
      }

      // Delete from database
      const { error: dbError } = await supabase
        .from('documents')
        .delete()
        .eq('document_id', documentId)
        .eq('user_id', userId);

      if (dbError) {
        throw new Error(`Database error: ${dbError.message}`);
      }

      return { success: true };

    } catch (error) {
      logger.error('Delete document error', { error: error.message, documentId });
      throw error;
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
