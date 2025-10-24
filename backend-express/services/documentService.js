const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (supabaseUrl && supabaseServiceKey) {
  supabase = createClient(supabaseUrl, supabaseServiceKey);
  console.log('✅ Supabase client initialized');
} else {
  console.warn('⚠️  Supabase not configured - document storage will use mock service');
}

class DocumentService {
  constructor() {
    this.mockDocuments = new Map(); // In-memory storage for mock mode
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
      console.error('Document upload error:', error);
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
      console.error('Get documents error:', error);
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

      // Get file from storage
      const { data: fileData, error: storageError } = await supabase.storage
        .from('documents')
        .download(metadata.storage_path);

      if (storageError) {
        console.warn('Could not download file:', storageError);
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
      console.error('Get document error:', error);
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

      // Delete from storage
      const { error: storageError } = await supabase.storage
        .from('documents')
        .remove([doc.storage_path]);

      if (storageError) {
        console.warn('Storage deletion error:', storageError);
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
      console.error('Delete document error:', error);
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

    console.log(`Mock: Uploaded document ${documentId} for user ${userId}`);
    return { documentId, storagePath };
  }

  mockGetDocumentsByUser({ userId }) {
    const userDocs = Array.from(this.mockDocuments.values())
      .filter(doc => doc.user_id === userId);
    console.log(`Mock: Retrieved ${userDocs.length} documents for user ${userId}`);
    return userDocs;
  }

  mockGetDocument({ documentId, userId }) {
    const doc = this.mockDocuments.get(documentId);
    if (doc && doc.user_id === userId) {
      console.log(`Mock: Retrieved document ${documentId}`);
      return doc;
    }
    return null;
  }

  mockDeleteDocument({ documentId, userId }) {
    const doc = this.mockDocuments.get(documentId);
    if (doc && doc.user_id === userId) {
      this.mockDocuments.delete(documentId);
      console.log(`Mock: Deleted document ${documentId}`);
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
