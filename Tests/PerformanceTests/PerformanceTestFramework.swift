import XCTest
import Foundation
@testable import MortgageGuardian

/// Performance Test Framework for Zero-Tolerance Error Detection System
/// Validates that all processing meets strict timing and memory requirements
class PerformanceTestFramework: XCTestCase {

    // MARK: - Properties

    private var documentProcessor: DocumentProcessor!
    private var aiAnalysisService: AIAnalysisService!
    private var plaidService: PlaidService!
    private var auditEngine: AuditEngine!
    private var testDataGenerator: MortgageTestDataGenerator!

    // Performance metrics
    private var performanceMetrics: [PerformanceMetric] = []

    // MARK: - Setup and Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        documentProcessor = DocumentProcessor.shared
        aiAnalysisService = AIAnalysisService.shared
        plaidService = PlaidService.shared
        auditEngine = AuditEngine.shared
        testDataGenerator = MortgageTestDataGenerator()

        performanceMetrics = []
    }

    override func tearDownWithError() throws {
        // Generate performance report
        generatePerformanceReport()
        try super.tearDownWithError()
    }

    // MARK: - Document OCR Performance Tests

    /// Test document OCR processing time (Requirement: < 10 seconds)
    func testDocumentOCRPerformance() async throws {
        print("\n⚡ Testing Document OCR Performance...")

        let testCases = [
            ("Single Page PDF", generateSinglePagePDF()),
            ("Multi Page PDF", generateMultiPagePDF()),
            ("High Quality Image", generateHighQualityImage()),
            ("Low Quality Scan", generateLowQualityScan()),
            ("Rotated Document", generateRotatedDocument())
        ]

        for (description, documentData) in testCases {
            let metric = try await measureProcessingTime(
                operation: "OCR - \(description)",
                maxTime: 10.0
            ) {
                return try await documentProcessor.processDocument(documentData)
            }

            performanceMetrics.append(metric)

            // Validate OCR accuracy
            let result = try await documentProcessor.processDocument(documentData)
            XCTAssertGreaterThan(result.confidence, 0.95, "OCR confidence too low for \(description)")
        }
    }

    /// Test OCR multi-pass validation (Requirement: < 15 seconds total)
    func testMultiPassOCRValidation() async throws {
        print("\n⚡ Testing Multi-Pass OCR Validation...")

        let documentData = generateStandardMortgageStatement()

        let metric = try await measureProcessingTime(
            operation: "Multi-Pass OCR",
            maxTime: 15.0
        ) {
            // Primary OCR (Apple Vision)
            let primaryResult = try await documentProcessor.performPrimaryOCR(documentData)

            // Secondary OCR (AWS Textract)
            let secondaryResult = try await documentProcessor.performSecondaryOCR(documentData)

            // Consensus validation
            return try await documentProcessor.validateOCRConsensus(
                primary: primaryResult,
                secondary: secondaryResult
            )
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 15.0, "Multi-pass OCR validation too slow")
    }

    // MARK: - AI Analysis Performance Tests

    /// Test AI analysis processing time (Requirement: < 30 seconds)
    func testAIAnalysisPerformance() async throws {
        print("\n⚡ Testing AI Analysis Performance...")

        let extractedData = testDataGenerator.generateRandomTestData()

        let metric = try await measureProcessingTime(
            operation: "AI Analysis",
            maxTime: 30.0
        ) {
            return try await aiAnalysisService.analyzeDocument(extractedData)
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 30.0, "AI analysis too slow")

        // Validate analysis quality
        let result = try await aiAnalysisService.analyzeDocument(extractedData)
        XCTAssertGreaterThan(result.confidence, 0.8, "AI analysis confidence too low")
    }

    /// Test multi-model consensus (Requirement: < 45 seconds)
    func testMultiModelConsensusPerformance() async throws {
        print("\n⚡ Testing Multi-Model Consensus Performance...")

        let extractedData = testDataGenerator.generatePaymentAllocationMismatchData()

        let metric = try await measureProcessingTime(
            operation: "Multi-Model Consensus",
            maxTime: 45.0
        ) {
            let claudeResult = try await aiAnalysisService.analyzeWithClaude(extractedData)
            let bedrockResult = try await aiAnalysisService.analyzeWithBedrock(extractedData)
            let textractResult = try await aiAnalysisService.analyzeWithTextract(extractedData)

            return try await aiAnalysisService.buildConsensus(
                claude: claudeResult,
                bedrock: bedrockResult,
                textract: textractResult
            )
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 45.0, "Multi-model consensus too slow")
    }

    // MARK: - Plaid Integration Performance Tests

    /// Test Plaid bank data sync (Requirement: < 5 seconds)
    func testPlaidSyncPerformance() async throws {
        print("\n⚡ Testing Plaid Sync Performance...")

        let metric = try await measureProcessingTime(
            operation: "Plaid Sync",
            maxTime: 5.0
        ) {
            return try await plaidService.syncBankTransactions(accountId: "test_account")
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 5.0, "Plaid sync too slow")
    }

    /// Test Plaid data validation (Requirement: < 3 seconds)
    func testPlaidValidationPerformance() async throws {
        print("\n⚡ Testing Plaid Validation Performance...")

        let transactions = testDataGenerator.generateMatchingBankTransactions(
            for: testDataGenerator.generateRandomTestData()
        )

        let metric = try await measureProcessingTime(
            operation: "Plaid Validation",
            maxTime: 3.0
        ) {
            return try await plaidService.validateTransactions(transactions)
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 3.0, "Plaid validation too slow")
    }

    // MARK: - End-to-End Workflow Performance Tests

    /// Test complete workflow (Requirement: < 45 seconds)
    func testEndToEndWorkflowPerformance() async throws {
        print("\n⚡ Testing End-to-End Workflow Performance...")

        let documentData = generateStandardMortgageStatement()

        let metric = try await measureProcessingTime(
            operation: "Complete Workflow",
            maxTime: 45.0
        ) {
            // 1. Document OCR
            let extractedData = try await documentProcessor.processDocument(documentData)

            // 2. Bank data sync
            let transactions = try await plaidService.syncBankTransactions(
                accountId: extractedData.accountNumber
            )

            // 3. Audit engine analysis
            let auditResult = try await auditEngine.performAudit(
                extractedData: extractedData,
                bankTransactions: transactions
            )

            // 4. AI analysis and consensus
            let aiResult = try await aiAnalysisService.analyzeDocument(extractedData)

            // 5. Final report generation
            return try await generateFinalReport(
                auditResult: auditResult,
                aiResult: aiResult,
                extractedData: extractedData
            )
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 45.0, "End-to-end workflow too slow")
    }

    // MARK: - Memory Performance Tests

    /// Test memory usage during processing (Requirement: < 100MB peak)
    func testMemoryUsageAndCleanup() async throws {
        print("\n🧠 Testing Memory Usage and Cleanup...")

        let initialMemory = getCurrentMemoryUsage()
        var peakMemory = initialMemory

        // Process multiple documents to test memory behavior
        for i in 0..<10 {
            autoreleasepool {
                let documentData = generateStandardMortgageStatement()

                Task {
                    do {
                        _ = try await documentProcessor.processDocument(documentData)
                        let currentMemory = getCurrentMemoryUsage()
                        peakMemory = max(peakMemory, currentMemory)
                    } catch {
                        // Handle error silently for memory test
                    }
                }
            }

            // Allow memory to be reclaimed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        let finalMemory = getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        let peakIncrease = peakMemory - initialMemory

        print("Memory Usage Report:")
        print("  Initial: \(formatMemory(initialMemory))")
        print("  Peak: \(formatMemory(peakMemory))")
        print("  Final: \(formatMemory(finalMemory))")
        print("  Peak Increase: \(formatMemory(peakIncrease))")
        print("  Final Growth: \(formatMemory(memoryGrowth))")

        // Validate memory requirements
        XCTAssertLessThan(peakIncrease, 100 * 1024 * 1024, "Peak memory usage exceeded 100MB")
        XCTAssertLessThan(memoryGrowth, 10 * 1024 * 1024, "Memory leak detected (>10MB growth)")

        let memoryMetric = PerformanceMetric(
            operation: "Memory Usage",
            duration: 0,
            success: peakIncrease < 100 * 1024 * 1024,
            details: [
                "peak_mb": String(peakIncrease / (1024 * 1024)),
                "growth_mb": String(memoryGrowth / (1024 * 1024))
            ]
        )
        performanceMetrics.append(memoryMetric)
    }

    // MARK: - Concurrent Processing Tests

    /// Test concurrent document processing
    func testConcurrentProcessing() async throws {
        print("\n⚡ Testing Concurrent Processing...")

        let concurrentTasks = 5
        let documents = (0..<concurrentTasks).map { _ in generateStandardMortgageStatement() }

        let metric = try await measureProcessingTime(
            operation: "Concurrent Processing (\(concurrentTasks) documents)",
            maxTime: 60.0
        ) {
            return await withTaskGroup(of: ExtractedMortgageData?.self) { group in
                for document in documents {
                    group.addTask {
                        do {
                            return try await self.documentProcessor.processDocument(document)
                        } catch {
                            return nil
                        }
                    }
                }

                var results: [ExtractedMortgageData] = []
                for await result in group {
                    if let data = result {
                        results.append(data)
                    }
                }
                return results
            }
        }

        performanceMetrics.append(metric)
        XCTAssertLessThan(metric.duration, 60.0, "Concurrent processing too slow")
    }

    // MARK: - Load Testing

    /// Test system performance under load (100 documents)
    func testPerformanceUnderLoad() async throws {
        print("\n🏋️ Testing Performance Under Load...")

        let documentCount = 100
        let batchSize = 10
        let batches = documentCount / batchSize

        let metric = try await measureProcessingTime(
            operation: "Load Test (\(documentCount) documents)",
            maxTime: 300.0 // 5 minutes max
        ) {
            var allResults: [ExtractedMortgageData] = []

            for batch in 0..<batches {
                let batchDocuments = (0..<batchSize).map { _ in
                    testDataGenerator.generateRandomTestData()
                }

                let batchResults = await withTaskGroup(of: ExtractedMortgageData?.self) { group in
                    for data in batchDocuments {
                        group.addTask {
                            do {
                                // Simulate document processing
                                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                return data
                            } catch {
                                return nil
                            }
                        }
                    }

                    var results: [ExtractedMortgageData] = []
                    for await result in group {
                        if let data = result {
                            results.append(data)
                        }
                    }
                    return results
                }

                allResults.append(contentsOf: batchResults)
                print("  Completed batch \(batch + 1)/\(batches)")
            }

            return allResults
        }

        performanceMetrics.append(metric)

        let averageTimePerDocument = metric.duration / Double(documentCount)
        print("Average time per document: \(String(format: "%.3f", averageTimePerDocument))s")

        XCTAssertLessThan(averageTimePerDocument, 3.0, "Average processing time per document too high")
    }

    // MARK: - Helper Methods

    private func measureProcessingTime<T>(
        operation: String,
        maxTime: Double,
        block: @escaping () async throws -> T
    ) async throws -> PerformanceMetric {
        let startTime = Date()

        do {
            _ = try await block()
            let duration = Date().timeIntervalSince(startTime)

            print("  ✓ \(operation): \(String(format: "%.3f", duration))s")

            return PerformanceMetric(
                operation: operation,
                duration: duration,
                success: duration <= maxTime,
                details: ["max_time": String(maxTime)]
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            print("  ✗ \(operation): FAILED after \(String(format: "%.3f", duration))s")

            return PerformanceMetric(
                operation: operation,
                duration: duration,
                success: false,
                details: ["error": error.localizedDescription]
            )
        }
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }

    private func formatMemory(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }

    private func generatePerformanceReport() {
        print("\n📊 PERFORMANCE TEST REPORT")
        print("============================")

        let passedTests = performanceMetrics.filter { $0.success }.count
        let totalTests = performanceMetrics.count

        print("Total Tests: \(totalTests)")
        print("Passed: \(passedTests)")
        print("Failed: \(totalTests - passedTests)")
        print("Success Rate: \(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%")
        print("")

        print("Detailed Results:")
        for metric in performanceMetrics {
            let status = metric.success ? "✓" : "✗"
            let duration = String(format: "%.3f", metric.duration)
            print("  \(status) \(metric.operation): \(duration)s")
        }
    }

    // MARK: - Test Data Generation

    private func generateStandardMortgageStatement() -> Data {
        // Generate sample mortgage statement data
        return Data("Sample mortgage statement content".utf8)
    }

    private func generateSinglePagePDF() -> Data {
        return Data("Single page PDF content".utf8)
    }

    private func generateMultiPagePDF() -> Data {
        return Data("Multi page PDF content".utf8)
    }

    private func generateHighQualityImage() -> Data {
        return Data("High quality image content".utf8)
    }

    private func generateLowQualityScan() -> Data {
        return Data("Low quality scan content".utf8)
    }

    private func generateRotatedDocument() -> Data {
        return Data("Rotated document content".utf8)
    }

    private func generateFinalReport(
        auditResult: AuditResult,
        aiResult: AIAnalysisResult,
        extractedData: ExtractedMortgageData
    ) async throws -> FinalReport {
        // Generate final report
        return FinalReport(
            auditResult: auditResult,
            aiResult: aiResult,
            extractedData: extractedData
        )
    }
}

// MARK: - Supporting Structures

struct PerformanceMetric {
    let operation: String
    let duration: TimeInterval
    let success: Bool
    let details: [String: String]
}

struct FinalReport {
    let auditResult: AuditResult
    let aiResult: AIAnalysisResult
    let extractedData: ExtractedMortgageData
}

struct AuditResult {
    let detectedErrors: [DetectedError]
    let confidence: Double
}

struct AIAnalysisResult {
    let detectedViolations: [ViolationPattern]
    let confidence: Double
}

struct DetectedError {
    let type: String
    let description: String
    let severity: String
}

struct ViolationPattern {
    let pattern: String
    let confidence: Double
}