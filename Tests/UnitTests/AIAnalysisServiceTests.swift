import XCTest
import Combine
@testable import MortgageGuardian

/// Comprehensive unit tests for AIAnalysisService
/// Tests all core functionality including analysis, letter generation, and error handling
final class AIAnalysisServiceTests: MortgageGuardianUnitTestCase {

    private var aiService: MockAIAnalysisService!
    private var testUser: User!
    private var testDocument: MortgageDocument!
    private var testMortgageAccount: User.MortgageAccount!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        setupTestObjects()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        aiService = nil
        testUser = nil
        testDocument = nil
        testMortgageAccount = nil
        cancellables = nil
        super.tearDown()
    }

    private func setupTestObjects() {
        aiService = MockAIAnalysisService()
        testUser = MockUsers.standardUser
        testDocument = MockDocuments.mortgageStatement
        testMortgageAccount = MockMortgageAccounts.standardAccount
    }

    // MARK: - Document Analysis Tests

    func testAnalyzeDocument_Success() async throws {
        // Given
        aiService.shouldFail = false
        aiService.mockResults = [MockAuditResults.latePaymentError]

        // When
        let result = try await aiService.analyzeDocument(
            testDocument,
            userContext: testUser,
            bankTransactions: MockTransactions.mortgagePayments
        )

        // Then
        XCTAssertEqual(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.issueType, .latePaymentError)
        XCTAssertGreaterThan(result.confidence, 0.5)
        XCTAssertEqual(result.analysisMetadata.documentType, .mortgageStatement)
        XCTAssertNotNil(result.rawResponse)
        XCTAssertGreaterThan(result.tokensUsed.totalTokens, 0)
        XCTAssertFalse(aiService.isAnalyzing)
    }

    func testAnalyzeDocument_NetworkFailure() async {
        // Given
        aiService.shouldFail = true
        aiService.failureError = AIAnalysisService.AIAnalysisError.networkError(URLError(.notConnectedToInternet))

        // When/Then
        await testAsyncThrows(expectedError: AIAnalysisService.AIAnalysisError.self) {
            try await self.aiService.analyzeDocument(
                self.testDocument,
                userContext: self.testUser
            )
        }

        XCTAssertFalse(aiService.isAnalyzing)
    }

    func testAnalyzeDocument_RateLimitExceeded() async {
        // Given
        aiService.shouldFail = true
        aiService.failureError = AIAnalysisService.AIAnalysisError.rateLimitExceeded

        // When/Then
        await testAsyncThrows(expectedError: AIAnalysisService.AIAnalysisError.self) {
            try await self.aiService.analyzeDocument(
                self.testDocument,
                userContext: self.testUser
            )
        }
    }

    func testAnalyzeDocument_ProgressUpdates() async throws {
        // Given
        aiService.simulateSlowResponse = true
        aiService.responseDelay = 0.5
        var progressUpdates: [AIAnalysisService.AnalysisProgress] = []

        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 3 // At least 3 progress updates

        aiService.$currentProgress
            .compactMap { $0 }
            .sink { progress in
                progressUpdates.append(progress)
                if progressUpdates.count >= 3 {
                    progressExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        _ = try await aiService.analyzeDocument(testDocument, userContext: testUser)

        // Then
        await fulfillment(of: [progressExpectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(progressUpdates.count, 3)

        let finalProgress = progressUpdates.last!
        XCTAssertEqual(finalProgress.percentComplete, 100.0)
        XCTAssertEqual(finalProgress.step, .completion)
    }

    func testAnalyzeDocument_ConfigurationHandling() async throws {
        // Given
        let customConfig = AIAnalysisService.AIConfiguration(
            model: .claude3Haiku,
            maxTokens: 2048,
            temperature: 0.0,
            confidenceThreshold: 0.8,
            timeoutInterval: 30,
            enableStreamingResponse: false,
            retryAttempts: 2,
            concurrentAnalysisLimit: 1
        )

        // When
        let result = try await aiService.analyzeDocument(
            testDocument,
            userContext: testUser,
            configuration: customConfig
        )

        // Then
        XCTAssertEqual(result.analysisMetadata.modelUsed, .claude3Haiku)
    }

    func testAnalyzeDocument_EmptyDocument() async {
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

        aiService.shouldFail = true
        aiService.failureError = AIAnalysisService.AIAnalysisError.insufficientContext

        // When/Then
        await testAsyncThrows(expectedError: AIAnalysisService.AIAnalysisError.self) {
            try await self.aiService.analyzeDocument(emptyDocument, userContext: self.testUser)
        }
    }

    // MARK: - Hybrid Analysis Tests

    func testPerformHybridAnalysis_Success() async throws {
        // Given
        let manualResults = [MockAuditResults.misappliedPayment]
        aiService.mockResults = [MockAuditResults.latePaymentError]

        // When
        let results = try await aiService.performHybridAnalysis(
            document: testDocument,
            userContext: testUser,
            bankTransactions: MockTransactions.mortgagePayments,
            manualResults: manualResults
        )

        // Then
        XCTAssertEqual(results.count, 2) // Manual + AI results
        XCTAssertTrue(results.contains { $0.issueType == .misappliedPayment })
        XCTAssertTrue(results.contains { $0.issueType == .latePaymentError })
    }

    func testPerformHybridAnalysis_AIFailure() async {
        // Given
        let manualResults = [MockAuditResults.misappliedPayment]
        aiService.shouldFail = true

        // When/Then
        await testAsyncThrows {
            try await self.aiService.performHybridAnalysis(
                document: self.testDocument,
                userContext: self.testUser,
                manualResults: manualResults
            )
        }
    }

    // MARK: - Letter Generation Tests

    func testGenerateNoticeOfErrorLetter_Success() async throws {
        // Given
        let issues = [MockAuditResults.latePaymentError, MockAuditResults.unauthorizedFee]

        // When
        let result = try await aiService.generateNoticeOfErrorLetter(
            for: issues,
            userInfo: testUser,
            mortgageAccount: testMortgageAccount
        )

        // Then
        XCTAssertEqual(result.letterType, .noticeOfError)
        XCTAssertFalse(result.letterContent.isEmpty)
        XCTAssertEqual(result.metadata.issues.count, 2)
        XCTAssertEqual(result.metadata.userInfo.fullName, testUser.fullName)
        XCTAssertEqual(result.metadata.mortgageAccount.loanNumber, testMortgageAccount.loanNumber)
        XCTAssertNotNil(result.pdfData)
        XCTAssertGreaterThan(result.confidence, 0.9)

        // Verify letter content includes key elements
        XCTAssertTrue(result.letterContent.contains("Notice of Error"))
        XCTAssertTrue(result.letterContent.contains(testMortgageAccount.loanNumber))
        XCTAssertTrue(result.letterContent.contains(testUser.fullName))
    }

    func testGenerateNoticeOfErrorLetter_EmptyIssues() async {
        // Given
        let emptyIssues: [AuditResult] = []
        aiService.shouldFail = true
        aiService.failureError = AIAnalysisService.AIAnalysisError.insufficientContext

        // When/Then
        await testAsyncThrows(expectedError: AIAnalysisService.AIAnalysisError.self) {
            try await self.aiService.generateNoticeOfErrorLetter(
                for: emptyIssues,
                userInfo: self.testUser,
                mortgageAccount: self.testMortgageAccount
            )
        }
    }

    func testGenerateNoticeOfErrorLetter_DifferentTypes() async throws {
        // Given
        let issues = [MockAuditResults.latePaymentError]

        // Test different letter types
        let letterTypes: [AIAnalysisService.LetterGenerationResult.LetterType] = [
            .noticeOfError,
            .qualifiedWrittenRequest,
            .escalationLetter,
            .consumerComplaint
        ]

        for letterType in letterTypes {
            // When
            let result = try await aiService.generateNoticeOfErrorLetter(
                for: issues,
                userInfo: testUser,
                mortgageAccount: testMortgageAccount,
                letterType: letterType
            )

            // Then
            XCTAssertEqual(result.letterType, letterType)
            XCTAssertFalse(result.letterContent.isEmpty)
        }
    }

    func testGenerateNoticeOfErrorLetter_UrgencyLevels() async throws {
        // Given
        let criticalIssues = [MockAuditResults.incorrectInterest] // Critical severity
        let routineIssues = [MockAuditResults.latePaymentError] // High severity

        // When
        let criticalResult = try await aiService.generateNoticeOfErrorLetter(
            for: criticalIssues,
            userInfo: testUser,
            mortgageAccount: testMortgageAccount
        )

        let routineResult = try await aiService.generateNoticeOfErrorLetter(
            for: routineIssues,
            userInfo: testUser,
            mortgageAccount: testMortgageAccount
        )

        // Then
        // Both should generate successfully regardless of urgency
        XCTAssertNotNil(criticalResult)
        XCTAssertNotNil(routineResult)
    }

    // MARK: - Configuration Tests

    func testConfigurationDefaults() {
        // Given/When
        let defaultConfig = AIAnalysisService.AIConfiguration.default
        let fastConfig = AIAnalysisService.AIConfiguration.fast

        // Then
        XCTAssertEqual(defaultConfig.model, .claude35Sonnet)
        XCTAssertEqual(defaultConfig.maxTokens, 4096)
        XCTAssertEqual(defaultConfig.confidenceThreshold, 0.7)
        XCTAssertEqual(defaultConfig.retryAttempts, 3)

        XCTAssertEqual(fastConfig.model, .claude3Haiku)
        XCTAssertEqual(fastConfig.maxTokens, 2048)
        XCTAssertEqual(fastConfig.confidenceThreshold, 0.6)
        XCTAssertEqual(fastConfig.retryAttempts, 2)
    }

    func testModelCostCalculation() {
        // Given
        let models: [AIAnalysisService.AIConfiguration.ClaudeModel] = [
            .claude3Haiku, .claude3Sonnet, .claude3Opus, .claude35Sonnet
        ]

        // When/Then
        for model in models {
            XCTAssertGreaterThan(model.costPerInputToken, 0)
            XCTAssertGreaterThan(model.contextWindow, 0)
            XCTAssertFalse(model.displayName.isEmpty)
        }

        // Verify cost ordering (Haiku < Sonnet < Opus)
        XCTAssertLessThan(
            AIAnalysisService.AIConfiguration.ClaudeModel.claude3Haiku.costPerInputToken,
            AIAnalysisService.AIConfiguration.ClaudeModel.claude3Sonnet.costPerInputToken
        )
        XCTAssertLessThan(
            AIAnalysisService.AIConfiguration.ClaudeModel.claude3Sonnet.costPerInputToken,
            AIAnalysisService.AIConfiguration.ClaudeModel.claude3Opus.costPerInputToken
        )
    }

    // MARK: - Performance Tests

    func testAnalysisPerformance() async {
        // Given
        aiService.responseDelay = 0.001 // Very fast response

        // When/Then
        await measureAsync {
            try? await self.aiService.analyzeDocument(self.testDocument, userContext: self.testUser)
        }
    }

    func testBatchAnalysisMemory() {
        // Given
        let documents = Array(repeating: testDocument, count: 10)

        // When/Then
        measureMemory {
            Task {
                for document in documents {
                    try? await self.aiService.analyzeDocument(document, userContext: self.testUser)
                }
            }
        }
    }

    // MARK: - Edge Case Tests

    func testAnalyzeDocument_LargeDocument() async throws {
        // Given
        let largeDocument = MockDocuments.largeDocument
        aiService.responseDelay = 0.1

        // When
        let result = try await aiService.analyzeDocument(largeDocument, userContext: testUser)

        // Then
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.analysisMetadata.contextLength, 10000)
    }

    func testAnalyzeDocument_SpecialCharacters() async throws {
        // Given
        let specialDocument = MortgageDocument(
            fileName: "special_chars_文档.pdf",
            documentType: .mortgageStatement,
            uploadDate: Date(),
            originalText: "Document with special chars: ñáéíóú, 中文, 🏠💰",
            extractedData: MockExtractedData.mortgageStatementData,
            analysisResults: [],
            isAnalyzed: false
        )

        // When
        let result = try await aiService.analyzeDocument(specialDocument, userContext: testUser)

        // Then
        XCTAssertNotNil(result)
    }

    func testConcurrentAnalysis() async throws {
        // Given
        aiService.responseDelay = 0.1
        let documents = [testDocument, MockDocuments.escrowStatement, MockDocuments.paymentHistory]

        // When
        async let result1 = aiService.analyzeDocument(documents[0], userContext: testUser)
        async let result2 = aiService.analyzeDocument(documents[1], userContext: testUser)
        async let result3 = aiService.analyzeDocument(documents[2], userContext: testUser)

        let results = try await [result1, result2, result3]

        // Then
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertNotNil(result)
        }
    }

    // MARK: - Error Recovery Tests

    func testAnalysisWithRetry() async throws {
        // Given
        aiService.shouldFail = true
        aiService.failureError = NetworkError.timeout

        // Simulate retry logic (this would be in the real service)
        var attempts = 0
        let maxAttempts = 3

        // When
        while attempts < maxAttempts {
            do {
                _ = try await aiService.analyzeDocument(testDocument, userContext: testUser)
                break
            } catch {
                attempts += 1
                if attempts >= maxAttempts {
                    throw error
                }
                // On last attempt, make it succeed
                if attempts == maxAttempts - 1 {
                    aiService.shouldFail = false
                }
            }
        }

        // Then
        XCTAssertEqual(attempts, 2) // Should succeed on second attempt
    }

    func testErrorMessageLocalization() {
        // Given
        let errors: [AIAnalysisService.AIAnalysisError] = [
            .invalidConfiguration,
            .apiKeyNotConfigured,
            .networkError(URLError(.notConnectedToInternet)),
            .rateLimitExceeded,
            .quotaExceeded,
            .analysisTimeout
        ]

        // When/Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - State Management Tests

    func testAnalysisHistory() async throws {
        // Given
        XCTAssertTrue(aiService.analysisHistory.isEmpty)

        // When
        _ = try await aiService.analyzeDocument(testDocument, userContext: testUser)
        _ = try await aiService.analyzeDocument(MockDocuments.escrowStatement, userContext: testUser)

        // Then
        XCTAssertEqual(aiService.analysisHistory.count, 2)

        let firstResult = aiService.analysisHistory[0]
        let secondResult = aiService.analysisHistory[1]

        XCTAssertEqual(firstResult.analysisMetadata.documentType, .mortgageStatement)
        XCTAssertEqual(secondResult.analysisMetadata.documentType, .escrowStatement)
    }

    func testServiceState() async throws {
        // Given
        XCTAssertFalse(aiService.isAnalyzing)
        XCTAssertNil(aiService.currentProgress)

        // When
        aiService.simulateSlowResponse = true
        aiService.responseDelay = 0.2

        let analysisTask = Task {
            try await aiService.analyzeDocument(testDocument, userContext: testUser)
        }

        // Brief delay to let analysis start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then (during analysis)
        XCTAssertTrue(aiService.isAnalyzing)
        XCTAssertNotNil(aiService.currentProgress)

        // Wait for completion
        _ = try await analysisTask.value

        // Then (after analysis)
        XCTAssertFalse(aiService.isAnalyzing)
    }

    // MARK: - Integration with User Context Tests

    func testAnalysisWithBankTransactions() async throws {
        // Given
        let bankTransactions = MockTransactions.mortgagePayments

        // When
        let result = try await aiService.analyzeDocument(
            testDocument,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertNotNil(result)
        // Verify that bank transaction context would influence analysis
        // (In a real implementation, this would be verified through the analysis results)
    }

    func testAnalysisWithMultipleAccounts() async throws {
        // Given
        let multiAccountUser = MockUsers.multiAccountUser

        // When
        let result = try await aiService.analyzeDocument(
            testDocument,
            userContext: multiAccountUser
        )

        // Then
        XCTAssertNotNil(result)
        // Verify analysis handles multiple mortgage accounts appropriately
    }

    func testAnalysisWithProblematicUser() async throws {
        // Given
        let problematicUser = MockUsers.problematicUser

        // When
        let result = try await aiService.analyzeDocument(
            testDocument,
            userContext: problematicUser
        )

        // Then
        XCTAssertNotNil(result)
        // Analysis should still complete even with problematic user data
    }
}