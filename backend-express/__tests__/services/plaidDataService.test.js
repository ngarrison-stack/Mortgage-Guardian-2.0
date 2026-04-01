/**
 * Unit tests for PlaidDataService (services/plaidDataService.js)
 *
 * Tests both Supabase-backed mode and in-memory mock mode.
 * Supabase mock must be hoisted because the module creates a client at load time.
 */

// --- Supabase chainable mock ---
const mockUpsert = jest.fn();
const mockInsert = jest.fn();
const mockSelect = jest.fn();
const mockUpdate = jest.fn();
const mockDelete = jest.fn();
const mockEq = jest.fn();
const mockIn = jest.fn();
const mockSingle = jest.fn();

// Build the chainable mock object, then wire return values (can't self-reference during init)
const mockSupabase = {
  from: jest.fn(),
  upsert: mockUpsert,
  insert: mockInsert,
  select: mockSelect,
  update: mockUpdate,
  delete: mockDelete,
  eq: mockEq,
  in: mockIn,
  single: mockSingle
};
// Each chainable method returns the mock object so `.from(...).upsert(...)` etc. works.
mockSupabase.from.mockReturnValue(mockSupabase);
mockUpsert.mockReturnValue(mockSupabase);
mockInsert.mockReturnValue(mockSupabase);
mockSelect.mockReturnValue(mockSupabase);
mockUpdate.mockReturnValue(mockSupabase);
mockDelete.mockReturnValue(mockSupabase);
mockEq.mockReturnValue(mockSupabase);
mockIn.mockReturnValue(mockSupabase);

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockSupabase)
}));

// Set env vars BEFORE requiring the service so module-scope init creates a client
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_SERVICE_KEY = 'test-service-key';

const plaidDataService = require('../../services/plaidDataService');

// ============================================================
// Supabase mode tests
// ============================================================
describe('PlaidDataService (Supabase mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Reset chain defaults — each method returns the chain object
    mockUpsert.mockReturnValue(mockSupabase);
    mockInsert.mockReturnValue(mockSupabase);
    mockSelect.mockReturnValue(mockSupabase);
    mockUpdate.mockReturnValue(mockSupabase);
    mockDelete.mockReturnValue(mockSupabase);
    mockEq.mockReturnValue(mockSupabase);
    mockIn.mockReturnValue(mockSupabase);
  });

  // ----------------------------------------------------------
  // upsertPlaidItem
  // ----------------------------------------------------------
  describe('upsertPlaidItem', () => {
    it('upserts item data to plaid_items table', async () => {
      // Terminal method — upsert resolves the chain
      mockUpsert.mockResolvedValue({ data: { item_id: 'item-1' }, error: null });

      const result = await plaidDataService.upsertPlaidItem({
        itemId: 'item-1',
        userId: 'user-1',
        accessToken: 'access-token-1',
        status: 'active',
        institutionId: 'ins_123'
      });

      expect(result).toEqual({ success: true, data: { item_id: 'item-1' } });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_items');
      expect(mockUpsert).toHaveBeenCalledWith(
        expect.objectContaining({
          item_id: 'item-1',
          user_id: 'user-1',
          access_token: 'access-token-1',
          status: 'active',
          institution_id: 'ins_123'
        }),
        { onConflict: 'item_id' }
      );
    });

    it('defaults status to active when not provided', async () => {
      mockUpsert.mockResolvedValue({ data: {}, error: null });

      await plaidDataService.upsertPlaidItem({
        itemId: 'item-2',
        userId: 'user-1',
        accessToken: 'access-token-2'
      });

      expect(mockUpsert).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'active' }),
        expect.any(Object)
      );
    });

    it('serializes error object to JSON', async () => {
      mockUpsert.mockResolvedValue({ data: {}, error: null });

      const plaidError = { type: 'ITEM_ERROR', code: 'ITEM_LOGIN_REQUIRED' };
      await plaidDataService.upsertPlaidItem({
        itemId: 'item-3',
        userId: 'user-1',
        accessToken: 'tok',
        error: plaidError
      });

      expect(mockUpsert).toHaveBeenCalledWith(
        expect.objectContaining({ error: JSON.stringify(plaidError) }),
        expect.any(Object)
      );
    });

    it('returns { success: false } on database error', async () => {
      mockUpsert.mockResolvedValue({ data: null, error: { message: 'DB error' } });

      const result = await plaidDataService.upsertPlaidItem({
        itemId: 'item-err',
        userId: 'user-1',
        accessToken: 'tok'
      });

      expect(result).toEqual({ success: false, error: 'Database error: DB error' });
    });
  });

  // ----------------------------------------------------------
  // storeTransactions
  // ----------------------------------------------------------
  describe('storeTransactions', () => {
    const transactions = [
      {
        transaction_id: 'tx-1',
        account_id: 'acc-1',
        amount: 25.50,
        iso_currency_code: 'USD',
        unofficial_currency_code: null,
        category: ['Food', 'Restaurants'],
        category_id: '13005000',
        transaction_type: 'place',
        name: 'Burger Joint',
        merchant_name: 'Burger Joint',
        date: '2026-01-15',
        authorized_date: '2026-01-14',
        authorized_datetime: null,
        datetime: null,
        payment_channel: 'in store',
        location: { city: 'Portland', region: 'OR' },
        payment_meta: { reference_number: 'REF123' },
        account_owner: null,
        pending: false,
        pending_transaction_id: null,
        transaction_code: null
      }
    ];

    it('bulk upserts transactions to plaid_transactions table', async () => {
      mockUpsert.mockResolvedValue({ data: [], error: null });

      const result = await plaidDataService.storeTransactions({
        itemId: 'item-1',
        transactions,
        userId: 'user-1'
      });

      expect(result).toEqual({ success: true, count: 1, data: [] });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_transactions');
      expect(mockUpsert).toHaveBeenCalledWith(
        expect.arrayContaining([
          expect.objectContaining({
            transaction_id: 'tx-1',
            item_id: 'item-1',
            user_id: 'user-1'
          })
        ]),
        { onConflict: 'transaction_id' }
      );
    });

    it('maps Plaid transaction fields to database columns', async () => {
      mockUpsert.mockResolvedValue({ data: [], error: null });

      await plaidDataService.storeTransactions({
        itemId: 'item-1',
        transactions,
        userId: 'user-1'
      });

      const record = mockUpsert.mock.calls[0][0][0];
      expect(record.amount).toBe(25.50);
      expect(record.category).toBe(JSON.stringify(['Food', 'Restaurants']));
      expect(record.location).toBe(JSON.stringify({ city: 'Portland', region: 'OR' }));
      expect(record.payment_meta).toBe(JSON.stringify({ reference_number: 'REF123' }));
      expect(record.merchant_name).toBe('Burger Joint');
      expect(record.pending).toBe(false);
    });

    it('handles null category and location', async () => {
      mockUpsert.mockResolvedValue({ data: [], error: null });

      await plaidDataService.storeTransactions({
        itemId: 'item-1',
        transactions: [{
          transaction_id: 'tx-null',
          account_id: 'acc-1',
          amount: 10,
          category: null,
          location: null,
          payment_meta: null,
          date: '2026-01-15'
        }],
        userId: 'user-1'
      });

      const record = mockUpsert.mock.calls[0][0][0];
      expect(record.category).toBeNull();
      expect(record.location).toBeNull();
      expect(record.payment_meta).toBeNull();
    });

    it('returns { success: false } on database error', async () => {
      mockUpsert.mockResolvedValue({ data: null, error: { message: 'Insert failed' } });

      const result = await plaidDataService.storeTransactions({
        itemId: 'item-1',
        transactions,
        userId: 'user-1'
      });

      expect(result).toEqual({ success: false, error: 'Database error: Insert failed' });
    });
  });

  // ----------------------------------------------------------
  // removeTransactions
  // ----------------------------------------------------------
  describe('removeTransactions', () => {
    it('deletes transactions by IDs', async () => {
      mockIn.mockResolvedValue({ data: [], error: null });

      const result = await plaidDataService.removeTransactions({
        transactionIds: ['tx-1', 'tx-2']
      });

      expect(result).toEqual({ success: true, count: 2, data: [] });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_transactions');
      expect(mockIn).toHaveBeenCalledWith('transaction_id', ['tx-1', 'tx-2']);
    });

    it('returns { success: false } on database error', async () => {
      mockIn.mockResolvedValue({ data: null, error: { message: 'Delete failed' } });

      const result = await plaidDataService.removeTransactions({
        transactionIds: ['tx-bad']
      });

      expect(result).toEqual({ success: false, error: 'Database error: Delete failed' });
    });
  });

  // ----------------------------------------------------------
  // updateItemStatus
  // ----------------------------------------------------------
  describe('updateItemStatus', () => {
    it('updates status and error fields', async () => {
      mockEq.mockResolvedValue({ data: {}, error: null });

      const result = await plaidDataService.updateItemStatus({
        itemId: 'item-1',
        status: 'error',
        error: { code: 'ITEM_LOGIN_REQUIRED' },
        requiresAction: true
      });

      expect(result).toEqual({ success: true, data: {} });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_items');
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'error',
          error: JSON.stringify({ code: 'ITEM_LOGIN_REQUIRED' }),
          requires_user_action: true
        })
      );
      expect(mockEq).toHaveBeenCalledWith('item_id', 'item-1');
    });

    it('sets null error when not provided', async () => {
      mockEq.mockResolvedValue({ data: {}, error: null });

      await plaidDataService.updateItemStatus({
        itemId: 'item-1',
        status: 'active'
      });

      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ error: null, requires_user_action: false })
      );
    });

    it('returns { success: false } on database error', async () => {
      mockEq.mockResolvedValue({ data: null, error: { message: 'Update failed' } });

      const result = await plaidDataService.updateItemStatus({
        itemId: 'item-bad',
        status: 'error'
      });

      expect(result).toEqual({ success: false, error: 'Database error: Update failed' });
    });
  });

  // ----------------------------------------------------------
  // upsertAccounts
  // ----------------------------------------------------------
  describe('upsertAccounts', () => {
    const accounts = [
      {
        account_id: 'acc-1',
        name: 'Checking',
        official_name: 'Premium Checking',
        type: 'depository',
        subtype: 'checking',
        mask: '1234',
        balances: {
          current: 5000,
          available: 4800,
          limit: null,
          iso_currency_code: 'USD',
          unofficial_currency_code: null
        }
      }
    ];

    it('upserts account records with balance data', async () => {
      mockUpsert.mockResolvedValue({ data: [], error: null });

      const result = await plaidDataService.upsertAccounts({
        itemId: 'item-1',
        accounts,
        userId: 'user-1'
      });

      expect(result).toEqual({ success: true, count: 1, data: [] });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_accounts');

      const record = mockUpsert.mock.calls[0][0][0];
      expect(record.account_id).toBe('acc-1');
      expect(record.current_balance).toBe(5000);
      expect(record.available_balance).toBe(4800);
      expect(record.limit).toBeNull();
      expect(record.iso_currency_code).toBe('USD');
    });

    it('returns { success: false } on database error', async () => {
      mockUpsert.mockResolvedValue({ data: null, error: { message: 'Upsert failed' } });

      const result = await plaidDataService.upsertAccounts({
        itemId: 'item-1',
        accounts,
        userId: 'user-1'
      });

      expect(result).toEqual({ success: false, error: 'Database error: Upsert failed' });
    });
  });

  // ----------------------------------------------------------
  // getItem
  // ----------------------------------------------------------
  describe('getItem', () => {
    it('returns item data by item_id', async () => {
      const itemData = { item_id: 'item-1', status: 'active' };
      mockSingle.mockResolvedValue({ data: itemData, error: null });

      const result = await plaidDataService.getItem('item-1');

      expect(result).toEqual({ success: true, data: itemData });
      expect(mockSupabase.from).toHaveBeenCalledWith('plaid_items');
      expect(mockEq).toHaveBeenCalledWith('item_id', 'item-1');
    });

    it('returns { success: false } on database error', async () => {
      mockSingle.mockResolvedValue({ data: null, error: { message: 'Not found' } });

      const result = await plaidDataService.getItem('item-missing');

      expect(result).toEqual({ success: false, error: 'Database error: Not found' });
    });
  });

  // ----------------------------------------------------------
  // createNotification
  // ----------------------------------------------------------
  describe('createNotification', () => {
    it('inserts notification record', async () => {
      mockInsert.mockResolvedValue({ data: { id: 1 }, error: null });

      const result = await plaidDataService.createNotification({
        userId: 'user-1',
        itemId: 'item-1',
        type: 'ITEM_LOGIN_REQUIRED',
        message: 'Your bank connection needs re-authentication',
        priority: 'high'
      });

      expect(result).toEqual({ success: true, data: { id: 1 } });
      expect(mockSupabase.from).toHaveBeenCalledWith('notifications');
      expect(mockInsert).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-1',
          item_id: 'item-1',
          type: 'ITEM_LOGIN_REQUIRED',
          message: 'Your bank connection needs re-authentication',
          priority: 'high',
          read: false
        })
      );
    });

    it('defaults priority to medium', async () => {
      mockInsert.mockResolvedValue({ data: {}, error: null });

      await plaidDataService.createNotification({
        userId: 'user-1',
        itemId: 'item-1',
        type: 'INFO',
        message: 'Test'
      });

      expect(mockInsert).toHaveBeenCalledWith(
        expect.objectContaining({ priority: 'medium' })
      );
    });

    it('returns { success: false } on database error', async () => {
      mockInsert.mockResolvedValue({ data: null, error: { message: 'Insert failed' } });

      const result = await plaidDataService.createNotification({
        userId: 'user-1',
        itemId: 'item-1',
        type: 'ERROR',
        message: 'Test'
      });

      expect(result).toEqual({ success: false, error: 'Database error: Insert failed' });
    });
  });
});

// ============================================================
// Mock mode tests (no Supabase configured)
// ============================================================
describe('PlaidDataService (mock mode)', () => {
  let mockService;

  beforeEach(() => {
    // Use isolateModules to re-require with no Supabase env vars
    jest.isolateModules(() => {
      delete process.env.SUPABASE_URL;
      delete process.env.SUPABASE_SERVICE_KEY;
      mockService = require('../../services/plaidDataService');
    });
    // Restore env vars for other tests
    process.env.SUPABASE_URL = 'https://test.supabase.co';
    process.env.SUPABASE_SERVICE_KEY = 'test-service-key';
  });

  it('mockUpsertItem stores in memory Map', async () => {
    const result = await mockService.upsertPlaidItem({
      itemId: 'mock-item-1',
      userId: 'user-1',
      accessToken: 'access-mock',
      status: 'active'
    });

    expect(result).toMatchObject({ success: true, mock: true });
  });

  it('mockStoreTransactions stores transactions', async () => {
    const result = await mockService.storeTransactions({
      itemId: 'mock-item-1',
      transactions: [
        { transaction_id: 'tx-mock-1' },
        { transaction_id: 'tx-mock-2' }
      ],
      userId: 'user-1'
    });

    expect(result).toMatchObject({ success: true, mock: true, count: 2 });
  });

  it('mockGetItem returns stored item', async () => {
    await mockService.upsertPlaidItem({
      itemId: 'mock-item-2',
      userId: 'user-1',
      accessToken: 'tok'
    });

    const result = await mockService.getItem('mock-item-2');

    expect(result).toMatchObject({ success: true, mock: true });
    expect(result.data.itemId).toBe('mock-item-2');
  });

  it('mockGetItem returns failure for missing item', async () => {
    const result = await mockService.getItem('nonexistent');

    expect(result).toEqual({ success: false, error: 'Item not found' });
  });

  it('mockRemoveTransactions removes by ID', async () => {
    await mockService.storeTransactions({
      itemId: 'item-1',
      transactions: [{ transaction_id: 'tx-rm-1' }],
      userId: 'user-1'
    });

    const result = await mockService.removeTransactions({
      transactionIds: ['tx-rm-1']
    });

    expect(result).toMatchObject({ success: true, mock: true, count: 1 });
  });

  it('mockUpdateItemStatus updates stored item', async () => {
    await mockService.upsertPlaidItem({
      itemId: 'mock-item-3',
      userId: 'user-1',
      accessToken: 'tok',
      status: 'active'
    });

    const result = await mockService.updateItemStatus({
      itemId: 'mock-item-3',
      status: 'error'
    });

    expect(result).toMatchObject({ success: true, mock: true });
  });

  it('mockUpsertAccounts stores account records', async () => {
    const result = await mockService.upsertAccounts({
      itemId: 'item-1',
      accounts: [{ account_id: 'acc-mock-1' }],
      userId: 'user-1'
    });

    expect(result).toMatchObject({ success: true, mock: true, count: 1 });
  });

  it('createNotification returns mock result without Supabase', async () => {
    const result = await mockService.createNotification({
      userId: 'user-1',
      itemId: 'item-1',
      type: 'INFO',
      message: 'Test notification'
    });

    expect(result).toMatchObject({ success: true, mock: true });
  });
});
