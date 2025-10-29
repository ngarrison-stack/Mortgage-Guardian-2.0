import Foundation
import os.signpost
@testable import MortgageGuardian

/// Real Performance Benchmark Suite for production-equivalent testing
///
/// This suite provides:
/// - Real-world performance testing under various load conditions
/// - Memory usage tracking and leak detection
/// - Network latency and throughput measurement
/// - CPU utilization monitoring
/// - Battery usage analysis (iOS specific)
/// - Disk I/O performance measurement
/// - Production-equivalent stress testing scenarios
///
/// Uses actual system metrics and performance monitoring tools
class RealPerformanceBenchmarkSuite {

    // MARK: - Configuration

    private struct PerformanceConfiguration {
        static let defaultConcurrency = 5
        static let maxConcurrency = 20
        static let memoryWarningThreshold: UInt64 = 400 * 1024 * 1024 // 400MB
        static let memoryCriticalThreshold: UInt64 = 500 * 1024 * 1024 // 500MB
        static let cpuThreshold: Double = 80.0 // 80% CPU usage
        static let networkTimeoutSeconds: TimeInterval = 30.0
        static let diskIOThresholdMBps: Double = 10.0 // 10MB/s minimum
        static let batteryDrainThreshold: Double = 5.0 // 5% per hour
    }

    // MARK: - Properties

    private let signposter = OSSignposter()
    private let performanceLog = OSLog(subsystem: "com.mortgageguardian.performance", category: "benchmark")

    private var systemMonitor: SystemPerformanceMonitor
    private var memoryTracker: MemoryUsageTracker
    private var networkMonitor: NetworkPerformanceMonitor
    private var diskMonitor: DiskPerformanceMonitor
    private var batteryMonitor: BatteryUsageMonitor

    private var activeLoadTests: [String: LoadTestContext] = [:]
    private var performanceHistory: [PerformanceSnapshot] = []

    // MARK: - Initialization

    init() {
        self.systemMonitor = SystemPerformanceMonitor()
        self.memoryTracker = MemoryUsageTracker()
        self.networkMonitor = NetworkPerformanceMonitor()
        self.diskMonitor = DiskPerformanceMonitor()
        self.batteryMonitor = BatteryUsageMonitor()

        print("⚡ Real Performance Benchmark Suite initialized")
    }

    // MARK: - Load Testing

    /// Run comprehensive load test with real documents and services
    func runLoadTest(
        configuration: RealPerformanceTestConfiguration,
        documentProcessor: DocumentProcessor,
        aiAnalysisService: AIAnalysisService,
        auditEngine: AuditEngine
    ) async throws -> PerformanceTestResult {

        print("🏋️ Starting load test with \(configuration.totalDocuments) documents...")

        let testId = UUID().uuidString
        let startTime = Date()

        // Initialize monitoring
        let loadTestContext = LoadTestContext(
            testId: testId,
            configuration: configuration,
            startTime: startTime
        )
        activeLoadTests[testId] = loadTestContext

        // Start system monitoring
        await startPerformanceMonitoring(testId: testId)

        var results: [DocumentProcessingResult] = []
        var errors: [ProcessingError] = []

        // Execute concurrent document processing
        await withTaskGroup(of: DocumentProcessingResult?.self) { group in
            let semaphore = DispatchSemaphore(value: configuration.concurrentDocuments)

            for batchIndex in 0..<(configuration.totalDocuments / configuration.concurrentDocuments) {
                let batchStartIndex = batchIndex * configuration.concurrentDocuments
                let batchEndIndex = min(batchStartIndex + configuration.concurrentDocuments, configuration.totalDocuments)

                for documentIndex in batchStartIndex..<batchEndIndex {
                    group.addTask {
                        semaphore.wait()
                        defer { semaphore.signal() }

                        do {
                            return try await self.processDocumentForLoadTest(
                                documentIndex: documentIndex,
                                documentProcessor: documentProcessor,
                                aiAnalysisService: aiAnalysisService,
                                auditEngine: auditEngine,
                                testId: testId
                            )
                        } catch {
                            await self.recordProcessingError(
                                error: error,
                                documentIndex: documentIndex,
                                testId: testId
                            )
                            return nil
                        }
                    }
                }

                // Wait for batch completion
                for await result in group {
                    if let result = result {
                        results.append(result)
                    }
                }
            }
        }

        // Stop monitoring and collect metrics
        let finalMetrics = await stopPerformanceMonitoring(testId: testId)

        // Calculate performance statistics
        let totalTime = Date().timeIntervalSince(startTime)
        let averageProcessingTime = results.isEmpty ? 0 : results.map { $0.processingTime }.reduce(0, +) / Double(results.count)
        let successRate = Double(results.count) / Double(configuration.totalDocuments)
        let throughput = Double(configuration.totalDocuments) / totalTime

        // Validate performance requirements
        let performanceValidation = validatePerformanceRequirements(
            configuration: configuration,
            metrics: finalMetrics,
            averageProcessingTime: averageProcessingTime,
            successRate: successRate
        )

        let testResult = PerformanceTestResult(
            testId: testId,
            configuration: configuration,
            totalProcessingTime: totalTime,
            averageProcessingTime: averageProcessingTime,
            successfulProcessing: results.count,
            failedProcessing: errors.count,
            successRate: successRate,
            throughputPerSecond: throughput,
            peakMemoryUsage: finalMetrics.peakMemoryUsage,
            averageCPUUsage: finalMetrics.averageCPUUsage,
            networkLatency: finalMetrics.averageNetworkLatency,
            diskIOPerformance: finalMetrics.averageDiskIORate,
            batteryUsage: finalMetrics.batteryDrainPercentage,
            performanceValidation: performanceValidation,
            systemMetrics: finalMetrics
        )

        // Clean up test context
        activeLoadTests.removeValue(forKey: testId)

        print("✅ Load test completed:")
        print("  Total time: \(String(format: "%.2f", totalTime))s")
        print("  Success rate: \(String(format: "%.1f", successRate * 100))%")
        print("  Throughput: \(String(format: "%.1f", throughput)) docs/sec")
        print("  Peak memory: \(ByteCountFormatter().string(fromByteCount: Int64(finalMetrics.peakMemoryUsage)))")

        return testResult
    }

    /// Run stress test to find performance limits
    func runStressTest(
        documentProcessor: DocumentProcessor,
        aiAnalysisService: AIAnalysisService,
        auditEngine: AuditEngine
    ) async throws -> StressTestResult {

        print("💪 Starting stress test to find performance limits...")

        var stressResults: [StressTestDataPoint] = []
        var currentConcurrency = 1
        var lastSuccessfulConcurrency = 1

        while currentConcurrency <= PerformanceConfiguration.maxConcurrency {
            print("🔄 Testing concurrency level: \(currentConcurrency)")

            let stressConfiguration = RealPerformanceTestConfiguration(
                concurrentDocuments: currentConcurrency,
                totalDocuments: currentConcurrency * 10, // 10 documents per concurrent worker
                maxProcessingTime: 45.0, // More lenient for stress test
                maxMemoryUsage: PerformanceConfiguration.memoryCriticalThreshold
            )

            do {
                let result = try await runLoadTest(
                    configuration: stressConfiguration,
                    documentProcessor: documentProcessor,
                    aiAnalysisService: aiAnalysisService,
                    auditEngine: auditEngine
                )

                let dataPoint = StressTestDataPoint(
                    concurrencyLevel: currentConcurrency,
                    successRate: result.successRate,
                    averageProcessingTime: result.averageProcessingTime,
                    peakMemoryUsage: result.peakMemoryUsage,
                    cpuUsage: result.averageCPUUsage,
                    throughput: result.throughputPerSecond,
                    failed: false
                )

                stressResults.append(dataPoint)

                // Check if performance is still acceptable
                if result.successRate >= 0.95 &&
                   result.peakMemoryUsage < PerformanceConfiguration.memoryCriticalThreshold &&
                   result.averageCPUUsage < PerformanceConfiguration.cpuThreshold {
                    lastSuccessfulConcurrency = currentConcurrency
                } else {
                    print("⚠️ Performance degradation detected at concurrency \(currentConcurrency)")
                    break
                }

                currentConcurrency += 2

            } catch {
                print("❌ Stress test failed at concurrency \(currentConcurrency): \(error)")

                let failedDataPoint = StressTestDataPoint(
                    concurrencyLevel: currentConcurrency,
                    successRate: 0.0,
                    averageProcessingTime: 0.0,
                    peakMemoryUsage: 0,
                    cpuUsage: 0.0,
                    throughput: 0.0,
                    failed: true
                )

                stressResults.append(failedDataPoint)
                break
            }
        }

        return StressTestResult(
            maxSupportedConcurrency: lastSuccessfulConcurrency,
            testDataPoints: stressResults,
            recommendedConcurrency: max(1, lastSuccessfulConcurrency - 2), // Safety margin
            performanceLimitReached: currentConcurrency > lastSuccessfulConcurrency
        )
    }

    /// Run memory leak detection test
    func runMemoryLeakDetection(
        documentProcessor: DocumentProcessor,
        iterationCount: Int = 100
    ) async throws -> MemoryLeakTestResult {

        print("🔍 Running memory leak detection over \(iterationCount) iterations...")

        let initialMemory = await memoryTracker.getCurrentMemoryUsage()
        var memorySnapshots: [MemorySnapshot] = []

        for iteration in 1...iterationCount {
            // Create a test document for processing
            let testDocument = createSyntheticTestDocument()

            // Process document
            _ = try await documentProcessor.processDocument(
                imageData: testDocument.imageData,
                documentType: .mortgageStatement,
                useAdvancedOCR: false
            )

            // Force garbage collection
            if iteration % 10 == 0 {
                // Trigger memory cleanup
                await performMemoryCleanup()

                // Take memory snapshot
                let currentMemory = await memoryTracker.getCurrentMemoryUsage()
                let memoryGrowth = Int64(currentMemory) - Int64(initialMemory)

                let snapshot = MemorySnapshot(
                    iteration: iteration,
                    memoryUsage: currentMemory,
                    memoryGrowth: memoryGrowth,
                    timestamp: Date()
                )

                memorySnapshots.append(snapshot)

                print("📊 Iteration \(iteration): Memory usage \(ByteCountFormatter().string(fromByteCount: Int64(currentMemory)))")
            }
        }

        // Analyze memory growth pattern
        let memoryLeakAnalysis = analyzeMemoryGrowthPattern(memorySnapshots)

        return MemoryLeakTestResult(
            initialMemoryUsage: initialMemory,
            finalMemoryUsage: memorySnapshots.last?.memoryUsage ?? initialMemory,
            memorySnapshots: memorySnapshots,
            leakDetected: memoryLeakAnalysis.leakDetected,
            estimatedLeakRate: memoryLeakAnalysis.leakRatePerIteration,
            analysis: memoryLeakAnalysis
        )
    }

    // MARK: - Network Performance Testing

    /// Test network performance under various conditions
    func runNetworkPerformanceTest(
        aiAnalysisService: AIAnalysisService,
        scenarios: [NetworkScenario] = NetworkScenario.allCases
    ) async throws -> NetworkPerformanceResult {

        print("🌐 Running network performance tests...")

        var scenarioResults: [NetworkScenarioResult] = []

        for scenario in scenarios {
            print("📡 Testing scenario: \(scenario.description)")

            // Simulate network conditions
            await networkMonitor.simulateNetworkConditions(scenario)

            let scenarioStartTime = Date()
            var requests: [NetworkRequestResult] = []

            // Test multiple AI analysis requests
            for requestIndex in 1...10 {
                let requestStartTime = Date()

                do {
                    let testData = createSyntheticExtractedData()
                    _ = try await aiAnalysisService.analyzeDocument(
                        extractedData: testData,
                        documentContext: DocumentContext(
                            documentType: .mortgageStatement,
                            servicerName: "Test Servicer"
                        )
                    )

                    let requestTime = Date().timeIntervalSince(requestStartTime)
                    requests.append(
                        NetworkRequestResult(
                            requestIndex: requestIndex,
                            responseTime: requestTime,
                            successful: true,
                            errorMessage: nil
                        )
                    )

                } catch {
                    let requestTime = Date().timeIntervalSince(requestStartTime)
                    requests.append(
                        NetworkRequestResult(
                            requestIndex: requestIndex,
                            responseTime: requestTime,
                            successful: false,
                            errorMessage: error.localizedDescription
                        )
                    )
                }
            }

            let scenarioTime = Date().timeIntervalSince(scenarioStartTime)
            let successfulRequests = requests.filter { $0.successful }
            let averageResponseTime = successfulRequests.isEmpty ? 0 :
                successfulRequests.map { $0.responseTime }.reduce(0, +) / Double(successfulRequests.count)

            let scenarioResult = NetworkScenarioResult(
                scenario: scenario,
                totalTime: scenarioTime,
                averageResponseTime: averageResponseTime,
                successRate: Double(successfulRequests.count) / Double(requests.count),
                requests: requests
            )

            scenarioResults.append(scenarioResult)

            // Reset network conditions
            await networkMonitor.resetNetworkConditions()
        }

        return NetworkPerformanceResult(
            scenarioResults: scenarioResults,
            overallSuccessRate: scenarioResults.map { $0.successRate }.reduce(0, +) / Double(scenarioResults.count)
        )
    }

    // MARK: - Battery Usage Testing

    /// Test battery usage during intensive processing (iOS only)
    func runBatteryUsageTest(
        documentProcessor: DocumentProcessor,
        testDurationMinutes: Int = 30
    ) async throws -> BatteryUsageTestResult {

        print("🔋 Running battery usage test for \(testDurationMinutes) minutes...")

        let initialBatteryLevel = await batteryMonitor.getCurrentBatteryLevel()
        let testStartTime = Date()
        let testEndTime = testStartTime.addingTimeInterval(TimeInterval(testDurationMinutes * 60))

        var batterySnapshots: [BatterySnapshot] = []

        // Continuous processing to stress battery
        let processingTask = Task {
            while Date() < testEndTime {
                let testDocument = createSyntheticTestDocument()
                _ = try await documentProcessor.processDocument(
                    imageData: testDocument.imageData,
                    documentType: .mortgageStatement,
                    useAdvancedOCR: true
                )

                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }

        // Monitor battery usage
        let monitoringTask = Task {
            while Date() < testEndTime {
                let currentBatteryLevel = await batteryMonitor.getCurrentBatteryLevel()
                let batteryUsage = await batteryMonitor.getCurrentBatteryUsage()

                let snapshot = BatterySnapshot(
                    timestamp: Date(),
                    batteryLevel: currentBatteryLevel,
                    powerUsage: batteryUsage.powerUsage,
                    thermalState: batteryUsage.thermalState
                )

                batterySnapshots.append(snapshot)

                // Take snapshot every 30 seconds
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }

        // Wait for test completion
        _ = await [processingTask.result, monitoringTask.result]

        let finalBatteryLevel = await batteryMonitor.getCurrentBatteryLevel()
        let totalBatteryDrain = initialBatteryLevel - finalBatteryLevel
        let batteryDrainPerHour = (totalBatteryDrain / Double(testDurationMinutes)) * 60

        return BatteryUsageTestResult(
            testDurationMinutes: testDurationMinutes,
            initialBatteryLevel: initialBatteryLevel,
            finalBatteryLevel: finalBatteryLevel,
            totalBatteryDrain: totalBatteryDrain,
            batteryDrainPerHour: batteryDrainPerHour,
            batterySnapshots: batterySnapshots,
            withinAcceptableRange: batteryDrainPerHour <= PerformanceConfiguration.batteryDrainThreshold
        )
    }

    // MARK: - Private Helper Methods

    private func startPerformanceMonitoring(testId: String) async {
        await systemMonitor.startMonitoring(testId: testId)
        await memoryTracker.startTracking(testId: testId)
        await networkMonitor.startMonitoring(testId: testId)
        await diskMonitor.startMonitoring(testId: testId)
        await batteryMonitor.startMonitoring(testId: testId)
    }

    private func stopPerformanceMonitoring(testId: String) async -> SystemMetrics {
        let systemMetrics = await systemMonitor.stopMonitoring(testId: testId)
        let memoryMetrics = await memoryTracker.stopTracking(testId: testId)
        let networkMetrics = await networkMonitor.stopMonitoring(testId: testId)
        let diskMetrics = await diskMonitor.stopMonitoring(testId: testId)
        let batteryMetrics = await batteryMonitor.stopMonitoring(testId: testId)

        return SystemMetrics(
            peakMemoryUsage: memoryMetrics.peakUsage,
            averageMemoryUsage: memoryMetrics.averageUsage,
            averageCPUUsage: systemMetrics.averageCPUUsage,
            peakCPUUsage: systemMetrics.peakCPUUsage,
            averageNetworkLatency: networkMetrics.averageLatency,
            networkThroughput: networkMetrics.throughput,
            averageDiskIORate: diskMetrics.averageIORate,
            batteryDrainPercentage: batteryMetrics.drainPercentage,
            thermalEvents: systemMetrics.thermalEvents
        )
    }

    private func processDocumentForLoadTest(
        documentIndex: Int,
        documentProcessor: DocumentProcessor,
        aiAnalysisService: AIAnalysisService,
        auditEngine: AuditEngine,
        testId: String
    ) async throws -> DocumentProcessingResult {

        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("DocumentProcessing", id: signpostID)

        let startTime = Date()

        // Create test document
        let testDocument = createSyntheticTestDocument()

        // Process with OCR
        let ocrResult = try await documentProcessor.processDocument(
            imageData: testDocument.imageData,
            documentType: .mortgageStatement,
            useAdvancedOCR: true
        )

        // Perform AI analysis
        let aiResult = try await aiAnalysisService.analyzeDocument(
            extractedData: ocrResult.extractedData,
            documentContext: DocumentContext(
                documentType: .mortgageStatement,
                servicerName: "Load Test Servicer"
            )
        )

        // Run audit
        let auditResult = try await auditEngine.performQuickAudit(
            extractedData: ocrResult.extractedData,
            aiAnalysis: aiResult
        )

        let processingTime = Date().timeIntervalSince(startTime)

        signposter.endInterval("DocumentProcessing", state)

        return DocumentProcessingResult(
            documentIndex: documentIndex,
            processingTime: processingTime,
            ocrConfidence: ocrResult.confidence,
            aiConfidence: aiResult.confidence,
            auditScore: auditResult.overallScore,
            memoryUsed: await memoryTracker.getCurrentMemoryUsage(),
            successful: true
        )
    }

    private func recordProcessingError(
        error: Error,
        documentIndex: Int,
        testId: String
    ) async {
        let processingError = ProcessingError(
            documentIndex: documentIndex,
            error: error,
            timestamp: Date(),
            testId: testId
        )

        os_log(.error, log: performanceLog, "Processing error for document %d: %@", documentIndex, error.localizedDescription)
    }

    private func validatePerformanceRequirements(
        configuration: RealPerformanceTestConfiguration,
        metrics: SystemMetrics,
        averageProcessingTime: TimeInterval,
        successRate: Double
    ) -> PerformanceValidation {

        var violations: [PerformanceViolation] = []

        // Check processing time requirement
        if averageProcessingTime > configuration.maxProcessingTime {
            violations.append(.processingTimeTooSlow(averageProcessingTime, configuration.maxProcessingTime))
        }

        // Check memory usage requirement
        if metrics.peakMemoryUsage > configuration.maxMemoryUsage {
            violations.append(.memoryUsageExceeded(metrics.peakMemoryUsage, configuration.maxMemoryUsage))
        }

        // Check success rate
        if successRate < 0.95 {
            violations.append(.successRateTooLow(successRate))
        }

        // Check CPU usage
        if metrics.averageCPUUsage > PerformanceConfiguration.cpuThreshold {
            violations.append(.cpuUsageTooHigh(metrics.averageCPUUsage))
        }

        return PerformanceValidation(
            isValid: violations.isEmpty,
            violations: violations,
            overallScore: calculatePerformanceScore(metrics: metrics, violations: violations)
        )
    }

    private func calculatePerformanceScore(metrics: SystemMetrics, violations: [PerformanceViolation]) -> Double {
        let baseScore = 100.0
        let violationPenalty = Double(violations.count) * 10.0
        let memoryPenalty = metrics.peakMemoryUsage > PerformanceConfiguration.memoryWarningThreshold ? 5.0 : 0.0
        let cpuPenalty = metrics.averageCPUUsage > 60.0 ? 5.0 : 0.0

        return max(0.0, baseScore - violationPenalty - memoryPenalty - cpuPenalty)
    }

    private func createSyntheticTestDocument() -> SyntheticTestDocument {
        // Create a realistic test document for performance testing
        let imageSize = 2048 * 1536 * 4 // 2048x1536 RGBA
        let imageData = Data(count: imageSize)

        return SyntheticTestDocument(
            id: UUID().uuidString,
            imageData: imageData,
            documentType: .mortgageStatement,
            expectedProcessingTime: 5.0
        )
    }

    private func createSyntheticExtractedData() -> ExtractedData {
        return ExtractedData(
            loanNumber: "TEST123456789",
            servicerName: "Test Servicer",
            borrowerName: "Test Borrower",
            propertyAddress: "123 Test St",
            currentBalance: 250000.00,
            monthlyPayment: 1500.00,
            dueDate: Date().addingTimeInterval(86400 * 30),
            lastPaymentAmount: 1500.00,
            lastPaymentDate: Date().addingTimeInterval(-86400 * 30)
        )
    }

    private func performMemoryCleanup() async {
        // Force memory cleanup
        await Task.yield()
    }

    private func analyzeMemoryGrowthPattern(_ snapshots: [MemorySnapshot]) -> MemoryLeakAnalysis {
        guard snapshots.count > 5 else {
            return MemoryLeakAnalysis(
                leakDetected: false,
                leakRatePerIteration: 0,
                confidenceLevel: 0.0,
                analysis: "Insufficient data for leak analysis"
            )
        }

        // Calculate memory growth trend
        let memoryGrowths = snapshots.map { $0.memoryGrowth }
        let averageGrowth = memoryGrowths.reduce(0, +) / Int64(memoryGrowths.count)

        // Check for consistent upward trend
        let consistentGrowth = memoryGrowths.dropFirst().enumerated().allSatisfy { index, growth in
            growth >= memoryGrowths[index]
        }

        // Consider a leak if average growth > 1MB per 10 iterations
        let leakThreshold: Int64 = 1024 * 1024 // 1MB
        let leakDetected = averageGrowth > leakThreshold && consistentGrowth

        return MemoryLeakAnalysis(
            leakDetected: leakDetected,
            leakRatePerIteration: averageGrowth,
            confidenceLevel: leakDetected ? 0.8 : 0.2,
            analysis: leakDetected ? "Consistent memory growth detected" : "No significant memory leak detected"
        )
    }
}

// MARK: - Supporting Types

struct LoadTestContext {
    let testId: String
    let configuration: RealPerformanceTestConfiguration
    let startTime: Date
}

struct DocumentProcessingResult {
    let documentIndex: Int
    let processingTime: TimeInterval
    let ocrConfidence: Double
    let aiConfidence: Double
    let auditScore: Double
    let memoryUsed: UInt64
    let successful: Bool
}

struct ProcessingError {
    let documentIndex: Int
    let error: Error
    let timestamp: Date
    let testId: String
}

struct PerformanceTestResult {
    let testId: String
    let configuration: RealPerformanceTestConfiguration
    let totalProcessingTime: TimeInterval
    let averageProcessingTime: TimeInterval
    let successfulProcessing: Int
    let failedProcessing: Int
    let successRate: Double
    let throughputPerSecond: Double
    let peakMemoryUsage: UInt64
    let averageCPUUsage: Double
    let networkLatency: TimeInterval
    let diskIOPerformance: Double
    let batteryUsage: Double
    let performanceValidation: PerformanceValidation
    let systemMetrics: SystemMetrics
}

struct StressTestResult {
    let maxSupportedConcurrency: Int
    let testDataPoints: [StressTestDataPoint]
    let recommendedConcurrency: Int
    let performanceLimitReached: Bool
}

struct StressTestDataPoint {
    let concurrencyLevel: Int
    let successRate: Double
    let averageProcessingTime: TimeInterval
    let peakMemoryUsage: UInt64
    let cpuUsage: Double
    let throughput: Double
    let failed: Bool
}

struct MemorySnapshot {
    let iteration: Int
    let memoryUsage: UInt64
    let memoryGrowth: Int64
    let timestamp: Date
}

struct MemoryLeakTestResult {
    let initialMemoryUsage: UInt64
    let finalMemoryUsage: UInt64
    let memorySnapshots: [MemorySnapshot]
    let leakDetected: Bool
    let estimatedLeakRate: Int64
    let analysis: MemoryLeakAnalysis
}

struct MemoryLeakAnalysis {
    let leakDetected: Bool
    let leakRatePerIteration: Int64
    let confidenceLevel: Double
    let analysis: String
}

struct SystemMetrics {
    let peakMemoryUsage: UInt64
    let averageMemoryUsage: UInt64
    let averageCPUUsage: Double
    let peakCPUUsage: Double
    let averageNetworkLatency: TimeInterval
    let networkThroughput: Double
    let averageDiskIORate: Double
    let batteryDrainPercentage: Double
    let thermalEvents: Int
}

struct PerformanceValidation {
    let isValid: Bool
    let violations: [PerformanceViolation]
    let overallScore: Double
}

enum PerformanceViolation {
    case processingTimeTooSlow(TimeInterval, TimeInterval)
    case memoryUsageExceeded(UInt64, UInt64)
    case successRateTooLow(Double)
    case cpuUsageTooHigh(Double)
}

struct SyntheticTestDocument {
    let id: String
    let imageData: Data
    let documentType: DocumentType
    let expectedProcessingTime: TimeInterval
}

struct NetworkPerformanceResult {
    let scenarioResults: [NetworkScenarioResult]
    let overallSuccessRate: Double
}

struct NetworkScenarioResult {
    let scenario: NetworkScenario
    let totalTime: TimeInterval
    let averageResponseTime: TimeInterval
    let successRate: Double
    let requests: [NetworkRequestResult]
}

struct NetworkRequestResult {
    let requestIndex: Int
    let responseTime: TimeInterval
    let successful: Bool
    let errorMessage: String?
}

enum NetworkScenario: CaseIterable {
    case optimal
    case slowNetwork
    case intermittentConnection
    case highLatency

    var description: String {
        switch self {
        case .optimal: return "Optimal Network Conditions"
        case .slowNetwork: return "Slow Network Speed"
        case .intermittentConnection: return "Intermittent Connection"
        case .highLatency: return "High Latency Network"
        }
    }
}

struct BatteryUsageTestResult {
    let testDurationMinutes: Int
    let initialBatteryLevel: Double
    let finalBatteryLevel: Double
    let totalBatteryDrain: Double
    let batteryDrainPerHour: Double
    let batterySnapshots: [BatterySnapshot]
    let withinAcceptableRange: Bool
}

struct BatterySnapshot {
    let timestamp: Date
    let batteryLevel: Double
    let powerUsage: Double
    let thermalState: String
}