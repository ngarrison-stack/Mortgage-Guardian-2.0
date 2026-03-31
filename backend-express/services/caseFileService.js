const { createLogger } = require('../utils/logger');
const logger = createLogger('case-file');

// Initialize pg query function when DATABASE_URL is available
let query = null;
if (process.env.DATABASE_URL) {
  const db = require('./db');
  query = db.query;
  logger.info('PostgreSQL client initialized for case files');
} else {
  logger.warn('DATABASE_URL not configured - case file service will use mock storage');
}

class CaseFileService {
  constructor() {
    this.mockCases = new Map();       // In-memory storage for mock mode
    this.mockDocCaseMap = new Map();   // documentId → caseId mapping for mock mode
  }

  // ============================================
  // POSTGRESQL METHODS
  // ============================================

  /**
   * Create a new case file
   */
  async createCase({ userId, caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes }) {
    if (!query) {
      return this.mockCreateCase({ userId, caseName, borrowerName, propertyAddress, loanNumber, servicerName, notes });
    }

    try {
      const { rows } = await query(
        `INSERT INTO case_files (user_id, case_name, borrower_name, property_address, loan_number, servicer_name, notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [userId, caseName, borrowerName || null, propertyAddress || null, loanNumber || null, servicerName || null, notes || null]
      );

      logger.info('Case created', { caseId: rows[0].id, userId });
      return rows[0];

    } catch (error) {
      logger.error('Create case error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get all cases for a user, optionally filtered by status
   */
  async getCasesByUser({ userId, status, limit = 50, offset = 0 }) {
    if (!query) {
      return this.mockGetCasesByUser({ userId, status, limit, offset });
    }

    try {
      let sql = 'SELECT * FROM case_files WHERE user_id = $1';
      const params = [userId];
      let paramIdx = 2;

      if (status) {
        sql += ` AND status = $${paramIdx}`;
        params.push(status);
        paramIdx++;
      }

      sql += ` ORDER BY created_at DESC LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`;
      params.push(limit, offset);

      const { rows } = await query(sql, params);
      return rows;

    } catch (error) {
      logger.error('Get cases error', { error: error.message, userId });
      throw error;
    }
  }

  /**
   * Get a single case with its associated documents
   */
  async getCase({ caseId, userId }) {
    if (!query) {
      return this.mockGetCase({ caseId, userId });
    }

    try {
      // Get the case
      const { rows: caseRows } = await query(
        'SELECT * FROM case_files WHERE id = $1 AND user_id = $2',
        [caseId, userId]
      );

      if (caseRows.length === 0) {
        return null;
      }

      // Get associated documents
      let documents = [];
      try {
        const { rows: docRows } = await query(
          'SELECT * FROM documents WHERE case_id = $1 AND user_id = $2 ORDER BY created_at DESC',
          [caseId, userId]
        );
        documents = docRows;
      } catch (docError) {
        logger.warn('Could not fetch case documents', { error: docError.message, caseId });
      }

      return { ...caseRows[0], documents };

    } catch (error) {
      logger.error('Get case error', { error: error.message, caseId });
      throw error;
    }
  }

  /**
   * Update case fields (only provided fields are updated)
   */
  async updateCase({ caseId, userId, updates }) {
    if (!query) {
      return this.mockUpdateCase({ caseId, userId, updates });
    }

    try {
      // Build SET clause dynamically from updates
      const setClauses = [];
      const params = [];
      let idx = 1;

      if (updates.caseName !== undefined) { setClauses.push(`case_name = $${idx++}`); params.push(updates.caseName); }
      if (updates.borrowerName !== undefined) { setClauses.push(`borrower_name = $${idx++}`); params.push(updates.borrowerName); }
      if (updates.propertyAddress !== undefined) { setClauses.push(`property_address = $${idx++}`); params.push(updates.propertyAddress); }
      if (updates.loanNumber !== undefined) { setClauses.push(`loan_number = $${idx++}`); params.push(updates.loanNumber); }
      if (updates.servicerName !== undefined) { setClauses.push(`servicer_name = $${idx++}`); params.push(updates.servicerName); }
      if (updates.status !== undefined) { setClauses.push(`status = $${idx++}`); params.push(updates.status); }
      if (updates.notes !== undefined) { setClauses.push(`notes = $${idx++}`); params.push(updates.notes); }
      setClauses.push(`updated_at = NOW()`);

      const sql = `UPDATE case_files SET ${setClauses.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`;
      params.push(caseId, userId);

      const { rows } = await query(sql, params);

      if (rows.length === 0) {
        throw new Error('Case not found');
      }

      logger.info('Case updated', { caseId, userId, fields: Object.keys(updates) });
      return rows[0];

    } catch (error) {
      logger.error('Update case error', { error: error.message, caseId });
      throw error;
    }
  }

  /**
   * Delete a case (documents remain but case_id set to NULL by FK cascade)
   */
  async deleteCase({ caseId, userId }) {
    if (!query) {
      return this.mockDeleteCase({ caseId, userId });
    }

    try {
      const { rows } = await query(
        'DELETE FROM case_files WHERE id = $1 AND user_id = $2 RETURNING *',
        [caseId, userId]
      );

      if (rows.length === 0) {
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
    if (!query) {
      return this.mockAddDocumentToCase({ caseId, documentId, userId });
    }

    try {
      const { rows } = await query(
        'UPDATE documents SET case_id = $1, updated_at = NOW() WHERE document_id = $2 AND user_id = $3 RETURNING *',
        [caseId, documentId, userId]
      );

      if (rows.length === 0) {
        throw new Error('Document not found');
      }

      logger.info('Document added to case', { caseId, documentId, userId });
      return rows[0];

    } catch (error) {
      logger.error('Add document to case error', { error: error.message, caseId, documentId });
      throw error;
    }
  }

  /**
   * Remove a document from its case (set case_id to NULL)
   */
  async removeDocumentFromCase({ documentId, userId }) {
    if (!query) {
      return this.mockRemoveDocumentFromCase({ documentId, userId });
    }

    try {
      const { rows } = await query(
        'UPDATE documents SET case_id = NULL, updated_at = NOW() WHERE document_id = $1 AND user_id = $2 RETURNING *',
        [documentId, userId]
      );

      if (rows.length === 0) {
        throw new Error('Document not found');
      }

      logger.info('Document removed from case', { documentId, userId });
      return rows[0];

    } catch (error) {
      logger.error('Remove document from case error', { error: error.message, documentId });
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
    this.mockCases.clear();
    this.mockDocCaseMap.clear();
    logger.debug('Mock case data cleared', { reason: 'manual cleanup' });
  }

  /**
   * Safety valve: if mock Maps exceed 500 entries, log a warning
   * and evict the oldest 100 entries (by Map insertion order).
   */
  _enforceMockSizeLimit() {
    if (this.mockCases.size > 500) {
      logger.warn('Mock case store exceeded 500 entries, evicting oldest 100', {
        currentSize: this.mockCases.size
      });
      const keys = [...this.mockCases.keys()].slice(0, 100);
      for (const key of keys) {
        this.mockCases.delete(key);
      }
    }
    if (this.mockDocCaseMap.size > 500) {
      logger.warn('Mock doc-case map exceeded 500 entries, evicting oldest 100', {
        currentSize: this.mockDocCaseMap.size
      });
      const keys = [...this.mockDocCaseMap.keys()].slice(0, 100);
      for (const key of keys) {
        this.mockDocCaseMap.delete(key);
      }
    }
  }

  // ============================================
  // MOCK METHODS (used when DATABASE_URL not configured)
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
    this._enforceMockSizeLimit();
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
    this._enforceMockSizeLimit();
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
