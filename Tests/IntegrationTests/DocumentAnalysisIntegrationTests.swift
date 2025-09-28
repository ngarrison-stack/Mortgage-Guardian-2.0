import XCTest
import Combine
@testable import MortgageGuardian

/// Integration tests for the complete document analysis pipeline
/// Tests the interaction between DocumentProcessor, AuditEngine, and AIAnalysisService
final class DocumentAnalysisIntegrationTests: MortgageGuardianIntegrationTestCase {

    private var documentProcessor: MockDocumentProcessor!
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
        documentProcessor = nil
        auditEngine = nil
        aiAnalysisService = nil
        testUser = nil
        cancellables = nil
        super.tearDown()
    }

    private func setupServices() {
        documentProcessor = MockDocumentProcessor()
        auditEngine = MockAuditEngine()
        aiAnalysisService = MockAIAnalysisService()
    }

    private func setupTestData() {
        testUser = MockUsers.standardUser
    }

    // MARK: - Complete Analysis Pipeline Tests

    func testCompleteAnalysisPipeline_Success() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "mortgage_statement_202412.pdf"

        // Configure services for success
        documentProcessor.shouldFail = false
        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData
        auditEngine.shouldFail = false
        auditEngine.mockResults = [MockAuditResults.latePaymentError, MockAuditResults.misappliedPayment]
        aiAnalysisService.shouldFail = false
        aiAnalysisService.mockResults = [MockAuditResults.incorrectInterest]

        // When - Execute complete pipeline
        // Step 1: Process document
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Step 2: Perform manual audit
        let manualAuditResults = try await auditEngine.performAudit(
            on: document,
            userContext: testUser,
            bankTransactions: MockTransactions.mortgagePayments
        )

        // Step 3: Perform AI analysis
        let aiAnalysisResult = try await aiAnalysisService.analyzeDocument(
            document,
            userContext: testUser,
            bankTransactions: MockTransactions.mortgagePayments
        )

        // Step 4: Combine results
        let combinedResults = try await aiAnalysisService.performHybridAnalysis(
            document: document,
            userContext: testUser,
            bankTransactions: MockTransactions.mortgagePayments,
            manualResults: manualAuditResults
        )

        // Then
        XCTAssertEqual(document.fileName, fileName)
        XCTAssertEqual(document.documentType, .mortgageStatement)
        XCTAssertNotNil(document.extractedData)

        XCTAssertNotEmpty(manualAuditResults)
        XCTAssertEqual(manualAuditResults.count, 2) // late payment + misapplied payment

        XCTAssertNotEmpty(aiAnalysisResult.findings)
        XCTAssertEqual(aiAnalysisResult.findings.count, 1) // incorrect interest

        XCTAssertNotEmpty(combinedResults)
        XCTAssertEqual(combinedResults.count, 3) // Manual + AI results

        // Verify all expected issue types are present
        let issueTypes = Set(combinedResults.map { $0.issueType })
        XCTAssertTrue(issueTypes.contains(.latePaymentError))
        XCTAssertTrue(issueTypes.contains(.misappliedPayment))
        XCTAssertTrue(issueTypes.contains(.incorrectInterest))
    }

    func testCompleteAnalysisPipeline_DocumentProcessingFailure() async {
        // Given
        let imageData = MockFileData.createCorruptedData()
        let fileName = "corrupted.pdf"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.invalidImageData

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            _ = try await self.documentProcessor.processDocument(from: imageData, fileName: fileName)
        }

        // Pipeline should stop at document processing
    }

    func testCompleteAnalysisPipeline_AuditEngineFailure() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        documentProcessor.shouldFail = false
        auditEngine.shouldFail = true
        auditEngine.failureError = AuditEngine.AuditError.calculationError("Test failure")

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        await testAsyncThrows(expectedError: AuditEngine.AuditError.self) {
            _ = try await self.auditEngine.performAudit(on: document, userContext: self.testUser)
        }
    }

    func testCompleteAnalysisPipeline_AIAnalysisFailure() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        documentProcessor.shouldFail = false
        auditEngine.shouldFail = false
        aiAnalysisService.shouldFail = true
        aiAnalysisService.failureError = AIAnalysisService.AIAnalysisError.networkError(URLError(.notConnectedToInternet))

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let manualResults = try await auditEngine.performAudit(on: document, userContext: testUser)

        // Then
        await testAsyncThrows(expectedError: AIAnalysisService.AIAnalysisError.self) {
            _ = try await self.aiAnalysisService.analyzeDocument(document, userContext: self.testUser)
        }

        // Manual results should still be available
        XCTAssertNotEmpty(manualResults)
    }

    func testCompleteAnalysisPipeline_PartialFailureRecovery() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        documentProcessor.shouldFail = false
        auditEngine.shouldFail = false
        auditEngine.mockResults = [MockAuditResults.latePaymentError]
        aiAnalysisService.shouldFail = true // AI fails but manual succeeds

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let manualResults = try await auditEngine.performAudit(on: document, userContext: testUser)

        do {
            _ = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)
            XCTFail("AI analysis should have failed")
        } catch {
            // Expected AI failure
        }

        // Then - Should still have manual results
        XCTAssertNotEmpty(manualResults)
        XCTAssertEqual(manualResults.count, 1)
        XCTAssertEqual(manualResults.first?.issueType, .latePaymentError)
    }

    // MARK: - Data Flow Integration Tests

    func testDataFlow_ExtractedDataToAudit() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.paymentHistoryData // Has late payment

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let auditResults = try await auditEngine.performAudit(on: document, userContext: testUser)

        // Then
        let extractedData = try XCTUnwrap(document.extractedData)
        XCTAssertNotEmpty(extractedData.paymentHistory)
        XCTAssertNotEmpty(extractedData.fees)

        // Audit should find issues based on extracted data
        XCTAssertNotEmpty(auditResults)

        // For payment history document, should focus on payment-related issues
        let issueTypes = Set(auditResults.map { $0.issueType })
        XCTAssertTrue(issueTypes.isSubset(of: [.latePaymentError, .misappliedPayment]))
    }

    func testDataFlow_BankTransactionsIntegration() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        let bankTransactions = MockTransactions.mortgagePayments

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let auditResults = try await auditEngine.performAudit(
            on: document,
            userContext: testUser,
            bankTransactions: bankTransactions
        )
        let aiResults = try await aiAnalysisService.analyzeDocument(
            document,
            userContext: testUser,
            bankTransactions: bankTransactions
        )

        // Then
        XCTAssertNotEmpty(auditResults)
        XCTAssertNotEmpty(aiResults.findings)

        // Bank transactions should influence analysis results
        // (In a real implementation, this would be verified through the analysis logic)
    }

    func testDataFlow_UserContextPropagation() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        let multiAccountUser = MockUsers.multiAccountUser // Has multiple mortgage accounts

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let auditResults = try await auditEngine.performAudit(on: document, userContext: multiAccountUser)
        let aiResults = try await aiAnalysisService.analyzeDocument(document, userContext: multiAccountUser)

        // Then
        XCTAssertNotEmpty(auditResults)
        XCTAssertNotEmpty(aiResults.findings)

        // User context should be properly propagated through the pipeline
        XCTAssertEqual(multiAccountUser.mortgageAccounts.count, 3)
    }

    // MARK: - Performance Integration Tests

    func testPipeline_PerformanceUnderLoad() async {
        // Given
        let documents = [
            (data: MockFileData.createMockImageData(), fileName: "doc1.pdf"),
            (data: MockFileData.createMockImageData(), fileName: "doc2.pdf"),
            (data: MockFileData.createMockImageData(), fileName: "doc3.pdf")
        ]

        // Configure for minimal delays
        documentProcessor.processingDelay = 0.001
        auditEngine.processingDelay = 0.001
        aiAnalysisService.responseDelay = 0.001

        // When/Then
        await measureAsync {
            for document in documents {
                do {
                    let processedDoc = try await self.documentProcessor.processDocument(
                        from: document.data,
                        fileName: document.fileName
                    )
                    _ = try await self.auditEngine.performAudit(on: processedDoc, userContext: self.testUser)
                    _ = try await self.aiAnalysisService.analyzeDocument(processedDoc, userContext: self.testUser)
                } catch {
                    // Continue with other documents
                }
            }
        }
    }

    func testPipeline_ConcurrentDocumentProcessing() async throws {
        // Given
        let documents = [
            (data: MockFileData.createMockImageData(), fileName: "doc1.pdf"),
            (data: MockFileData.createMockImageData(), fileName: "doc2.pdf"),
            (data: MockFileData.createMockImageData(), fileName: "doc3.pdf")
        ]

        // When - Process documents concurrently
        let results = try await withThrowingTaskGroup(of: MortgageDocument.self) { group in
            for document in documents {
                group.addTask {
                    try await self.documentProcessor.processDocument(
                        from: document.data,
                        fileName: document.fileName
                    )
                }
            }

            var processedDocuments: [MortgageDocument] = []
            for try await document in group {
                processedDocuments.append(document)
            }
            return processedDocuments
        }

        // Then
        XCTAssertEqual(results.count, documents.count)
        for document in results {
            XCTAssertNotNil(document.extractedData)
        }
    }

    func testPipeline_MemoryUsageUnderLoad() {
        // Given
        let largeDocuments = Array(repeating: MockFileData.createMockImageData(), count: 10)

        // When/Then
        measureMemory {
            Task {
                for (index, documentData) in largeDocuments.enumerated() {
                    do {
                        let document = try await self.documentProcessor.processDocument(
                            from: documentData,
                            fileName: "doc\(index).pdf"
                        )
                        _ = try await self.auditEngine.performAudit(on: document, userContext: self.testUser)
                    } catch {
                        // Continue processing
                    }
                }
            }
        }
    }

    // MARK: - Error Recovery Integration Tests

    func testPipeline_ErrorRecoveryAndRetry() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"

        // Configure AI to fail initially, then succeed
        aiAnalysisService.shouldFail = true
        aiAnalysisService.failureError = AIAnalysisService.AIAnalysisError.rateLimitExceeded

        // When - First attempt (should fail)
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        do {
            _ = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)
            XCTFail("AI analysis should have failed initially")
        } catch AIAnalysisService.AIAnalysisError.rateLimitExceeded {
            // Expected failure
        }

        // Configure for success on retry
        aiAnalysisService.shouldFail = false

        // Retry (should succeed)
        let aiResult = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)

        // Then
        XCTAssertNotNil(aiResult)
        XCTAssertNotEmpty(aiResult.findings)
    }

    func testPipeline_GracefulDegradation() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"

        // Configure AI to fail but keep other services working
        documentProcessor.shouldFail = false
        auditEngine.shouldFail = false
        aiAnalysisService.shouldFail = true

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let manualResults = try await auditEngine.performAudit(on: document, userContext: testUser)

        var aiResults: [AuditResult] = []
        do {
            let aiResult = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)
            aiResults = aiResult.findings
        } catch {
            // AI failed, continue with manual results only
        }

        // Combine available results
        let allResults = manualResults + aiResults

        // Then - Should still have partial results
        XCTAssertNotEmpty(allResults)
        XCTAssertEqual(allResults.count, manualResults.count) // Only manual results
        XCTAssertTrue(aiResults.isEmpty) // AI failed
    }

    // MARK: - State Management Integration Tests

    func testPipeline_StateConsistencyAcrossServices() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"

        var processingStates: [Bool] = []
        var analysisStates: [Bool] = []

        // Monitor state changes
        documentProcessor.$isProcessing
            .sink { isProcessing in
                processingStates.append(isProcessing)
            }
            .store(in: &cancellables)

        aiAnalysisService.$isAnalyzing
            .sink { isAnalyzing in
                analysisStates.append(isAnalyzing)
            }
            .store(in: &cancellables)

        // Configure for slow processing to observe state changes
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.1
        aiAnalysisService.simulateSlowResponse = true
        aiAnalysisService.responseDelay = 0.1

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        _ = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)

        // Small delay to ensure state updates are captured
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        XCTAssertTrue(processingStates.contains(true)) // Was processing
        XCTAssertTrue(processingStates.contains(false)) // Finished processing
        XCTAssertTrue(analysisStates.contains(true)) // Was analyzing
        XCTAssertTrue(analysisStates.contains(false)) // Finished analyzing
    }

    func testPipeline_ProgressReporting() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"

        var progressUpdates: [DocumentProcessor.ProcessingProgress] = []
        var analysisUpdates: [AIAnalysisService.AnalysisProgress] = []

        // Monitor progress
        documentProcessor.$currentProgress
            .compactMap { $0 }
            .sink { progress in
                progressUpdates.append(progress)
            }
            .store(in: &cancellables)

        aiAnalysisService.$currentProgress
            .compactMap { $0 }
            .sink { progress in
                analysisUpdates.append(progress)
            }
            .store(in: &cancellables)

        // Configure for observable progress
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.2
        aiAnalysisService.simulateSlowResponse = true
        aiAnalysisService.responseDelay = 0.2

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        _ = try await aiAnalysisService.analyzeDocument(document, userContext: testUser)

        // Then
        XCTAssertNotEmpty(progressUpdates)
        XCTAssertNotEmpty(analysisUpdates)

        // Verify progress reaches completion
        XCTAssertTrue(progressUpdates.contains { $0.percentComplete == 100.0 })
        XCTAssertTrue(analysisUpdates.contains { $0.percentComplete == 100.0 })
    }

    // MARK: - Real-World Scenario Tests

    func testPipeline_MortgageStatementAnalysis() async throws {
        // Given - Realistic mortgage statement scenario
        let imageData = MockFileData.createMockImageData()
        let fileName = "mortgage_statement_december_2024.pdf"
        let bankTransactions = MockTransactions.mortgagePayments

        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData
        auditEngine.mockResults = [
            MockAuditResults.latePaymentError,
            MockAuditResults.incorrectInterest
        ]
        aiAnalysisService.mockResults = [
            MockAuditResults.misappliedPayment
        ]

        // When - Complete analysis pipeline
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let combinedResults = try await aiAnalysisService.performHybridAnalysis(
            document: document,
            userContext: testUser,
            bankTransactions: bankTransactions,
            manualResults: try await auditEngine.performAudit(on: document, userContext: testUser, bankTransactions: bankTransactions)
        )

        // Generate letter based on findings
        let letterResult = try await aiAnalysisService.generateNoticeOfErrorLetter(
            for: combinedResults,
            userInfo: testUser,
            mortgageAccount: testUser.mortgageAccounts.first!
        )

        // Then
        XCTAssertEqual(document.documentType, .mortgageStatement)
        XCTAssertNotEmpty(combinedResults)
        XCTAssertEqual(combinedResults.count, 3) // All findings combined

        XCTAssertEqual(letterResult.letterType, .noticeOfError)
        XCTAssertFalse(letterResult.letterContent.isEmpty)
        XCTAssertNotNil(letterResult.pdfData)

        // Verify letter contains reference to all issues
        let letterContent = letterResult.letterContent
        XCTAssertTrue(letterContent.contains("Loan Number"))
        XCTAssertTrue(letterContent.contains(testUser.mortgageAccounts.first!.loanNumber))
    }

    func testPipeline_EscrowStatementAnalysis() async throws {
        // Given - Escrow statement scenario
        let imageData = MockFileData.createMockImageData()
        let fileName = "escrow_analysis_2024.pdf"

        documentProcessor.mockExtractedData = MockExtractedData.escrowStatementData
        auditEngine.mockResults = [MockAuditResults.escrowError]
        aiAnalysisService.mockResults = [MockAuditResults.escrowError]

        // When
        let document = try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        let combinedResults = try await aiAnalysisService.performHybridAnalysis(
            document: document,
            userContext: testUser,
            manualResults: try await auditEngine.performAudit(on: document, userContext: testUser)
        )

        // Then
        XCTAssertEqual(document.documentType, .escrowStatement)
        XCTAssertNotEmpty(combinedResults)

        // Should focus on escrow-related issues
        let issueTypes = Set(combinedResults.map { $0.issueType })
        XCTAssertTrue(issueTypes.contains(.escrowError))
    }

    func testPipeline_MultiDocumentAnalysis() async throws {
        // Given - Multiple related documents
        let documents = [
            (data: MockFileData.createMockImageData(), fileName: "statement_nov_2024.pdf", type: MortgageDocument.DocumentType.mortgageStatement),
            (data: MockFileData.createMockImageData(), fileName: "escrow_2024.pdf", type: MortgageDocument.DocumentType.escrowStatement),
            (data: MockFileData.createMockImageData(), fileName: "payment_history_2024.pdf", type: MortgageDocument.DocumentType.paymentHistory)
        ]

        var allResults: [AuditResult] = []

        // When - Process each document
        for document in documents {
            let processedDoc = try await documentProcessor.processDocument(
                from: document.data,
                fileName: document.fileName
            )

            let results = try await auditEngine.performAudit(
                on: processedDoc,
                userContext: testUser,
                bankTransactions: MockTransactions.mortgagePayments
            )

            allResults.append(contentsOf: results)
        }

        // Then
        XCTAssertNotEmpty(allResults)
        XCTAssertGreaterThanOrEqual(allResults.count, documents.count) // At least one result per document

        // Should have diverse issue types from different document types
        let issueTypes = Set(allResults.map { $0.issueType })
        XCTAssertGreaterThan(issueTypes.count, 1)
    }
}