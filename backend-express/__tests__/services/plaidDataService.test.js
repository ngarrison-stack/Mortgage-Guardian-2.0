/**
 * Unit tests for PlaidDataService (services/plaidDataService.js)
 *
 * Tests both DB-backed mode and in-memory mock mode.
 * DB mock uses jest.mock for the db module.
 */

const mockQuery = jest.fn();
const mockClientQuery = jest.fn();
const mockClientRelease = jest.fn();
const mockConnect = jest.fn().mockResolvedValue({
  query: mockClientQuery,
  release: mockClientRelease
});

jest.mock('../../services/db', () => ({
  query: mockQuery,
  pool: { connect: mockConnect }
}));

// Also mock ../db for the lazy require('../db') in plaidDataService
jest.mock('../../db', () => ({
  query: mockQuery,
  pool: { connect: mockConnect }
}), { virtual: true });

// Set env vars BEFORE requiring service
process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';

const plaidDataService = require('../../services/plaidDataService');

// ============================================================
// DB mode tests
// ============================================================
describe('PlaidDataService (DB mode)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockClientQuery.mockResolvedValue({ rows: [], rowCount: 0 });
  });

  describe('upsertPlaidItem', () => {
    it('upserts item data to plaid_items table', async () => {
      mockQuery.mockResolvedValue({ rows: [{ item_id: 'item-1' }], rowCount: 1 });

      const result = await plaidDataService.upsertPlaidItem({
        itemId: 'item-1', userId: 'user-1', accessToken: 'access-token-1', status: 'active', institutionId: 'ins_123'
      });

      expect(result).toEqual({ success: true, data: { item_id: 'item-1' } });
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO plaid_items'),
        expect.arrayContaining(['item-1', 'user-1', 'access-token-1', 'active', 'ins_123'])
      );
    });

    it('returns { success: false } on database error', async () => {
      mockQuery.mockRejectedValue(new Error('DB error'));

      const result = await plaidDataService.upsertPlaidItem({
        itemId: 'item-err', userId: 'user-1', accessToken: 'tok'
      });

      expect(result).toEqual({ success: false, error: expect.stringContaining('DB error') });
    });
  });

  describe('storeTransactions', () => {
    const transactions = [{
      transaction_id: 'tx-1', account_id: 'acc-1', amount: 25.50, iso_currency_code: 'USD',
      category: ['Food', 'Restaurants'], category_id: '13005000', transaction_type: 'place',
      name: 'Burger Joint', merchant_name: 'Burger Joint', date: '2026-01-15',
      payment_channel: 'in store', location: { city: 'Portland' },
      payment_meta: { reference_number: 'REF123' }, pending: false
    }];

    it('bulk upserts transactions to plaid_transactions table', async () => {
      const result = await plaidDataService.storeTransactions({
        itemId: 'item-1', transactions, userId: 'user-1'
      });

      expect(result).toEqual({ success: true, count: 1 });
      // Verify pool.connect was used for transaction
      expect(mockConnect).toHaveBeenCalled();
      expect(mockClientQuery).toHaveBeenCalledWith('BEGIN');
      expect(mockClientQuery).toHaveBeenCalledWith('COMMIT');
      expect(mockClientRelease).toHaveBeenCalled();
    });

    it('returns { success: false } on database error', async () => {
      mockClientQuery.mockRejectedValueOnce(new Error('Insert failed'));

      const result = await plaidDataService.storeTransactions({
        itemId: 'item-1', transactions, userId: 'user-1'
      });

      expect(result).toEqual({ success: false, error: expect.stringContaining('Insert failed') });
    });
  });

  describe('getItem', () => {
    it('returns item data by item_id', async () => {
      const itemData = { item_id: 'item-1', status: 'active' };
      mockQuery.mockResolvedValue({ rows: [itemData], rowCount: 1 });

      const result = await plaidDataService.getItem('item-1');

      expect(result).toEqual({ success: true, data: itemData });
      expect(mockQuery).toHaveBeenCalledWith(
        expect.stringContaining('plaid_items'),
        expect.arrayContaining(['item-1'])
      );
    });

    it('returns { success: false } on database error', async () => {
      mockQuery.mockRejectedValue(new Error('Not found'));

      const result = await plaidDataService.getItem('item-missing');

      expect(result).toEqual({ success: false, error: expect.stringContaining('Not found') });
    });
  });
});

// ============================================================
// Mock mode tests (no DATABASE_URL configured)
// ============================================================
describe('PlaidDataService (mock mode)', () => {
  let mockService;

  beforeEach(() => {
    // Save and delete DATABASE_URL so the service uses mock mode
    // The service checks process.env.DATABASE_URL at call time
    delete process.env.DATABASE_URL;
    jest.isolateModules(() => {
      mockService = require('../../services/plaidDataService');
    });
  });

  afterEach(() => {
    // Restore DATABASE_URL for other test suites
    process.env.DATABASE_URL = 'postgresql://test:test@localhost/test';
  });

  it('mockUpsertItem stores in memory Map', async () => {
    const result = await mockService.upsertPlaidItem({
      itemId: 'mock-item-1', userId: 'user-1', accessToken: 'access-mock', status: 'active'
    });
    expect(result).toMatchObject({ success: true, mock: true });
  });

  it('mockStoreTransactions stores transactions', async () => {
    const result = await mockService.storeTransactions({
      itemId: 'mock-item-1', transactions: [{ transaction_id: 'tx-mock-1' }, { transaction_id: 'tx-mock-2' }], userId: 'user-1'
    });
    expect(result).toMatchObject({ success: true, mock: true, count: 2 });
  });

  it('mockGetItem returns stored item', async () => {
    await mockService.upsertPlaidItem({ itemId: 'mock-item-2', userId: 'user-1', accessToken: 'tok' });
    const result = await mockService.getItem('mock-item-2');
    expect(result).toMatchObject({ success: true, mock: true });
    expect(result.data.itemId).toBe('mock-item-2');
  });

  it('mockGetItem returns failure for missing item', async () => {
    const result = await mockService.getItem('nonexistent');
    expect(result).toEqual({ success: false, error: 'Item not found' });
  });

  it('mockRemoveTransactions removes by ID', async () => {
    await mockService.storeTransactions({ itemId: 'item-1', transactions: [{ transaction_id: 'tx-rm-1' }], userId: 'user-1' });
    const result = await mockService.removeTransactions({ transactionIds: ['tx-rm-1'] });
    expect(result).toMatchObject({ success: true, mock: true, count: 1 });
  });

  it('mockUpdateItemStatus updates stored item', async () => {
    await mockService.upsertPlaidItem({ itemId: 'mock-item-3', userId: 'user-1', accessToken: 'tok', status: 'active' });
    const result = await mockService.updateItemStatus({ itemId: 'mock-item-3', status: 'error' });
    expect(result).toMatchObject({ success: true, mock: true });
  });

  it('mockUpsertAccounts stores account records', async () => {
    const result = await mockService.upsertAccounts({ itemId: 'item-1', accounts: [{ account_id: 'acc-mock-1' }], userId: 'user-1' });
    expect(result).toMatchObject({ success: true, mock: true, count: 1 });
  });

  it('createNotification returns mock result without DB', async () => {
    const result = await mockService.createNotification({ userId: 'user-1', itemId: 'item-1', type: 'INFO', message: 'Test notification' });
    expect(result).toMatchObject({ success: true, mock: true });
  });
});
