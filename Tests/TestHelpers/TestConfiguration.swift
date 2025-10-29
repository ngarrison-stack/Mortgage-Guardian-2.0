import Foundation
import XCTest
@testable import MortgageGuardian

/// Test configuration and benchmarking setup for Mortgage Guardian testing framework
/// Provides performance benchmarking, code coverage tracking, and test quality metrics

// MARK: - Performance Benchmarking

public class PerformanceBenchmark {

    public struct BenchmarkResult {
        let operationName: String
        let averageTime: TimeInterval
        let minTime: TimeInterval
        let maxTime: TimeInterval
        let iterations: Int
        let memoryUsage: UInt64?
        let timestamp: Date

        public var description: String {
            let memoryInfo = memoryUsage.map { " Memory: \(ByteCountFormatter().string(fromByteCount: Int64($0)))" } ?? ""
            return """
            📊 \(operationName):
               Average: \(String(format: "%.4f", averageTime))s
               Range: \(String(format: "%.4f", minTime))s - \(String(format: "%.4f", maxTime))s
               Iterations: \(iterations)\(memoryInfo)
            """
        }
    }

    private static var benchmarkResults: [BenchmarkResult] = []
    private static let benchmarkQueue = DispatchQueue(label: "benchmark.queue", qos: .utility)

    /// Benchmark an async operation
    public static func benchmark<T>(
        _ operationName: String,
        iterations: Int = 10,
        warmupIterations: Int = 2,
        operation: @escaping () async throws -> T
    ) async -> BenchmarkResult {

        var measurements: [TimeInterval] = []
        var memoryBefore: UInt64 = 0
        var memoryAfter: UInt64 = 0

        // Warmup
        for _ in 0..<warmupIterations {
            _ = try? await operation()
        }

        // Actual measurements
        for _ in 0..<iterations {
            let startMemory = getCurrentMemoryUsage()
            let startTime = CFAbsoluteTimeGetCurrent()

            _ = try? await operation()

            let endTime = CFAbsoluteTimeGetCurrent()
            let endMemory = getCurrentMemoryUsage()

            measurements.append(endTime - startTime)
            memoryBefore += startMemory
            memoryAfter += endMemory
        }

        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let minTime = measurements.min() ?? 0
        let maxTime = measurements.max() ?? 0
        let memoryDelta = (memoryAfter - memoryBefore) / UInt64(iterations)

        let result = BenchmarkResult(
            operationName: operationName,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            iterations: iterations,
            memoryUsage: memoryDelta > 0 ? memoryDelta : nil,
            timestamp: Date()
        )

        benchmarkQueue.async {
            benchmarkResults.append(result)
        }

        return result
    }

    /// Benchmark a synchronous operation
    public static func benchmark<T>(
        _ operationName: String,
        iterations: Int = 10,
        warmupIterations: Int = 2,
        operation: @escaping () throws -> T
    ) -> BenchmarkResult {

        var measurements: [TimeInterval] = []

        // Warmup
        for _ in 0..<warmupIterations {
            _ = try? operation()
        }

        // Actual measurements
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try? operation()
            let endTime = CFAbsoluteTimeGetCurrent()
            measurements.append(endTime - startTime)
        }

        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let minTime = measurements.min() ?? 0
        let maxTime = measurements.max() ?? 0

        let result = BenchmarkResult(
            operationName: operationName,
            averageTime: averageTime,
            minTime: minTime,
            maxTime: maxTime,
            iterations: iterations,
            memoryUsage: nil,
            timestamp: Date()
        )

        benchmarkQueue.async {
            benchmarkResults.append(result)
        }

        return result
    }

    /// Get all benchmark results
    public static func getAllResults() -> [BenchmarkResult] {
        return benchmarkQueue.sync {
            return benchmarkResults
        }
    }

    /// Generate benchmark report
    public static func generateReport() -> String {
        let results = getAllResults()

        if results.isEmpty {
            return "📊 No benchmark results available"
        }

        let report = """
        📊 PERFORMANCE BENCHMARK REPORT
        Generated: \(DateFormatter.fullDateTime.string(from: Date()))
        Total Operations Benchmarked: \(results.count)

        \(results.map { $0.description }.joined(separator: "\n\n"))

        🏆 SUMMARY:
        Fastest Operation: \(results.min(by: { $0.averageTime < $1.averageTime })?.operationName ?? "N/A")
        Slowest Operation: \(results.max(by: { $0.averageTime < $1.averageTime })?.operationName ?? "N/A")
        """

        return report
    }

    /// Clear all benchmark results
    public static func clearResults() {
        benchmarkQueue.async {
            benchmarkResults.removeAll()
        }
    }

    private static func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Code Coverage Tracking

public class CodeCoverageTracker {

    public struct CoverageReport {
        let totalLines: Int
        let coveredLines: Int
        let coveragePercentage: Double
        let uncoveredAreas: [String]
        let timestamp: Date

        public var description: String {
            return """
            📈 CODE COVERAGE REPORT
            Generated: \(DateFormatter.fullDateTime.string(from: timestamp))

            Total Lines: \(totalLines)
            Covered Lines: \(coveredLines)
            Coverage: \(String(format: "%.1f", coveragePercentage))%

            🎯 TARGET: \(TestConfiguration.coverageThreshold * 100)%
            Status: \(coveragePercentage >= TestConfiguration.coverageThreshold * 100 ? "✅ PASS" : "❌ FAIL")

            \(uncoveredAreas.isEmpty ? "✅ All critical areas covered" : "⚠️ Uncovered Areas:\n\(uncoveredAreas.joined(separator: "\n"))")
            """
        }
    }

    private static var coverageData: [String: Bool] = [:]

    /// Track that a code path was executed
    public static func track(_ identifier: String) {
        coverageData[identifier] = true
    }

    /// Generate coverage report
    public static func generateReport() -> CoverageReport {
        let totalLines = coverageData.count
        let coveredLines = coverageData.values.filter { $0 }.count
        let coveragePercentage = totalLines > 0 ? Double(coveredLines) / Double(totalLines) * 100 : 0

        let uncoveredAreas = coverageData.compactMap { key, covered in
            covered ? nil : key
        }

        return CoverageReport(
            totalLines: totalLines,
            coveredLines: coveredLines,
            coveragePercentage: coveragePercentage,
            uncoveredAreas: uncoveredAreas,
            timestamp: Date()
        )
    }

    /// Clear coverage data
    public static func clearData() {
        coverageData.removeAll()
    }
}

// MARK: - Test Quality Metrics

public class TestQualityMetrics {

    public struct QualityReport {
        let totalTests: Int
        let passedTests: Int
        let failedTests: Int
        let skippedTests: Int
        let averageTestDuration: TimeInterval
        let testCategories: [String: Int]
        let flakiness: Double
        let timestamp: Date

        public var description: String {
            let passRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0

            return """
            🧪 TEST QUALITY REPORT
            Generated: \(DateFormatter.fullDateTime.string(from: timestamp))

            📊 Test Results:
            Total Tests: \(totalTests)
            Passed: \(passedTests) (\(String(format: "%.1f", passRate))%)
            Failed: \(failedTests)
            Skipped: \(skippedTests)

            ⏱️ Performance:
            Average Duration: \(String(format: "%.3f", averageTestDuration))s

            🎯 Categories:
            \(testCategories.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))

            🔄 Flakiness: \(String(format: "%.1f", flakiness))%

            ✅ Quality Score: \(calculateQualityScore(passRate: passRate, flakiness: flakiness))/100
            """
        }

        private func calculateQualityScore(passRate: Double, flakiness: Double) -> Int {
            let baseScore = passRate
            let flakinessPenalty = flakiness * 2 // 2% penalty per 1% flakiness
            return max(0, Int(baseScore - flakinessPenalty))
        }
    }

    private static var testResults: [(name: String, passed: Bool, duration: TimeInterval, category: String)] = []
    private static var testRuns: [String: [Bool]] = [:] // Track multiple runs for flakiness

    /// Record test result
    public static func recordTest(
        name: String,
        passed: Bool,
        duration: TimeInterval,
        category: String = "general"
    ) {
        testResults.append((name: name, passed: passed, duration: duration, category: category))

        // Track for flakiness detection
        if testRuns[name] == nil {
            testRuns[name] = []
        }
        testRuns[name]?.append(passed)
    }

    /// Generate quality report
    public static func generateReport() -> QualityReport {
        let totalTests = testResults.count
        let passedTests = testResults.filter { $0.passed }.count
        let failedTests = testResults.filter { !$0.passed }.count
        let skippedTests = 0 // Would track skipped tests in real implementation

        let averageTestDuration = totalTests > 0
            ? testResults.map { $0.duration }.reduce(0, +) / Double(totalTests)
            : 0

        let testCategories = Dictionary(grouping: testResults, by: { $0.category })
            .mapValues { $0.count }

        let flakiness = calculateFlakiness()

        return QualityReport(
            totalTests: totalTests,
            passedTests: passedTests,
            failedTests: failedTests,
            skippedTests: skippedTests,
            averageTestDuration: averageTestDuration,
            testCategories: testCategories,
            flakiness: flakiness,
            timestamp: Date()
        )
    }

    private static func calculateFlakiness() -> Double {
        let flakyTests = testRuns.values.filter { results in
            let hasPass = results.contains(true)
            let hasFail = results.contains(false)
            return hasPass && hasFail && results.count > 1
        }

        return testRuns.isEmpty ? 0 : Double(flakyTests.count) / Double(testRuns.count) * 100
    }

    /// Clear all metrics
    public static func clearMetrics() {
        testResults.removeAll()
        testRuns.removeAll()
    }
}

// MARK: - Automated Test Analysis

public class AutomatedTestAnalysis {

    /// Analyze test suite for potential issues
    public static func analyzeTestSuite() -> String {
        let coverageReport = CodeCoverageTracker.generateReport()
        let qualityReport = TestQualityMetrics.generateReport()
        let benchmarkResults = PerformanceBenchmark.getAllResults()

        var issues: [String] = []
        var recommendations: [String] = []

        // Coverage analysis
        if coverageReport.coveragePercentage < TestConfiguration.coverageThreshold * 100 {
            issues.append("❌ Code coverage below target (\(String(format: "%.1f", coverageReport.coveragePercentage))% < \(TestConfiguration.coverageThreshold * 100)%)")
            recommendations.append("📝 Add tests for uncovered areas: \(coverageReport.uncoveredAreas.prefix(3).joined(separator: ", "))")
        }

        // Quality analysis
        let passRate = qualityReport.totalTests > 0
            ? Double(qualityReport.passedTests) / Double(qualityReport.totalTests) * 100
            : 0

        if passRate < 95 {
            issues.append("❌ Test pass rate below 95% (\(String(format: "%.1f", passRate))%)")
            recommendations.append("🔧 Fix failing tests before adding new features")
        }

        if qualityReport.flakiness > 5 {
            issues.append("❌ High test flakiness (\(String(format: "%.1f", qualityReport.flakiness))%)")
            recommendations.append("🔄 Investigate and fix flaky tests")
        }

        // Performance analysis
        let slowTests = benchmarkResults.filter { $0.averageTime > 1.0 }
        if !slowTests.isEmpty {
            issues.append("⏱️ Slow tests detected: \(slowTests.count) tests > 1s")
            recommendations.append("🚀 Optimize slow tests or split into integration tests")
        }

        let analysis = """
        🔍 AUTOMATED TEST SUITE ANALYSIS
        Generated: \(DateFormatter.fullDateTime.string(from: Date()))

        📊 Overview:
        \(issues.isEmpty ? "✅ No critical issues detected" : "⚠️ Issues Found: \(issues.count)")

        \(issues.isEmpty ? "" : "🚨 ISSUES:\n\(issues.joined(separator: "\n"))\n")

        \(recommendations.isEmpty ? "" : "💡 RECOMMENDATIONS:\n\(recommendations.joined(separator: "\n"))\n")

        📈 Detailed Reports:
        \(coverageReport.description)

        \(qualityReport.description)

        \(benchmarkResults.isEmpty ? "📊 No performance benchmarks available" : "📊 \(benchmarkResults.count) performance benchmarks recorded")
        """

        return analysis
    }
}

// MARK: - Test Configuration

public enum TestConfiguration {
    public static let timeout: TimeInterval = 30.0
    public static let shortTimeout: TimeInterval = 5.0
    public static let performanceIterations = 10
    public static let coverageThreshold = 0.90 // 90%
    public static let maxTestDuration: TimeInterval = 10.0
    public static let maxMemoryUsage: UInt64 = 100 * 1024 * 1024 // 100MB

    public static var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
    }

    public static var isPerformanceTestingEnabled: Bool {
        ProcessInfo.processInfo.environment["PERFORMANCE_TESTING"] == "1"
    }

    public static var shouldGenerateReports: Bool {
        ProcessInfo.processInfo.environment["GENERATE_REPORTS"] == "1" || !isRunningInCI
    }
}

// MARK: - Test Report Generator

public class TestReportGenerator {

    /// Generate comprehensive test report
    public static func generateFullReport() -> String {
        let analysis = AutomatedTestAnalysis.analyzeTestSuite()
        let benchmarkReport = PerformanceBenchmark.generateReport()

        let report = """
        🧪 MORTGAGE GUARDIAN TEST SUITE REPORT
        =====================================
        Generated: \(DateFormatter.fullDateTime.string(from: Date()))
        Environment: \(TestConfiguration.isRunningInCI ? "CI" : "Local")

        \(analysis)

        \(benchmarkReport)

        📋 TEST CONFIGURATION:
        Coverage Target: \(TestConfiguration.coverageThreshold * 100)%
        Max Test Duration: \(TestConfiguration.maxTestDuration)s
        Performance Testing: \(TestConfiguration.isPerformanceTestingEnabled ? "Enabled" : "Disabled")

        🎯 NEXT STEPS:
        1. Address any failing tests
        2. Improve code coverage if below target
        3. Optimize slow performance tests
        4. Review and fix flaky tests
        5. Add tests for new features

        =====================================
        """

        return report
    }

    /// Save report to file
    public static func saveReport(_ report: String, to fileName: String = "test-report.txt") {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(fileName)

        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📄 Test report saved to: \(fileURL.path)")
        } catch {
            print("❌ Failed to save test report: \(error)")
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Test Observer

public class TestObserver: NSObject, XCTestObservation {

    public override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    public func testCaseWillStart(_ testCase: XCTestCase) {
        let testName = "\(type(of: testCase)).\(testCase.name)"
        print("🧪 Starting: \(testName)")
    }

    public func testCaseDidFinish(_ testCase: XCTestCase) {
        let testName = "\(type(of: testCase)).\(testCase.name)"
        let passed = testCase.testRun?.hasSucceeded ?? false
        let duration = testCase.testRun?.totalDuration ?? 0

        let category = categorizeTest(testCase)
        TestQualityMetrics.recordTest(
            name: testName,
            passed: passed,
            duration: duration,
            category: category
        )

        let status = passed ? "✅" : "❌"
        print("\(status) Finished: \(testName) (\(String(format: "%.3f", duration))s)")
    }

    public func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        if testSuite.name == "All tests" && TestConfiguration.shouldGenerateReports {
            let report = TestReportGenerator.generateFullReport()
            print(report)

            if TestConfiguration.isRunningInCI {
                TestReportGenerator.saveReport(report)
            }
        }
    }

    private func categorizeTest(_ testCase: XCTestCase) -> String {
        let className = String(describing: type(of: testCase))

        if className.contains("Unit") {
            return "unit"
        } else if className.contains("Integration") {
            return "integration"
        } else if className.contains("UI") {
            return "ui"
        } else if className.contains("Performance") {
            return "performance"
        } else {
            return "other"
        }
    }
}