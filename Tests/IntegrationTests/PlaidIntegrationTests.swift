import XCTest
import Combine
@testable import MortgageGuardian

/// Integration tests for Plaid service integration with document analysis
/// Tests the complete flow from bank data to audit findings
final class PlaidIntegrationTests: MortgageGuardianIntegrationTestCase {

    private var plaidService: MockPlaidService!
    private var auditEngine: MockAuditEngine!
    private var aiAnalysisService: MockAIAnalysisService!
    private var testUser: User!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        setupServices()
        setupTestData()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        plaidService = nil
        auditEngine = nil
        aiAnalysisService = nil
        testUser = nil
        cancellables = nil
        super.tearDown()
    }

    private func setupServices() {
        plaidService = MockPlaidService()
        auditEngine = MockAuditEngine()
        aiAnalysisService = MockAIAnalysisService()
    }

    private func setupTestData() {
        testUser = MockUsers.standardUser
    }

    // MARK: - Plaid Linking Integration Tests

    func testPlaidLinking_CompleteFlow() async throws {
        // Given
        plaidService.shouldFailLinking = false
        plaidService.mockAccounts = [
            PlaidAccount(id: "checking_123", name: "Primary Checking", type: "depository", subtype: "checking", balance: 5000.0),
            PlaidAccount(id: "savings_456", name: "Savings Account", type: "depository", subtype: "savings", balance: 15000.0)
        ]

        // When - Complete linking flow
        try await plaidService.initializeLinkToken()
        XCTAssertNotNil(plaidService.linkToken)

        try await plaidService.handleLinkSuccess(
            publicToken: "public-test-token",
            metadata: ["institution": ["name": "Test Bank"]]
        )

        let accounts = try await plaidService.fetchAccounts()

        // Then
        XCTAssertTrue(plaidService.isLinked)
        XCTAssertEqual(accounts.count, 2)
        XCTAssertEqual(accounts[0].name, "Primary Checking")
        XCTAssertEqual(accounts[1].name, "Savings Account")
    }

    func testPlaidLinking_FailureRecovery() async throws {
        // Given
        plaidService.shouldFailLinking = true

        // When - Initial failure
        do {
            try await plaidService.initializeLinkToken()
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }

        // Simulate service recovery
        plaidService.shouldFailLinking = false

        // Retry should succeed
        try await plaidService.initializeLinkToken()
        try await plaidService.handleLinkSuccess(
            publicToken: "public-test-token",
            metadata: [:]
        )

        // Then
        XCTAssertTrue(plaidService.isLinked)
        XCTAssertNotNil(plaidService.linkToken)
    }

    // MARK: - Transaction Fetching Integration Tests

    func testTransactionFetching_WithMortgagePayments() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.mockAccounts = [
            PlaidAccount(id: "checking_123", name: "Primary Checking", type: "depository", subtype: "checking", balance: 5000.0)
        ]

        // Mock transactions with mortgage payments
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN001",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 11, day: 1),
                description: "MORTGAGE PAYMENT - EXAMPLE CORP",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN002",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 10, day: 1),
                description: "AUTOMATIC PAYMENT - MORTGAGE",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN003",
                accountId: "checking_123",
                amount: -2500.00,
                date: Date.testDate(year: 2024, month: 10, day: 15),
                description: "RENT PAYMENT",
                category: "Transfer",
                merchantName: "Property Management",
                relatedMortgagePayment: false
            )
        ]

        // When
        let accounts = try await plaidService.fetchAccounts()
        let transactions = try await plaidService.fetchTransactions(
            accountIds: accounts.map { $0.id },
            startDate: Date.testDate(year: 2024, month: 1, day: 1),
            endDate: Date.testDate(year: 2024, month: 12, day: 31)
        )

        // Filter mortgage-related transactions
        let mortgageTransactions = transactions.filter { $0.relatedMortgagePayment }

        // Then
        XCTAssertEqual(transactions.count, 3)
        XCTAssertEqual(mortgageTransactions.count, 2)

        for transaction in mortgageTransactions {
            XCTAssertEqual(transaction.amount, -1725.45) // Expected payment amount
            XCTAssertTrue(transaction.description.lowercased().contains("mortgage"))
        }
    }

    func testTransactionFetching_DateRangeFiltering() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 5, day: 1),
                description: "MORTGAGE MAY",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN2",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 6, day: 1),
                description: "MORTGAGE JUNE",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN3",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 7, day: 1),
                description: "MORTGAGE JULY",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        // When - Fetch transactions for June only
        let transactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 6, day: 1),
            endDate: Date.testDate(year: 2024, month: 6, day: 30)
        )

        // Then
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.id, "TXN2")
        XCTAssertTrue(transactions.first?.description.contains("JUNE") ?? false)
    }

    // MARK: - Plaid Data Integration with Analysis Tests

    func testPlaidIntegration_WithDocumentAnalysis() async throws {
        // Given
        let testDocument = MockDocuments.mortgageStatement
        plaidService.isLinked = true
        plaidService.mockTransactions = MockTransactions.mortgagePayments

        auditEngine.mockResults = [MockAuditResults.latePaymentError]
        aiAnalysisService.mockResults = [MockAuditResults.misappliedPayment]

        // When
        let bankTransactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 1, day: 1),
            endDate: Date.testDate(year: 2024, month: 12, day: 31)
        )

        let auditResults = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        let aiResults = try await aiAnalysisService.analyzeDocument(
            testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertNotEmpty(bankTransactions)
        XCTAssertNotEmpty(auditResults)
        XCTAssertNotEmpty(aiResults.findings)

        // Bank transactions should enhance analysis accuracy
        XCTAssertTrue(bankTransactions.allSatisfy { $0.relatedMortgagePayment })
    }

    func testPlaidIntegration_PaymentTimingAnalysis() async throws {
        // Given - Transactions showing late payment pattern
        plaidService.isLinked = true
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 1, day: 1), // On time
                description: "MORTGAGE JAN",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN2",
                accountId: "checking_123",
                amount: -1750.45, // Includes late fee
                date: Date.testDate(year: 2024, month: 2, day: 5), // 5 days late
                description: "MORTGAGE FEB + LATE FEE",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN3",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 3, day: 1), // On time again
                description: "MORTGAGE MAR",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        let testDocument = MockDocuments.paymentHistory
        auditEngine.mockResults = [MockAuditResults.latePaymentError]

        // When
        let bankTransactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 1, day: 1),
            endDate: Date.testDate(year: 2024, month: 3, day: 31)
        )

        let auditResults = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertEqual(bankTransactions.count, 3)

        // Should identify the late payment
        let latePayment = bankTransactions.first { $0.amount == -1750.45 }
        XCTAssertNotNil(latePayment)
        XCTAssertTrue(latePayment?.description.contains("LATE FEE") ?? false)

        XCTAssertNotEmpty(auditResults)
        XCTAssertTrue(auditResults.contains { $0.issueType == .latePaymentError })
    }

    func testPlaidIntegration_PaymentAmountDiscrepancy() async throws {
        // Given - Bank transactions show different amounts than mortgage statement
        plaidService.isLinked = true
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -1725.45, // Correct amount
                date: Date.testDate(year: 2024, month: 10, day: 1),
                description: "MORTGAGE OCT",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN2",
                accountId: "checking_123",
                amount: -1625.45, // $100 less than expected
                date: Date.testDate(year: 2024, month: 11, day: 1),
                description: "MORTGAGE NOV",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        auditEngine.mockResults = [MockAuditResults.misappliedPayment]

        // When
        let bankTransactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 10, day: 1),
            endDate: Date.testDate(year: 2024, month: 11, day: 30)
        )

        let auditResults = try await auditEngine.performAudit(
            on: MockDocuments.mortgageStatement,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertEqual(bankTransactions.count, 2)

        // Should identify payment discrepancy
        let discrepantPayment = bankTransactions.first { $0.amount == -1625.45 }
        XCTAssertNotNil(discrepantPayment)

        XCTAssertNotEmpty(auditResults)
        XCTAssertTrue(auditResults.contains { $0.issueType == .misappliedPayment })
    }

    // MARK: - Error Handling Integration Tests

    func testPlaidIntegration_NetworkFailureRecovery() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.shouldFailTransactionFetch = true // Simulate network failure

        // When - First attempt fails
        do {
            _ = try await plaidService.fetchTransactions(
                accountIds: ["checking_123"],
                startDate: Date.testDate(year: 2024, month: 1, day: 1),
                endDate: Date.testDate(year: 2024, month: 12, day: 31)
            )
            XCTFail("Should have failed due to network error")
        } catch {
            // Expected failure
        }

        // Recovery - network comes back
        plaidService.shouldFailTransactionFetch = false
        plaidService.mockTransactions = MockTransactions.mortgagePayments

        let transactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 1, day: 1),
            endDate: Date.testDate(year: 2024, month: 12, day: 31)
        )

        // Then
        XCTAssertNotEmpty(transactions)
    }

    func testPlaidIntegration_AnalysisWithoutBankData() async throws {
        // Given - No bank data available
        plaidService.isLinked = false
        let emptyTransactions: [Transaction] = []

        auditEngine.mockResults = [MockAuditResults.latePaymentError]
        aiAnalysisService.mockResults = [MockAuditResults.incorrectInterest]

        // When - Perform analysis without bank data
        let auditResults = try await auditEngine.performAudit(
            on: MockDocuments.mortgageStatement,
            userContext: testUser,
            bankTransactions: emptyTransactions
        )

        let aiResults = try await aiAnalysisService.analyzeDocument(
            MockDocuments.mortgageStatement,
            userContext: testUser,
            bankTransactions: emptyTransactions
        )

        // Then - Analysis should still work, albeit with less verification
        XCTAssertNotEmpty(auditResults)
        XCTAssertNotEmpty(aiResults.findings)

        // Results might have lower confidence without bank verification
        for result in auditResults {
            XCTAssertGreaterThan(result.confidence, 0.0)
        }
    }

    // MARK: - Performance Integration Tests

    func testPlaidIntegration_PerformanceUnderLoad() async {
        // Given
        plaidService.isLinked = true
        plaidService.mockTransactions = Array(repeating: MockTransactions.mortgagePayments.first!, count: 100)

        let accountIds = ["checking_123"]
        let dateRanges = [
            (Date.testDate(year: 2024, month: 1, day: 1), Date.testDate(year: 2024, month: 3, day: 31)),
            (Date.testDate(year: 2024, month: 4, day: 1), Date.testDate(year: 2024, month: 6, day: 30)),
            (Date.testDate(year: 2024, month: 7, day: 1), Date.testDate(year: 2024, month: 9, day: 30)),
            (Date.testDate(year: 2024, month: 10, day: 1), Date.testDate(year: 2024, month: 12, day: 31))
        ]

        // When/Then
        await measureAsync {
            for (startDate, endDate) in dateRanges {
                try? await self.plaidService.fetchTransactions(
                    accountIds: accountIds,
                    startDate: startDate,
                    endDate: endDate
                )
            }
        }
    }

    func testPlaidIntegration_ConcurrentTransactionFetching() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.mockTransactions = MockTransactions.mortgagePayments

        let accountIds = ["checking_123", "savings_456", "credit_789"]
        let startDate = Date.testDate(year: 2024, month: 1, day: 1)
        let endDate = Date.testDate(year: 2024, month: 12, day: 31)

        // When - Fetch transactions for multiple accounts concurrently
        let results = try await withThrowingTaskGroup(of: [Transaction].self) { group in
            for accountId in accountIds {
                group.addTask {
                    try await self.plaidService.fetchTransactions(
                        accountIds: [accountId],
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }

            var allTransactions: [Transaction] = []
            for try await transactions in group {
                allTransactions.append(contentsOf: transactions)
            }
            return allTransactions
        }

        // Then
        XCTAssertNotEmpty(results)
        // Each account should return the same mock transactions filtered by account ID
    }

    // MARK: - Data Consistency Integration Tests

    func testPlaidIntegration_DataConsistencyAcrossServices() async throws {
        // Given
        plaidService.isLinked = true
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 11, day: 1),
                description: "MORTGAGE NOV",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        let testDocument = MockDocuments.mortgageStatement
        auditEngine.mockResults = []
        aiAnalysisService.mockResults = []

        // When
        let bankTransactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 11, day: 1),
            endDate: Date.testDate(year: 2024, month: 11, day: 30)
        )

        // Both services should use the same bank transaction data
        let auditResults = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        let aiResults = try await aiAnalysisService.analyzeDocument(
            testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertEqual(bankTransactions.count, 1)
        XCTAssertEqual(bankTransactions.first?.amount, -1725.45)

        // Both services should have access to the same transaction data
        XCTAssertNotNil(auditResults)
        XCTAssertNotNil(aiResults)
    }

    func testPlaidIntegration_AccountStateConsistency() async throws {
        // Given
        plaidService.shouldFailLinking = false

        // Monitor state changes
        var linkStates: [Bool] = []
        var accountStates: [[PlaidAccount]] = []

        plaidService.$isLinked
            .sink { isLinked in
                linkStates.append(isLinked)
            }
            .store(in: &cancellables)

        plaidService.$accounts
            .sink { accounts in
                accountStates.append(accounts)
            }
            .store(in: &cancellables)

        // When - Complete linking process
        try await plaidService.initializeLinkToken()
        try await plaidService.handleLinkSuccess(publicToken: "test", metadata: [:])
        let accounts = try await plaidService.fetchAccounts()

        // Small delay to capture all state changes
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        XCTAssertTrue(linkStates.contains(false)) // Initial state
        XCTAssertTrue(linkStates.contains(true)) // After linking

        XCTAssertTrue(accountStates.contains { $0.isEmpty }) // Initial empty state
        XCTAssertTrue(accountStates.contains { !$0.isEmpty }) // After fetch

        XCTAssertEqual(accounts.count, plaidService.accounts.count)
    }

    // MARK: - Real-World Scenario Integration Tests

    func testPlaidIntegration_MortgagePaymentVerification() async throws {
        // Given - Real-world scenario: verify mortgage payment was properly applied
        let expectedPaymentAmount = 1725.45
        let expectedPaymentDate = Date.testDate(year: 2024, month: 11, day: 1)

        plaidService.isLinked = true
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -expectedPaymentAmount,
                date: expectedPaymentDate,
                description: "ACH DEBIT EXAMPLE MORTGAGE CORP",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        let mortgageStatement = MockDocuments.mortgageStatement
        auditEngine.mockResults = [] // No issues if payment matches

        // When
        let bankTransactions = try await plaidService.fetchTransactions(
            accountIds: ["checking_123"],
            startDate: Date.testDate(year: 2024, month: 11, day: 1),
            endDate: Date.testDate(year: 2024, month: 11, day: 30)
        )

        let auditResults = try await auditEngine.performAudit(
            on: mortgageStatement,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertEqual(bankTransactions.count, 1)
        let payment = bankTransactions.first!
        XCTAssertEqual(payment.amount, -expectedPaymentAmount)
        XCTAssertEqual(payment.date, expectedPaymentDate)
        XCTAssertTrue(payment.relatedMortgagePayment)

        // No audit issues should be found for matching payment
        XCTAssertTrue(auditResults.isEmpty)
    }

    func testPlaidIntegration_MultipleAccountAnalysis() async throws {
        // Given - User has multiple bank accounts
        plaidService.isLinked = true
        plaidService.mockAccounts = [
            PlaidAccount(id: "checking_123", name: "Primary Checking", type: "depository", subtype: "checking", balance: 3000.0),
            PlaidAccount(id: "savings_456", name: "Savings", type: "depository", subtype: "savings", balance: 20000.0),
            PlaidAccount(id: "checking_789", name: "Joint Checking", type: "depository", subtype: "checking", balance: 1500.0)
        ]

        // Mortgage payments come from different accounts
        plaidService.mockTransactions = [
            Transaction(
                id: "TXN1",
                accountId: "checking_123",
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 10, day: 1),
                description: "MORTGAGE OCT",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            ),
            Transaction(
                id: "TXN2",
                accountId: "checking_789", // Different account
                amount: -1725.45,
                date: Date.testDate(year: 2024, month: 11, day: 1),
                description: "MORTGAGE NOV",
                category: "Payment",
                merchantName: "Example Mortgage Corp",
                relatedMortgagePayment: true
            )
        ]

        // When
        let accounts = try await plaidService.fetchAccounts()
        let allTransactions = try await plaidService.fetchTransactions(
            accountIds: accounts.map { $0.id },
            startDate: Date.testDate(year: 2024, month: 10, day: 1),
            endDate: Date.testDate(year: 2024, month: 11, day: 30)
        )

        let mortgageTransactions = allTransactions.filter { $0.relatedMortgagePayment }

        // Then
        XCTAssertEqual(accounts.count, 3)
        XCTAssertEqual(mortgageTransactions.count, 2)

        // Verify payments came from different accounts
        let accountIds = Set(mortgageTransactions.map { $0.accountId })
        XCTAssertEqual(accountIds.count, 2)
        XCTAssertTrue(accountIds.contains("checking_123"))
        XCTAssertTrue(accountIds.contains("checking_789"))
    }
}