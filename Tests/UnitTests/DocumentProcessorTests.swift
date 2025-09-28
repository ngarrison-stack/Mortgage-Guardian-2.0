import XCTest
import Combine
import UIKit
@testable import MortgageGuardian

/// Comprehensive unit tests for DocumentProcessor
/// Tests OCR processing, data extraction, and document validation
final class DocumentProcessorTests: MortgageGuardianUnitTestCase {

    private var documentProcessor: MockDocumentProcessor!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        documentProcessor = MockDocumentProcessor()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        documentProcessor = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Image Processing Tests

    func testProcessDocument_FromImageData_Success() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test_statement.jpg"
        documentProcessor.shouldFail = false
        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData

        // When
        let result = try await documentProcessor.processDocument(
            from: imageData,
            fileName: fileName
        )

        // Then
        XCTAssertEqual(result.fileName, fileName)
        XCTAssertEqual(result.documentType, .mortgageStatement)
        XCTAssertFalse(result.originalText.isEmpty)
        XCTAssertNotNil(result.extractedData)
        XCTAssertFalse(result.isAnalyzed)
        XCTAssertTrue(result.analysisResults.isEmpty)

        // Verify extracted data
        let extractedData = try XCTUnwrap(result.extractedData)
        XCTAssertEqual(extractedData.loanNumber, "LOAN123456789")
        XCTAssertEqual(extractedData.servicerName, "Example Mortgage Corp")
        XCTAssertMoneyEqual(extractedData.principalBalance ?? 0, 298750.50)
    }

    func testProcessDocument_FromImageData_InvalidData() async {
        // Given
        let invalidData = Data([0x00, 0x01, 0x02]) // Invalid image data
        let fileName = "invalid.jpg"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.invalidImageData

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(
                from: invalidData,
                fileName: fileName
            )
        }
    }

    func testProcessDocument_UnsupportedFormat() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "document.unsupported"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.unsupportedFileFormat

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(
                from: imageData,
                fileName: fileName
            )
        }
    }

    func testProcessDocument_DocumentTooLarge() async {
        // Given
        let largeData = Data(count: 60 * 1024 * 1024) // 60MB
        let fileName = "large_document.pdf"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.documentTooLarge

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(
                from: largeData,
                fileName: fileName
            )
        }
    }

    // MARK: - PDF Processing Tests

    func testProcessDocument_FromPDFData_Success() async throws {
        // Given
        let pdfData = MockFileData.createMockPDFData()
        let fileName = "statement.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData

        // When
        let result = try await documentProcessor.processDocument(
            from: pdfData,
            fileName: fileName
        )

        // Then
        XCTAssertEqual(result.fileName, fileName)
        XCTAssertNotNil(result.extractedData)
        XCTAssertFalse(result.originalText.isEmpty)
    }

    func testProcessDocument_CorruptedPDF() async {
        // Given
        let corruptedData = MockFileData.createCorruptedData()
        let fileName = "corrupted.pdf"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.documentParsingFailed("Corrupted PDF")

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(
                from: corruptedData,
                fileName: fileName
            )
        }
    }

    // MARK: - Progress Tracking Tests

    func testProcessDocument_ProgressUpdates() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.5

        var progressUpdates: [DocumentProcessor.ProcessingProgress] = []
        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 3

        documentProcessor.$currentProgress
            .compactMap { $0 }
            .sink { progress in
                progressUpdates.append(progress)
                if progressUpdates.count >= 3 {
                    progressExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        _ = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        await fulfillment(of: [progressExpectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(progressUpdates.count, 3)

        let finalProgress = progressUpdates.last!
        XCTAssertEqual(finalProgress.percentComplete, 100.0)
        XCTAssertEqual(finalProgress.currentStep, .completion)
    }

    func testProcessDocument_ProgressSteps() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.3

        var steps: [DocumentProcessor.ProcessingProgress.ProcessingStep] = []
        let progressExpectation = expectation(description: "All steps completed")

        documentProcessor.$currentProgress
            .compactMap { $0 }
            .sink { progress in
                if !steps.contains(progress.currentStep) {
                    steps.append(progress.currentStep)
                }
                if progress.currentStep == .completion {
                    progressExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        _ = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        await fulfillment(of: [progressExpectation], timeout: 1.0)

        let expectedSteps: [DocumentProcessor.ProcessingProgress.ProcessingStep] = [
            .validation, .preprocessing, .ocrProcessing, .dataExtraction, .completion
        ]

        for step in expectedSteps {
            XCTAssertTrue(steps.contains(step), "Missing processing step: \(step)")
        }
    }

    // MARK: - OCR Configuration Tests

    func testProcessDocument_DefaultConfiguration() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"

        // When
        let result = try await documentProcessor.processDocument(
            from: imageData,
            fileName: fileName
        )

        // Then
        XCTAssertNotNil(result)
        // Default configuration should work
    }

    func testProcessDocument_FastConfiguration() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        let fastConfig = DocumentProcessor.OCRConfiguration.fast

        // When
        let result = try await documentProcessor.processDocument(
            from: imageData,
            fileName: fileName,
            configuration: fastConfig
        )

        // Then
        XCTAssertNotNil(result)
    }

    func testOCRConfiguration_Validation() {
        // Given/When
        let defaultConfig = DocumentProcessor.OCRConfiguration.default
        let fastConfig = DocumentProcessor.OCRConfiguration.fast

        // Then
        XCTAssertEqual(defaultConfig.recognitionLanguages, ["en-US"])
        XCTAssertTrue(defaultConfig.usesLanguageCorrection)
        XCTAssertFalse(defaultConfig.customWords.isEmpty)

        XCTAssertEqual(fastConfig.recognitionLanguages, ["en-US"])
        XCTAssertFalse(fastConfig.usesLanguageCorrection)
        XCTAssertTrue(fastConfig.customWords.isEmpty)

        // Fast should have higher minimum text height for speed
        XCTAssertGreaterThan(fastConfig.minimumTextHeight, defaultConfig.minimumTextHeight)
    }

    // MARK: - Batch Processing Tests

    func testProcessBatch_Success() async throws {
        // Given
        let documents = [
            (data: MockFileData.createMockImageData(), fileName: "doc1.jpg"),
            (data: MockFileData.createMockImageData(), fileName: "doc2.jpg"),
            (data: MockFileData.createMockPDFData(), fileName: "doc3.pdf")
        ]

        // When
        let results = try await documentProcessor.processBatch(documents: documents)

        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].fileName, "doc1.jpg")
        XCTAssertEqual(results[1].fileName, "doc2.jpg")
        XCTAssertEqual(results[2].fileName, "doc3.pdf")
    }

    func testProcessBatch_PartialFailure() async throws {
        // Given
        let documents = [
            (data: MockFileData.createMockImageData(), fileName: "good1.jpg"),
            (data: MockFileData.createCorruptedData(), fileName: "bad.jpg"),
            (data: MockFileData.createMockImageData(), fileName: "good2.jpg")
        ]

        // Configure to fail on corrupted data but continue with others
        documentProcessor.shouldFail = false // Will still process good documents

        // When
        let results = try await documentProcessor.processBatch(documents: documents)

        // Then
        // Should continue processing even if some documents fail
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    func testProcessBatch_Empty() async throws {
        // Given
        let emptyDocuments: [(data: Data, fileName: String)] = []

        // When
        let results = try await documentProcessor.processBatch(documents: emptyDocuments)

        // Then
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Document Type Detection Tests

    func testDocumentTypeDetection_MortgageStatement() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "mortgage_statement_202412.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertEqual(result.documentType, .mortgageStatement)
    }

    func testDocumentTypeDetection_EscrowStatement() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "escrow_analysis_2024.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.escrowStatementData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertEqual(result.documentType, .escrowStatement)
    }

    func testDocumentTypeDetection_PaymentHistory() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "payment_history_2024.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.paymentHistoryData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertEqual(result.documentType, .paymentHistory)
    }

    func testDocumentTypeDetection_Unknown() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "unknown_document.pdf"

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertEqual(result.documentType, .other)
    }

    // MARK: - Data Extraction Tests

    func testDataExtraction_MortgageStatement() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "statement.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.mortgageStatementData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        let extractedData = try XCTUnwrap(result.extractedData)

        XCTAssertEqual(extractedData.loanNumber, "LOAN123456789")
        XCTAssertEqual(extractedData.servicerName, "Example Mortgage Corp")
        XCTAssertEqual(extractedData.borrowerName, "John Doe")
        XCTAssertMoneyEqual(extractedData.principalBalance ?? 0, 298750.50)
        XCTAssertApproximatelyEqual(extractedData.interestRate ?? 0, 0.0425, tolerance: 0.0001)
        XCTAssertMoneyEqual(extractedData.monthlyPayment ?? 0, 1725.45)
        XCTAssertMoneyEqual(extractedData.escrowBalance ?? 0, 2450.75)
        XCTAssertNotNil(extractedData.dueDate)

        // Verify payment history
        XCTAssertEqual(extractedData.paymentHistory.count, 1)
        let payment = extractedData.paymentHistory.first!
        XCTAssertMoneyEqual(payment.amount, 1725.45)
        XCTAssertFalse(payment.isLate)

        // Verify escrow activity
        XCTAssertEqual(extractedData.escrowActivity.count, 2)
        let propertyTax = extractedData.escrowActivity.first { $0.category == .propertyTax }
        XCTAssertNotNil(propertyTax)
        XCTAssertMoneyEqual(propertyTax?.amount ?? 0, 1200.00)
    }

    func testDataExtraction_EscrowStatement() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "escrow.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.escrowStatementData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        let extractedData = try XCTUnwrap(result.extractedData)

        XCTAssertNotNil(extractedData.escrowBalance)
        XCTAssertNotEmpty(extractedData.escrowActivity)

        // Verify escrow transactions
        let propertyTaxTransactions = extractedData.escrowActivity.filter { $0.category == .propertyTax }
        let insuranceTransactions = extractedData.escrowActivity.filter { $0.category == .homeownerInsurance }

        XCTAssertNotEmpty(propertyTaxTransactions)
        XCTAssertNotEmpty(insuranceTransactions)
    }

    func testDataExtraction_PaymentHistory() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "payments.pdf"
        documentProcessor.mockExtractedData = MockExtractedData.paymentHistoryData

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        let extractedData = try XCTUnwrap(result.extractedData)

        XCTAssertNotEmpty(extractedData.paymentHistory)
        XCTAssertNotEmpty(extractedData.fees)

        // Verify late payment detection
        let latePayments = extractedData.paymentHistory.filter { $0.isLate }
        XCTAssertNotEmpty(latePayments)

        let latePayment = latePayments.first!
        XCTAssertNotNil(latePayment.dayslate)
        XCTAssertNotNil(latePayment.lateFeesApplied)
        XCTAssertGreaterThan(latePayment.dayslate ?? 0, 0)

        // Verify fees
        let lateFees = extractedData.fees.filter { $0.category == .lateFee }
        XCTAssertNotEmpty(lateFees)
    }

    // MARK: - Error Handling Tests

    func testProcessDocument_OCRFailure() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.ocrProcessingFailed(NSError(domain: "Vision", code: -1))

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(from: imageData, fileName: fileName)
        }
    }

    func testProcessDocument_InsufficientTextConfidence() async {
        // Given
        let poorQualityData = MockImages.createPoorQualityImage().pngData()!
        let fileName = "poor_quality.png"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.insufficientTextConfidence

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(from: poorQualityData, fileName: fileName)
        }
    }

    func testProcessDocument_ProcessingTimeout() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.processingTimeout

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(from: imageData, fileName: fileName)
        }
    }

    func testProcessDocument_MemoryLimitExceeded() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.shouldFail = true
        documentProcessor.failureError = DocumentProcessor.ProcessingError.memoryLimitExceeded

        // When/Then
        await testAsyncThrows(expectedError: DocumentProcessor.ProcessingError.self) {
            try await self.documentProcessor.processDocument(from: imageData, fileName: fileName)
        }
    }

    // MARK: - Performance Tests

    func testProcessDocument_Performance() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.processingDelay = 0.001

        // When/Then
        await measureAsync {
            try? await self.documentProcessor.processDocument(from: imageData, fileName: fileName)
        }
    }

    func testProcessBatch_Performance() async {
        // Given
        let documents = Array(repeating: (data: MockFileData.createMockImageData(), fileName: "test.jpg"), count: 5)
        documentProcessor.processingDelay = 0.001

        // When/Then
        await measureAsync {
            try? await self.documentProcessor.processBatch(documents: documents)
        }
    }

    func testMemoryUsage_LargeDocument() {
        // Given
        let largeImageData = Data(count: 10 * 1024 * 1024) // 10MB

        // When/Then
        measureMemory {
            Task {
                try? await self.documentProcessor.processDocument(from: largeImageData, fileName: "large.jpg")
            }
        }
    }

    // MARK: - Edge Cases

    func testProcessDocument_EmptyFileName() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = ""

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.fileName, fileName)
    }

    func testProcessDocument_VeryLongFileName() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = String(repeating: "a", count: 1000) + ".jpg"

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.fileName, fileName)
    }

    func testProcessDocument_SpecialCharactersInFileName() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "document_with_special_chars_ñáéíóú_中文_🏠.jpg"

        // When
        let result = try await documentProcessor.processDocument(from: imageData, fileName: fileName)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.fileName, fileName)
    }

    func testProcessDocument_MinimalValidData() async throws {
        // Given
        let minimalImageData = UIImage(systemName: "doc.text")!.pngData()!
        let fileName = "minimal.png"

        // When
        let result = try await documentProcessor.processDocument(from: minimalImageData, fileName: fileName)

        // Then
        XCTAssertNotNil(result)
    }

    // MARK: - State Management Tests

    func testProcessorState_IsProcessing() async throws {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName = "test.jpg"
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.2

        XCTAssertFalse(documentProcessor.isProcessing)

        // When
        let processingTask = Task {
            try await documentProcessor.processDocument(from: imageData, fileName: fileName)
        }

        // Brief delay to let processing start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then (during processing)
        XCTAssertTrue(documentProcessor.isProcessing)

        // Wait for completion
        _ = try await processingTask.value

        // Then (after processing)
        XCTAssertFalse(documentProcessor.isProcessing)
    }

    func testConcurrentProcessing_Blocked() async {
        // Given
        let imageData = MockFileData.createMockImageData()
        let fileName1 = "test1.jpg"
        let fileName2 = "test2.jpg"
        documentProcessor.simulateSlowProcessing = true
        documentProcessor.processingDelay = 0.3

        // When - try to process two documents concurrently
        let task1 = Task {
            try await documentProcessor.processDocument(from: imageData, fileName: fileName1)
        }

        let task2 = Task {
            try await documentProcessor.processDocument(from: imageData, fileName: fileName2)
        }

        // Then - second task should fail because processor is busy
        do {
            _ = try await task1.value
        } catch {
            XCTFail("First task should succeed")
        }

        do {
            _ = try await task2.value
            XCTFail("Second task should fail due to concurrent processing")
        } catch {
            // Expected behavior - concurrent processing not allowed
        }
    }

    // MARK: - Error Message Tests

    func testErrorMessages_Localization() {
        // Given
        let errors: [DocumentProcessor.ProcessingError] = [
            .invalidImageData,
            .unsupportedFileFormat,
            .ocrProcessingFailed(NSError(domain: "Test", code: 1)),
            .imagePreprocessingFailed("Test reason"),
            .documentParsingFailed("Test reason"),
            .insufficientTextConfidence,
            .memoryLimitExceeded,
            .processingTimeout,
            .documentTooLarge,
            .securityValidationFailed
        ]

        // When/Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}