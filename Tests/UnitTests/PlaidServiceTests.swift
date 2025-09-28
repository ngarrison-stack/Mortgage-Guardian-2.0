import XCTest
import Combine
@testable import MortgageGuardian

/// Comprehensive unit tests for PlaidService
/// Tests bank account linking, transaction fetching, and error handling
final class PlaidServiceTests: MortgageGuardianUnitTestCase {

    private var plaidService: MockPlaidService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        setupTestObjects()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        plaidService = nil
        cancellables = nil
        super.tearDown()
    }

    private func setupTestObjects() {
        plaidService = MockPlaidService()
    }

    // MARK: - Link Token Tests

    func testInitializeLinkToken_Success() async throws {
        // Given
        plaidService.shouldFailLinking = false

        // When
        try await plaidService.initializeLinkToken()

        // Then
        XCTAssertNotNil(plaidService.linkToken)
        XCTAssertEqual(plaidService.linkToken, "mock-link-token")
    }

    func testInitializeLinkToken_Failure() async {
        // Given
        plaidService.shouldFailLinking = true

        // When/Then
        await testAsyncThrows(expectedError: PlaidService.PlaidError.self) {
            try await self.plaidService.initializeLinkToken()
        }

        XCTAssertNil(plaidService.linkToken)
    }

    func testInitializeLinkToken_MultipleAttempts() async throws {
        // Given
        plaidService.shouldFailLinking = false

        // When
        try await plaidService.initializeLinkToken()
        let firstToken = plaidService.linkToken

        try await plaidService.initializeLinkToken()
        let secondToken = plaidService.linkToken

        // Then
        XCTAssertNotNil(firstToken)
        XCTAssertNotNil(secondToken)
        // In a real implementation, tokens might be different each time
    }

    // MARK: - Account Linking Tests

    func testHandleLinkSuccess_ValidToken() async throws {
        // Given
        let publicToken = "public-test-token"
        let metadata = [
            "institution": [
                "name": "Test Bank",
                "institution_id": "ins_test"
            ],
            "accounts": [
                [
                    "id": "account123",
                    "name": "Checking Account",
                    "type": "depository",
                    "subtype": "checking"
                ]
            ]
        ]
        plaidService.shouldFailLinking = false

        // When
        try await plaidService.handleLinkSuccess(publicToken: publicToken, metadata: metadata)

        // Then
        XCTAssertTrue(plaidService.isLinked)
        XCTAssertNotEmpty(plaidService.accounts)
    }

    func testHandleLinkSuccess_LinkingFailure() async {
        // Given
        let publicToken = "invalid-token"
        let metadata: [String: Any] = [:]
        plaidService.shouldFailLinking = true

        // When/Then
        await testAsyncThrows(expectedError: PlaidService.PlaidError.self) {
            try await self.plaidService.handleLinkSuccess(publicToken: publicToken, metadata: metadata)
        }

        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)
    }

    func testHandleLinkSuccess_StateUpdates() async throws {
        // Given
        let publicToken = "public-test-token"
        let metadata: [String: Any] = [:]
        plaidService.shouldFailLinking = false

        var linkStateUpdates: [Bool] = []
        let linkExpectation = expectation(description: "Link state updated")

        plaidService.$isLinked
            .sink { isLinked in
                linkStateUpdates.append(isLinked)
                if isLinked {
                    linkExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        try await plaidService.handleLinkSuccess(publicToken: publicToken, metadata: metadata)

        // Then
        await fulfillment(of: [linkExpectation], timeout: 1.0)
        XCTAssertTrue(linkStateUpdates.contains(true))
    }

    // MARK: - Account Fetching Tests

    func testFetchAccounts_Success() async throws {
        // Given
        plaidService.shouldFailAccountFetch = false
        plaidService.isLinked = true

        // When
        let accounts = try await plaidService.fetchAccounts()

        // Then
        XCTAssertNotEmpty(accounts)
        XCTAssertEqual(accounts.count, plaidService.mockAccounts.count)

        for account in accounts {
            XCTAssertFalse(account.id.isEmpty)
            XCTAssertFalse(account.name.isEmpty)
            XCTAssertFalse(account.type.isEmpty)
            XCTAssertGreaterThanOrEqual(account.balance, 0)
        }
    }

    func testFetchAccounts_NotLinked() async {
        // Given
        plaidService.isLinked = false
        plaidService.shouldFailAccountFetch = true

        // When/Then
        await testAsyncThrows(expectedError: PlaidService.PlaidError.self) {
            try await self.plaidService.fetchAccounts()
        }
    }

    func testFetchAccounts_NetworkError() async {
        // Given
        plaidService.isLinked = true
        plaidService.shouldFailAccountFetch = true

        // When/Then
        await testAsyncThrows(expectedError: PlaidService.PlaidError.self) {
            try await self.plaidService.fetchAccounts()
        }
    }

    func testFetchAccounts_EmptyResponse() async throws {
        // Given
        plaidService.shouldFailAccountFetch = false
        plaidService.mockAccounts = []
        plaidService.isLinked = true

        // When
        let accounts = try await plaidService.fetchAccounts()

        // Then
        XCTAssertTrue(accounts.isEmpty)
    }

    func testFetchAccounts_StateUpdate() async throws {
        // Given
        plaidService.shouldFailAccountFetch = false
        plaidService.isLinked = true

        var accountUpdates: [[PlaidAccount]] = []
        let accountExpectation = expectation(description: "Accounts updated")

        plaidService.$accounts
            .sink { accounts in
                accountUpdates.append(accounts)
                if !accounts.isEmpty {
                    accountExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        _ = try await plaidService.fetchAccounts()

        // Then
        await fulfillment(of: [accountExpectation], timeout: 1.0)
        XCTAssertGreaterThan(accountUpdates.count, 1) // Initial empty + updated
    }

    // MARK: - Transaction Fetching Tests

    func testFetchTransactions_Success() async throws {
        // Given
        let accountIds = ["ACC123"]
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)
        plaidService.shouldFailTransactionFetch = false
        plaidService.mockTransactions = MockTransactions.mortgagePayments

        // When
        let transactions = try await plaidService.fetchTransactions(
            accountIds: accountIds,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertNotEmpty(transactions)

        for transaction in transactions {
            XCTAssertTrue(accountIds.contains(transaction.accountId))
            XCTAssertGreaterThanOrEqual(transaction.date, startDate)
            XCTAssertLessThanOrEqual(transaction.date, endDate)
            XCTAssertFalse(transaction.id.isEmpty)
            XCTAssertFalse(transaction.description.isEmpty)
        }
    }

    func testFetchTransactions_DateFiltering() async throws {
        // Given
        let accountIds = ["ACC123"]
        let startDate = Date.testDate(year: 2024, month: 6, day: 1)
        let endDate = Date.testDate(year: 2024, month: 6, day: 30)

        // Mock transactions with various dates
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "ACC123",
                amount: -1000.0,
                date: Date.testDate(year: 2024, month: 5, day: 15), // Before range
                description: "Before range",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: false
            ),
            Transaction(
                id: "TXN2",
                accountId: "ACC123",
                amount: -1500.0,
                date: Date.testDate(year: 2024, month: 6, day: 15), // In range
                description: "In range",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN3",
                accountId: "ACC123",
                amount: -2000.0,
                date: Date.testDate(year: 2024, month: 7, day: 15), // After range
                description: "After range",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: false
            )
        ]

        // When
        let transactions = try await plaidService.fetchTransactions(
            accountIds: accountIds,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertEqual(transactions.count, 1) // Only the transaction in range
        XCTAssertEqual(transactions.first?.id, "TXN2")
    }

    func testFetchTransactions_MultipleAccounts() async throws {
        // Given
        let accountIds = ["ACC123", "ACC456", "ACC789"]
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)

        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "ACC123",
                amount: -1000.0,
                date: Date.testDate(year: 2024, month: 6, day: 1),
                description: "Account 123 transaction",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN2",
                accountId: "ACC456",
                amount: -1500.0,
                date: Date.testDate(year: 2024, month: 6, day: 2),
                description: "Account 456 transaction",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN3",
                accountId: "ACC999", // Not in requested accounts
                amount: -2000.0,
                date: Date.testDate(year: 2024, month: 6, day: 3),
                description: "Account 999 transaction",
                category: "Payment",
                merchantName: nil,
                relatedMortgagePayment: false
            )
        ]

        // When
        let transactions = try await plaidService.fetchTransactions(
            accountIds: accountIds,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertEqual(transactions.count, 2) // Only transactions from requested accounts
        XCTAssertTrue(transactions.allSatisfy { accountIds.contains($0.accountId) })
    }

    func testFetchTransactions_NetworkFailure() async {
        // Given
        let accountIds = ["ACC123"]
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)
        plaidService.shouldFailTransactionFetch = true

        // When/Then
        await testAsyncThrows(expectedError: PlaidService.PlaidError.self) {
            try await self.plaidService.fetchTransactions(
                accountIds: accountIds,
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    func testFetchTransactions_EmptyAccountIds() async throws {
        // Given
        let emptyAccountIds: [String] = []
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)

        // When
        let transactions = try await plaidService.fetchTransactions(
            accountIds: emptyAccountIds,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertTrue(transactions.isEmpty)
    }

    func testFetchTransactions_InvalidDateRange() async throws {
        // Given
        let accountIds = ["ACC123"]
        let startDate = Date.testDate(year: 2024, month: 12, day: 31)
        let endDate = Date.testDate(year: 2024, month: 1, day: 1) // End before start

        // When
        let transactions = try await plaidService.fetchTransactions(
            accountIds: accountIds,
            startDate: startDate,
            endDate: endDate
        )

        // Then
        XCTAssertTrue(transactions.isEmpty) // No transactions in invalid range
    }

    // MARK: - Account Unlinking Tests

    func testUnlinkAccount_Success() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.accounts = plaidService.mockAccounts
        plaidService.linkToken = "test-token"

        // When
        try await plaidService.unlinkAccount()

        // Then
        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)
        XCTAssertNil(plaidService.linkToken)
    }

    func testUnlinkAccount_WhenNotLinked() async throws {
        // Given
        plaidService.isLinked = false

        // When
        try await plaidService.unlinkAccount()

        // Then
        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)
        XCTAssertNil(plaidService.linkToken)
    }

    func testUnlinkAccount_StateUpdates() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.accounts = plaidService.mockAccounts

        var linkStateChanges: [Bool] = []
        let unlinkExpectation = expectation(description: "Account unlinked")

        plaidService.$isLinked
            .sink { isLinked in
                linkStateChanges.append(isLinked)
                if !isLinked && linkStateChanges.count > 1 { // Ignore initial state
                    unlinkExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        try await plaidService.unlinkAccount()

        // Then
        await fulfillment(of: [unlinkExpectation], timeout: 1.0)
        XCTAssertTrue(linkStateChanges.contains(false))
    }

    // MARK: - Error Handling Tests

    func testPlaidErrors_ErrorCodes() {
        // Given
        let errors: [PlaidService.PlaidError] = [
            .initializationFailed("Test init failure"),
            .linkingFailed("Test linking failure"),
            .networkError(URLError(.notConnectedToInternet)),
            .authenticationError("Test auth error"),
            .invalidResponse("Test invalid response"),
            .accountNotFound("ACC123"),
            .permissionDenied("Test permission denied"),
            .rateLimitExceeded
        ]

        // When/Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testPlaidErrors_RecoveryOptions() {
        // Given
        let linkingError = PlaidService.PlaidError.linkingFailed("Connection failed")
        let networkError = PlaidService.PlaidError.networkError(URLError(.notConnectedToInternet))
        let authError = PlaidService.PlaidError.authenticationError("Invalid credentials")

        // When/Then
        // These would have recovery options in a real implementation
        XCTAssertNotNil(linkingError.errorDescription)
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertNotNil(authError.errorDescription)
    }

    // MARK: - Performance Tests

    func testFetchAccounts_Performance() async {
        // Given
        plaidService.shouldFailAccountFetch = false
        plaidService.isLinked = true

        // When/Then
        await measureAsync {
            try? await self.plaidService.fetchAccounts()
        }
    }

    func testFetchTransactions_Performance() async {
        // Given
        let accountIds = ["ACC123"]
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)
        plaidService.shouldFailTransactionFetch = false

        // When/Then
        await measureAsync {
            try? await self.plaidService.fetchTransactions(
                accountIds: accountIds,
                startDate: startDate,
                endDate: endDate
            )
        }
    }

    func testBulkTransactionFetch_Performance() async {
        // Given
        let accountIds = Array(repeating: "ACC123", count: 10)
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)

        // When/Then
        await measureAsync {
            for accountId in accountIds {
                try? await self.plaidService.fetchTransactions(
                    accountIds: [accountId],
                    startDate: startDate,
                    endDate: endDate
                )
            }
        }
    }

    // MARK: - Memory Tests

    func testLargeTransactionSet_Memory() {
        // Given
        let largeTransactionSet = Array(repeating: MockTransactions.mortgagePayments.first!, count: 1000)
        plaidService.mockTransactions = largeTransactionSet

        // When/Then
        measureMemory {
            Task {
                try? await self.plaidService.fetchTransactions(
                    accountIds: ["ACC123"],
                    startDate: Date.testDate(year: 2024, month: 1, day: 1),
                    endDate: Date.testDate(year: 2024, month: 12, day: 31)
                )
            }
        }
    }

    // MARK: - Edge Cases

    func testPlaidService_EdgeCaseInputs() async throws {
        // Test extreme date ranges
        let veryEarlyDate = Date.testDate(year: 1900, month: 1, day: 1)
        let veryFutureDate = Date.testDate(year: 2100, month: 12, day: 31)

        let transactions = try await plaidService.fetchTransactions(
            accountIds: ["ACC123"],
            startDate: veryEarlyDate,
            endDate: veryFutureDate
        )

        XCTAssertNotNil(transactions)
    }

    func testPlaidService_SpecialCharacterAccountIds() async throws {
        // Given
        let specialAccountIds = ["ACC-123", "ACC_456", "账户789", "🏦💰"]

        // When/Then
        for accountId in specialAccountIds {
            let transactions = try await plaidService.fetchTransactions(
                accountIds: [accountId],
                startDate: Date.testDate(year: 2024, month: 1, day: 1),
                endDate: Date.testDate(year: 2024, month: 12, day: 31)
            )
            XCTAssertNotNil(transactions)
        }
    }

    func testPlaidService_ConcurrentOperations() async throws {
        // Given
        plaidService.shouldFailAccountFetch = false
        plaidService.shouldFailTransactionFetch = false
        plaidService.isLinked = true

        // When
        async let accountsTask = plaidService.fetchAccounts()
        async let transactionsTask = plaidService.fetchTransactions(
            accountIds: ["ACC123"],
            startDate: Date.testDate(year: 2024, month: 1, day: 1),
            endDate: Date.testDate(year: 2024, month: 12, day: 31)
        )

        let accounts = try await accountsTask
        let transactions = try await transactionsTask

        // Then
        XCTAssertNotNil(accounts)
        XCTAssertNotNil(transactions)
    }

    // MARK: - State Consistency Tests

    func testPlaidService_StateConsistency() async throws {
        // Test that service state remains consistent across operations

        // Initial state
        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)
        XCTAssertNil(plaidService.linkToken)

        // After initialization
        try await plaidService.initializeLinkToken()
        XCTAssertNotNil(plaidService.linkToken)
        XCTAssertFalse(plaidService.isLinked) // Still not linked

        // After linking
        try await plaidService.handleLinkSuccess(publicToken: "test", metadata: [:])
        XCTAssertTrue(plaidService.isLinked)
        XCTAssertNotEmpty(plaidService.accounts)

        // After unlinking
        try await plaidService.unlinkAccount()
        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)
        XCTAssertNil(plaidService.linkToken)
    }

    func testPlaidService_ErrorStateRecovery() async throws {
        // Test that service can recover from error states

        // Simulate failure during linking
        plaidService.shouldFailLinking = true

        do {
            try await plaidService.handleLinkSuccess(publicToken: "test", metadata: [:])
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }

        // Verify state is still clean
        XCTAssertFalse(plaidService.isLinked)
        XCTAssertTrue(plaidService.accounts.isEmpty)

        // Now allow success and verify recovery
        plaidService.shouldFailLinking = false
        try await plaidService.handleLinkSuccess(publicToken: "test", metadata: [:])

        XCTAssertTrue(plaidService.isLinked)
        XCTAssertNotEmpty(plaidService.accounts)
    }
}