const { createClient } = require('@supabase/supabase-js');
const { createLogger } = require('../utils/logger');
const logger = createLogger('case-file');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

let supabase = null;
if (supabaseUrl && supabaseServiceKey) {
  supabase = createClient(supabaseUrl, supabaseServiceKey);
  logger.info('Supabase client initialized for case files');
} else {
  logger.warn('Supabase not configured - case file service will use mock storage');
}

class CaseFileService {
  constructor() {
    this.mockCases = new Map();       // In-memory storage for mock mode
    this.mockDocCaseMap = new Map();   // documentId → caseId mapping for mock mode
  }

  // ============================================
  // SUPABASE METHODS
  // ============================================

  /**
   * Create a new case file
   */
  async createCase({ userId, caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes }) {
    if (!supabase) {
      return this.mockCreateCase({ userId, caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes });
    }

    try {
      const { data, error } = await supabase
        .from('case_files')
        .insert({
          user_id: userId,
          case_name: caseName,
          borrower_name: borrowerName || null,
          property_address: propertyAddress || null,
          loan_number: loanNumber || null,
          servicer_name: servicerName || null,
          notes: notes || null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Case created', { caseId: data.id, userId });
      return data;

    } catch (error) {
      logger.error('Create case error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get all cases for a user, optionally filtered by status
   */
  async getCasesByUser({ userId, status, limit = 50, offset = 0 }) {
    if (!supabase) {
      return this.mockGetCasesByUser({ userId, status, limit, offset });
    }

    try {
      let query = supabase
        .from('case_files')
        .select('*')
        .eq('user_id', userId);

      if (status) {
        query = query.eq('status', status);
      }

      const { data, error } = await query
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      return data || [];

    } catch (error) {
      logger.error('Get cases error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get a single case with its associated documents
   */
  async getCase({ caseId, userId }) {
    if (!supabase) {
      return this.mockGetCase({ caseId, userId });
    }

    try {
      // Get the case
      const { data: caseData, error: caseError } = await supabase
        .from('case_files')
        .select('*')
        .eq('id', caseId)
        .eq('user_id', userId)
        .single();

      if (caseError) {
        throw new Error(`Database error: ${caseError.message}`);
      }

      if (!caseData) {
        return null;
      }

      // Get associated documents
      const { data: documents, error: docError } = await supabase
        .from('documents')
        .select('*')
        .eq('case_id', caseId)
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (docError) {
        logger.warn('Could not fetch case documents', { error: docError.message, caseId });
        return { ...caseData, documents: [] };
      }

      return { ...caseData, documents: documents || [] };

    } catch (error) {
      logger.error('Get case error', { error: error.message, caseId });
      throw error;
    }
  }

  /**
   * Update case fields (only provided fields are updated)
   */
  async updateCase({ caseId, userId, updates }) {
    if (!supabase) {
      return this.mockUpdateCase({ caseId, userId, updates });
    }

    try {
      // Map camelCase input to snake_case columns
      const dbUpdates = {};
      if (updates.caseName !== undefined) dbUpdates.case_name = updates.caseName;
      if (updates.borrowerName !== undefined) dbUpdates.borrower_name = updates.borrowerName;
      if (updates.propertyAddress !== undefined) dbUpdates.property_address = updates.propertyAddress;
      if (updates.loanNumber !== undefined) dbUpdates.loan_number = updates.loanNumber;
      if (updates.servicerName !== undefined) dbUpdates.servicerName = updates.servicerName;
      if (updates.status !== undefined) dbUpdates.status = updates.status;
      if (updates.notes !== undefined) dbUpdates.notes = updates.notes;
      dbUpdates.updated_at = new Date().toISOString();

      const { data, error } = await supabase
        .from('case_files')
        .update(dbUpdates)
        .eq('id', caseId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Case updated', { caseId, userId, fields: Object.keys(dbUpdates) });
      return data;

    } catch (error) {
      logger.error('Update case error', { error: error.message, caseId });
      throw error;
    }
  }

  /**
   * Delete a case (documents remain but case_id set to NULL by FK cascade)
   */
  async deleteCase({ caseId, userId }) {
    if (!supabase) {
      return this.mockDeleteCase({ caseId, userId });
    }

    try {
      const { data, error } = await supabase
        .from('case_files')
        .delete()
        .eq('id', caseId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      if (!data) {
        throw new Error('Case not found');
      }

      logger.info('Case deleted', { caseId, userId });
      return { success: true };

    } catch (error) {
      logger.error('Delete case error', { error: error.message, caseId });
      throw error;
    }
  }

  /**
   * Add a document to a case (update documents.case_id)
   */
  async addDocumentToCase({ caseId, documentId, userId }) {
    if (!supabase) {
      return this.mockAddDocumentToCase({ caseId, documentId, userId });
    }

    try {
      const { data, error } = await supabase
        .from('documents')
        .update({ case_id: caseId, updated_at: new Date().toISOString() })
        .eq('document_id', documentId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Document added to case', { caseId, documentId, userId });
      return data;

    } catch (error) {
      logger.error('Add document to case error', { error: error.message, caseId, documentId });
      throw error;
    }
  }

  /**
   * Remove a document from its case (set case_id to NULL)
   */
  async removeDocumentFromCase({ documentId, userId }) {
    if (!supabase) {
      return this.mockRemoveDocumentFromCase({ documentId, userId });
    }

    try {
      const { data, error } = await supabase
        .from('documents')
        .update({ case_id: null, updated_at: new Date().toISOString() })
        .eq('document_id', documentId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      logger.info('Document removed from case', { documentId, userId });
      return data;

    } catch (error) {
      logger.error('Remove document from case error', { error: error.message, documentId });
      throw error;
    }
  }

  // ============================================
  // MOCK METHODS (used when Supabase not configured)
  // ============================================

  mockCreateCase({ userId, caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes }) {
    const id = `mock-case-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const caseData = {
      id,
      user_id: userId,
      case_name: caseName,
      borrower_name: borrowerName || null,
      property_address: propertyAddress || null,
      loan_number: loanNumber || null,
      servicer_name: servicerName || null,
      status: 'open',
      notes: notes || null,
      metadata: {},
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    this.mockCases.set(id, caseData);
    logger.debug('Mock: created case', { caseId: id, userId });
    return caseData;
  }

  mockGetCasesByUser({ userId, status, limit = 50, offset = 0 }) {
    let cases = Array.from(this.mockCases.values())
      .filter(c => c.user_id === userId);

    if (status) {
      cases = cases.filter(c => c.status === status);
    }

    cases.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return cases.slice(offset, offset + limit);
  }

  mockGetCase({ caseId, userId }) {
    const caseData = this.mockCases.get(caseId);
    if (!caseData || caseData.user_id !== userId) {
      return null;
    }

    // Gather documents assigned to this case
    const documents = [];
    for (const [docId, assignedCaseId] of this.mockDocCaseMap.entries()) {
      if (assignedCaseId === caseId) {
        documents.push({ document_id: docId, case_id: caseId });
      }
    }

    return { ...caseData, documents };
  }

  mockUpdateCase({ caseId, userId, updates }) {
    const caseData = this.mockCases.get(caseId);
    if (!caseData || caseData.user_id !== userId) {
      throw new Error('Case not found');
    }

    if (updates.caseName !== undefined) caseData.case_name = updates.caseName;
    if (updates.borrowerName !== undefined) caseData.borrower_name = updates.borrowerName;
    if (updates.propertyAddress !== undefined) caseData.property_address = updates.propertyAddress;
    if (updates.loanNumber !== undefined) caseData.loan_number = updates.loanNumber;
    if (updates.servicerName !== undefined) caseData.servicer_name = updates.servicerName;
    if (updates.status !== undefined) caseData.status = updates.status;
    if (updates.notes !== undefined) caseData.notes = updates.notes;
    caseData.updated_at = new Date().toISOString();

    this.mockCases.set(caseId, caseData);
    logger.debug('Mock: updated case', { caseId, userId });
    return caseData;
  }

  mockDeleteCase({ caseId, userId }) {
    const caseData = this.mockCases.get(caseId);
    if (!caseData || caseData.user_id !== userId) {
      throw new Error('Case not found');
    }

    this.mockCases.delete(caseId);

    // Unlink documents from this case
    for (const [docId, assignedCaseId] of this.mockDocCaseMap.entries()) {
      if (assignedCaseId === caseId) {
        this.mockDocCaseMap.delete(docId);
      }
    }

    logger.debug('Mock: deleted case', { caseId, userId });
    return { success: true };
  }

  mockAddDocumentToCase({ caseId, documentId, userId }) {
    const caseData = this.mockCases.get(caseId);
    if (!caseData || caseData.user_id !== userId) {
      throw new Error('Case not found');
    }

    this.mockDocCaseMap.set(documentId, caseId);
    logger.debug('Mock: added document to case', { caseId, documentId });
    return { document_id: documentId, case_id: caseId };
  }

  mockRemoveDocumentFromCase({ documentId, userId }) {
    this.mockDocCaseMap.delete(documentId);
    logger.debug('Mock: removed document from case', { documentId });
    return { document_id: documentId, case_id: null };
  }
}

module.exports = new CaseFileService();
