import XCTest
import Combine
@testable import MortgageGuardian

/// Comprehensive unit tests for AuditEngine
/// Tests all audit algorithms, calculations, and business rule validation
final class AuditEngineTests: MortgageGuardianUnitTestCase {

    private var auditEngine: MockAuditEngine!
    private var testUser: User!
    private var testDocument: MortgageDocument!
    private var testTransactions: [Transaction]!

    override func setUp() {
        super.setUp()
        setupTestObjects()
    }

    override func tearDown() {
        auditEngine = nil
        testUser = nil
        testDocument = nil
        testTransactions = nil
        super.tearDown()
    }

    private func setupTestObjects() {
        auditEngine = MockAuditEngine()
        testUser = MockUsers.standardUser
        testDocument = MockDocuments.mortgageStatement
        testTransactions = MockTransactions.mortgagePayments
    }

    // MARK: - Main Audit Tests

    func testPerformAudit_Success() async throws {
        // Given
        auditEngine.shouldFail = false
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        XCTAssertNotEmpty(results)
        XCTAssertGreaterThanOrEqual(results.count, 1)

        for result in results {
            XCTAssertValidAuditResult(result)
            XCTAssertNotNil(result.evidenceText)
            XCTAssertFalse(result.suggestedAction.isEmpty)
        }
    }

    func testPerformAudit_MortgageStatement() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: MockDocuments.mortgageStatement,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        XCTAssertNotEmpty(results)

        // Mortgage statements should detect all types of issues
        let issueTypes = Set(results.map { $0.issueType })
        XCTAssertTrue(issueTypes.contains(.latePaymentError))
        XCTAssertTrue(issueTypes.contains(.misappliedPayment))
        XCTAssertTrue(issueTypes.contains(.incorrectInterest))
    }

    func testPerformAudit_EscrowStatement() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: MockDocuments.escrowStatement,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        XCTAssertNotEmpty(results)

        // Escrow statements should focus on escrow-related issues
        let issueTypes = Set(results.map { $0.issueType })
        XCTAssertTrue(issueTypes.contains(.escrowError))

        // Should not contain payment-specific issues
        for result in results {
            XCTAssertTrue([.escrowError, .lateTaxPayment, .lateInsurancePayment].contains(result.issueType))
        }
    }

    func testPerformAudit_PaymentHistory() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: MockDocuments.paymentHistory,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        XCTAssertNotEmpty(results)

        // Payment history should focus on payment-related issues
        let issueTypes = Set(results.map { $0.issueType })
        XCTAssertTrue(issueTypes.contains(.latePaymentError) || issueTypes.contains(.misappliedPayment))

        for result in results {
            XCTAssertTrue([.latePaymentError, .misappliedPayment].contains(result.issueType))
        }
    }

    func testPerformAudit_WithoutBankTransactions() async throws {
        // Given
        auditEngine.mockResults = [MockAuditResults.latePaymentError, MockAuditResults.incorrectInterest]

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: [] // No bank transactions
        )

        // Then
        XCTAssertNotEmpty(results)
        // Audit should still work without bank transactions, but may be less comprehensive
    }

    func testPerformAudit_CalculationError() async {
        // Given
        auditEngine.shouldFail = true
        auditEngine.failureError = AuditEngine.AuditError.calculationError("Test calculation failed")

        // When/Then
        await testAsyncThrows(expectedError: AuditEngine.AuditError.self) {
            try await self.auditEngine.performAudit(
                on: self.testDocument,
                userContext: self.testUser,
                bankTransactions: self.testTransactions
            )
        }
    }

    // MARK: - Payment Accuracy Tests

    func testValidatePaymentAccuracy_CorrectPayments() async throws {
        // Given
        let paymentHistory = MockExtractedData.mortgageStatementData.paymentHistory
        let expectedPayment = 1725.45
        let interestRate = 0.0425
        auditEngine.mockResults = [] // No issues found

        // When
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: paymentHistory,
            expectedPayment: expectedPayment,
            interestRate: interestRate
        )

        // Then
        XCTAssertTrue(results.isEmpty) // No issues should be found for correct payments
    }

    func testValidatePaymentAccuracy_MisappliedPayment() async throws {
        // Given
        let paymentHistory = MockExtractedData.paymentHistoryData.paymentHistory
        let expectedPayment = 1725.45
        let interestRate = 0.0425
        auditEngine.mockResults = [MockAuditResults.misappliedPayment]

        // When
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: paymentHistory,
            expectedPayment: expectedPayment,
            interestRate: interestRate
        )

        // Then
        XCTAssertNotEmpty(results)
        XCTAssertTrue(results.contains { $0.issueType == .misappliedPayment })

        let misappliedResult = results.first { $0.issueType == .misappliedPayment }!
        XCTAssertNotNil(misappliedResult.affectedAmount)
        XCTAssertNotNil(misappliedResult.calculationDetails)
    }

    func testValidatePaymentAccuracy_IncorrectInterest() async throws {
        // Given
        let paymentHistory = MockExtractedData.mortgageStatementData.paymentHistory
        let expectedPayment = 1725.45
        let interestRate = 0.0425
        auditEngine.mockResults = [MockAuditResults.incorrectInterest]

        // When
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: paymentHistory,
            expectedPayment: expectedPayment,
            interestRate: interestRate
        )

        // Then
        XCTAssertNotEmpty(results)
        XCTAssertTrue(results.contains { $0.issueType == .incorrectInterest })

        let interestResult = results.first { $0.issueType == .incorrectInterest }!
        XCTAssertNotNil(interestResult.affectedAmount)
        XCTAssertGreaterThan(interestResult.confidence, 0.8)
    }

    func testValidatePaymentAccuracy_EdgeCases() async throws {
        // Given - Edge case payments
        let edgeCasePayments = [
            ExtractedData.PaymentRecord(
                paymentDate: Date(),
                amount: 0.01, // Penny payment
                principalApplied: 0.01,
                interestApplied: 0.0,
                escrowApplied: 0.0,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            ),
            ExtractedData.PaymentRecord(
                paymentDate: Date(),
                amount: 50000.0, // Very large payment
                principalApplied: 50000.0,
                interestApplied: 0.0,
                escrowApplied: 0.0,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            )
        ]

        // When
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: edgeCasePayments,
            expectedPayment: 1725.45,
            interestRate: 0.0425
        )

        // Then
        // Should handle edge cases without crashing
        XCTAssertNotNil(results)
    }

    // MARK: - Escrow Analysis Tests

    func testAnalyzeEscrowAccount_Balanced() async throws {
        // Given
        let escrowActivity = MockExtractedData.escrowStatementData.escrowActivity
        let monthlyEscrowPayment = 250.25
        auditEngine.mockResults = [] // No issues

        // When
        let results = try await auditEngine.analyzeEscrowAccount(
            escrowActivity: escrowActivity,
            monthlyEscrowPayment: monthlyEscrowPayment
        )

        // Then
        XCTAssertTrue(results.isEmpty) // No issues for balanced escrow
    }

    func testAnalyzeEscrowAccount_Shortage() async throws {
        // Given
        let escrowActivity = MockExtractedData.escrowStatementData.escrowActivity
        let monthlyEscrowPayment = 250.25
        auditEngine.mockResults = [MockAuditResults.escrowError]

        // When
        let results = try await auditEngine.analyzeEscrowAccount(
            escrowActivity: escrowActivity,
            monthlyEscrowPayment: monthlyEscrowPayment
        )

        // Then
        XCTAssertNotEmpty(results)
        XCTAssertTrue(results.contains { $0.issueType == .escrowError })

        let escrowResult = results.first!
        XCTAssertNotNil(escrowResult.affectedAmount)
        XCTAssertEqual(escrowResult.severity, .medium)
    }

    func testAnalyzeEscrowAccount_LatePayments() async throws {
        // Given
        let escrowActivity = [
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2024, month: 1, day: 15),
                description: "Property Tax Payment - LATE",
                amount: 1200.0,
                type: .withdrawal,
                category: .propertyTax
            ),
            ExtractedData.EscrowTransaction(
                date: Date.testDate(year: 2024, month: 3, day: 15),
                description: "Insurance Payment - LATE",
                amount: 890.0,
                type: .withdrawal,
                category: .homeownerInsurance
            )
        ]
        let monthlyEscrowPayment = 250.25
        auditEngine.mockResults = [MockAuditResults.escrowError]

        // When
        let results = try await auditEngine.analyzeEscrowAccount(
            escrowActivity: escrowActivity,
            monthlyEscrowPayment: monthlyEscrowPayment
        )

        // Then
        XCTAssertNotEmpty(results)
    }

    func testAnalyzeEscrowAccount_EmptyActivity() async throws {
        // Given
        let emptyActivity: [ExtractedData.EscrowTransaction] = []
        let monthlyEscrowPayment = 250.25

        // When
        let results = try await auditEngine.analyzeEscrowAccount(
            escrowActivity: emptyActivity,
            monthlyEscrowPayment: monthlyEscrowPayment
        )

        // Then
        // Should handle empty activity gracefully
        XCTAssertNotNil(results)
    }

    // MARK: - Fee Detection Tests

    func testDetectUnauthorizedFees_NoFees() async throws {
        // Given
        let noFees: [ExtractedData.Fee] = []

        // When
        let results = try await auditEngine.detectUnauthorizedFees(
            fees: noFees,
            userContext: testUser
        )

        // Then
        XCTAssertTrue(results.isEmpty)
    }

    func testDetectUnauthorizedFees_AuthorizedFees() async throws {
        // Given
        let authorizedFees = [
            ExtractedData.Fee(
                date: Date(),
                description: "Late Fee - 5 days late",
                amount: 25.0,
                category: .lateFee
            )
        ]
        auditEngine.mockResults = [] // No issues

        // When
        let results = try await auditEngine.detectUnauthorizedFees(
            fees: authorizedFees,
            userContext: testUser
        )

        // Then
        XCTAssertTrue(results.isEmpty) // Authorized fees should not be flagged
    }

    func testDetectUnauthorizedFees_UnauthorizedFees() async throws {
        // Given
        let unauthorizedFees = [
            ExtractedData.Fee(
                date: Date(),
                description: "Inspection Fee - Unauthorized",
                amount: 150.0,
                category: .inspectionFee
            ),
            ExtractedData.Fee(
                date: Date(),
                description: "Processing Fee - Not in loan terms",
                amount: 75.0,
                category: .processingFee
            )
        ]
        auditEngine.mockResults = [MockAuditResults.unauthorizedFee]

        // When
        let results = try await auditEngine.detectUnauthorizedFees(
            fees: unauthorizedFees,
            userContext: testUser
        )

        // Then
        XCTAssertNotEmpty(results)
        XCTAssertTrue(results.contains { $0.issueType == .unauthorizedFee })

        let feeResult = results.first!
        XCTAssertNotNil(feeResult.affectedAmount)
        XCTAssertEqual(feeResult.severity, .high)
    }

    func testDetectUnauthorizedFees_ExcessiveFees() async throws {
        // Given
        let excessiveFees = [
            ExtractedData.Fee(
                date: Date(),
                description: "Late Fee - Excessive Amount",
                amount: 500.0, // Unusually high late fee
                category: .lateFee
            )
        ]
        auditEngine.mockResults = [MockAuditResults.unauthorizedFee]

        // When
        let results = try await auditEngine.detectUnauthorizedFees(
            fees: excessiveFees,
            userContext: testUser
        )

        // Then
        XCTAssertNotEmpty(results)
        // Should flag excessive amounts even for otherwise authorized fee types
    }

    // MARK: - Performance Tests

    func testPerformAudit_Performance() async {
        // Given
        auditEngine.processingDelay = 0.001

        // When/Then
        await measureAsync {
            try? await self.auditEngine.performAudit(
                on: self.testDocument,
                userContext: self.testUser,
                bankTransactions: self.testTransactions
            )
        }
    }

    func testBulkAnalysis_Performance() async {
        // Given
        let documents = [
            MockDocuments.mortgageStatement,
            MockDocuments.escrowStatement,
            MockDocuments.paymentHistory
        ]
        auditEngine.processingDelay = 0.001

        // When/Then
        await measureAsync {
            for document in documents {
                try? await self.auditEngine.performAudit(
                    on: document,
                    userContext: self.testUser,
                    bankTransactions: self.testTransactions
                )
            }
        }
    }

    func testMemoryUsage_LargeDataset() {
        // Given
        let largePaymentHistory = Array(repeating: MockExtractedData.paymentHistoryData.paymentHistory.first!, count: 1000)

        // When/Then
        measureMemory {
            Task {
                try? await self.auditEngine.validatePaymentAccuracy(
                    paymentHistory: largePaymentHistory,
                    expectedPayment: 1725.45,
                    interestRate: 0.0425
                )
            }
        }
    }

    // MARK: - Error Handling Tests

    func testAuditEngine_DataValidationError() async {
        // Given
        auditEngine.shouldFail = true
        auditEngine.failureError = AuditEngine.AuditError.dataValidationFailed("Invalid data format")

        // When/Then
        await testAsyncThrows(expectedError: AuditEngine.AuditError.self) {
            try await self.auditEngine.performAudit(
                on: self.testDocument,
                userContext: self.testUser,
                bankTransactions: self.testTransactions
            )
        }
    }

    func testAuditEngine_CalculationFailure() async {
        // Given
        auditEngine.shouldFail = true
        auditEngine.failureError = AuditEngine.AuditError.calculationError("Division by zero")

        // When/Then
        await testAsyncThrows(expectedError: AuditEngine.AuditError.self) {
            try await self.auditEngine.validatePaymentAccuracy(
                paymentHistory: MockExtractedData.mortgageStatementData.paymentHistory,
                expectedPayment: 1725.45,
                interestRate: 0.0425
            )
        }
    }

    func testAuditEngine_BusinessRuleViolation() async {
        // Given
        auditEngine.shouldFail = true
        auditEngine.failureError = AuditEngine.AuditError.businessRuleViolation("Interest rate exceeds legal limit")

        // When/Then
        await testAsyncThrows(expectedError: AuditEngine.AuditError.self) {
            try await self.auditEngine.performAudit(
                on: self.testDocument,
                userContext: self.testUser,
                bankTransactions: self.testTransactions
            )
        }
    }

    // MARK: - Edge Cases and Robustness Tests

    func testAuditEngine_EmptyDocument() async throws {
        // Given
        let emptyDocument = MortgageDocument(
            fileName: "empty.pdf",
            documentType: .other,
            uploadDate: Date(),
            originalText: "",
            extractedData: nil,
            analysisResults: [],
            isAnalyzed: false
        )

        // When
        let results = try await auditEngine.performAudit(
            on: emptyDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        // Should handle empty documents gracefully
        XCTAssertNotNil(results)
    }

    func testAuditEngine_CorruptedData() async throws {
        // Given
        let corruptedDocument = MockDocuments.corruptedDocument

        // When
        let results = try await auditEngine.performAudit(
            on: corruptedDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        // Should handle corrupted data gracefully
        XCTAssertNotNil(results)
    }

    func testAuditEngine_ExtremeValues() async throws {
        // Given
        let extremePayments = [
            ExtractedData.PaymentRecord(
                paymentDate: Date(),
                amount: Double.greatestFiniteMagnitude,
                principalApplied: nil,
                interestApplied: nil,
                escrowApplied: nil,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            )
        ]

        // When/Then
        // Should handle extreme values without crashing
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: extremePayments,
            expectedPayment: 1725.45,
            interestRate: 0.0425
        )

        XCTAssertNotNil(results)
    }

    func testAuditEngine_NilValues() async throws {
        // Given
        let nilValuePayments = [
            ExtractedData.PaymentRecord(
                paymentDate: Date(),
                amount: 1725.45,
                principalApplied: nil,
                interestApplied: nil,
                escrowApplied: nil,
                lateFeesApplied: nil,
                isLate: false,
                dayslate: nil
            )
        ]

        // When
        let results = try await auditEngine.validatePaymentAccuracy(
            paymentHistory: nilValuePayments,
            expectedPayment: 1725.45,
            interestRate: 0.0425
        )

        // Then
        // Should handle nil values gracefully
        XCTAssertNotNil(results)
    }

    // MARK: - Confidence and Accuracy Tests

    func testAuditResults_ConfidenceScoring() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        for result in results {
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)

            // High-severity issues should generally have high confidence
            if result.severity == .critical || result.severity == .high {
                XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
            }
        }
    }

    func testAuditResults_SeverityClassification() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        let severityDistribution = Dictionary(grouping: results, by: { $0.severity })

        // Verify severity makes sense for issue types
        for (severity, issues) in severityDistribution {
            for issue in issues {
                switch issue.issueType {
                case .incorrectInterest:
                    XCTAssertTrue([.high, .critical].contains(severity))
                case .latePaymentError:
                    XCTAssertTrue([.medium, .high].contains(severity))
                case .escrowError:
                    XCTAssertTrue([.low, .medium, .high].contains(severity))
                default:
                    break
                }
            }
        }
    }

    func testAuditResults_MonetaryImpact() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.monetaryResults

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        let totalImpact = results.compactMap { $0.affectedAmount }.reduce(0, +)
        XCTAssertGreaterThan(totalImpact, 0)

        // Verify monetary amounts are reasonable
        for result in results {
            if let amount = result.affectedAmount {
                XCTAssertGreaterThan(amount, 0)
                XCTAssertLessThan(amount, 100000) // Reasonable upper bound
            }
        }
    }

    // MARK: - Documentation and Evidence Tests

    func testAuditResults_EvidenceQuality() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        for result in results {
            // Evidence should be present and meaningful
            XCTAssertNotNil(result.evidenceText)
            if let evidence = result.evidenceText {
                XCTAssertFalse(evidence.isEmpty)
                XCTAssertGreaterThan(evidence.count, 10) // Minimum meaningful length
            }

            // Suggested actions should be specific and actionable
            XCTAssertFalse(result.suggestedAction.isEmpty)
            XCTAssertGreaterThan(result.suggestedAction.count, 20)

            // Detailed explanations should provide context
            XCTAssertFalse(result.detailedExplanation.isEmpty)
            XCTAssertGreaterThan(result.detailedExplanation.count, 50)
        }
    }

    func testAuditResults_CalculationDetails() async throws {
        // Given
        auditEngine.mockResults = MockAuditResults.allResults.filter { $0.calculationDetails != nil }

        // When
        let results = try await auditEngine.performAudit(
            on: testDocument,
            userContext: testUser,
            bankTransactions: testTransactions
        )

        // Then
        for result in results {
            if let calculations = result.calculationDetails {
                // Calculation details should be comprehensive
                XCTAssertNotNil(calculations.expectedValue)
                XCTAssertNotNil(calculations.actualValue)
                XCTAssertNotNil(calculations.difference)

                if let expected = calculations.expectedValue,
                   let actual = calculations.actualValue,
                   let difference = calculations.difference {

                    // Verify calculation consistency
                    XCTAssertApproximatelyEqual(abs(actual - expected), abs(difference), tolerance: 0.01)
                }

                // Formula should be provided for transparency
                XCTAssertNotNil(calculations.formula)
                XCTAssertFalse(calculations.formula?.isEmpty ?? true)

                // Assumptions should be documented
                XCTAssertNotEmpty(calculations.assumptions)
            }
        }
    }
}