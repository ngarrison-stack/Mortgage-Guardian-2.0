import XCTest
import Foundation
import Combine
import os.log
@testable import MortgageGuardian

/// Comprehensive test helpers and utilities for Mortgage Guardian testing framework
/// Provides common testing patterns, assertions, mocks, and test data

// MARK: - Test Configuration

public enum TestConfiguration {
    public static let timeout: TimeInterval = 30.0
    public static let shortTimeout: TimeInterval = 5.0
    public static let performanceIterations = 10
    public static let coverageThreshold = 0.90 // 90%

    public static var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
    }

    public static var isRunningDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Async Testing Utilities

public extension XCTestCase {

    /// Wait for async operation with timeout
    func waitForAsync<T>(
        timeout: TimeInterval = TestConfiguration.timeout,
        operation: @escaping () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }

            guard let result = try await group.next() else {
                throw TestError.unexpectedNil
            }

            group.cancelAll()
            return result
        }
    }

    /// Test async throwing operation
    func testAsyncThrows<T>(
        expectedError: Error.Type? = nil,
        timeout: TimeInterval = TestConfiguration.timeout,
        operation: @escaping () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await waitForAsync(timeout: timeout, operation: operation)
            XCTFail("Expected operation to throw, but it succeeded", file: file, line: line)
        } catch {
            if let expectedType = expectedError {
                XCTAssert(type(of: error) == expectedType,
                         "Expected error of type \(expectedType), got \(type(of: error))",
                         file: file, line: line)
            }
        }
    }

    /// Wait for publisher to emit value
    func waitForPublisher<T>(
        _ publisher: AnyPublisher<T, Error>,
        timeout: TimeInterval = TestConfiguration.timeout,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                cancellable?.cancel()
                continuation.resume(throwing: TestError.timeout)
            }

            cancellable = publisher
                .sink(
                    receiveCompletion: { completion in
                        timeoutTimer.invalidate()
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { value in
                        timeoutTimer.invalidate()
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}

// MARK: - Custom Assertions

public extension XCTestCase {

    /// Assert that two doubles are approximately equal within tolerance
    func XCTAssertApproximatelyEqual(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = 0.001,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let difference = abs(lhs - rhs)
        XCTAssert(difference <= tolerance,
                 "Values not approximately equal: \(lhs) vs \(rhs), difference: \(difference), tolerance: \(tolerance). \(message())",
                 file: file, line: line)
    }

    /// Assert that a monetary amount is correct within cent precision
    func XCTAssertMoneyEqual(
        _ actual: Double,
        _ expected: Double,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertApproximatelyEqual(actual, expected, tolerance: 0.01, message(), file: file, line: line)
    }

    /// Assert that an array contains expected elements in any order
    func XCTAssertContainsElements<T: Equatable>(
        _ array: [T],
        _ expectedElements: [T],
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for element in expectedElements {
            XCTAssert(array.contains(element),
                     "Array does not contain expected element: \(element). \(message())",
                     file: file, line: line)
        }
    }

    /// Assert that a collection is not empty
    func XCTAssertNotEmpty<T: Collection>(
        _ collection: T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(collection.isEmpty, "Collection should not be empty. \(message())", file: file, line: line)
    }

    /// Assert that an optional value is not nil and return unwrapped value
    @discardableResult
    func XCTUnwrap<T>(
        _ optional: T?,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        guard let value = optional else {
            XCTFail("Found nil, expected non-nil value. \(message())", file: file, line: line)
            throw TestError.unexpectedNil
        }
        return value
    }

    /// Assert that an audit result meets quality standards
    func XCTAssertValidAuditResult(
        _ result: AuditResult,
        minConfidence: Double = 0.5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(result.confidence, minConfidence,
                                   "Audit result confidence too low", file: file, line: line)
        XCTAssertFalse(result.title.isEmpty, "Audit result title should not be empty", file: file, line: line)
        XCTAssertFalse(result.description.isEmpty, "Audit result description should not be empty", file: file, line: line)
        XCTAssertFalse(result.suggestedAction.isEmpty, "Audit result suggested action should not be empty", file: file, line: line)
    }
}

// MARK: - Performance Testing

public extension XCTestCase {

    /// Measure performance of async operation
    func measureAsync(
        iterations: Int = TestConfiguration.performanceIterations,
        operation: @escaping () async throws -> Void
    ) async {
        var measurements: [TimeInterval] = []

        for _ in 0..<iterations {
            let startTime = Date()
            try? await operation()
            let endTime = Date()
            measurements.append(endTime.timeIntervalSince(startTime))
        }

        let average = measurements.reduce(0, +) / Double(measurements.count)
        let min = measurements.min() ?? 0
        let max = measurements.max() ?? 0

        print("Performance - Average: \(String(format: "%.4f", average))s, Min: \(String(format: "%.4f", min))s, Max: \(String(format: "%.4f", max))s")
    }

    /// Measure memory usage during operation
    func measureMemory(operation: @escaping () throws -> Void) {
        let startMemory = getCurrentMemoryUsage()
        try? operation()
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        print("Memory usage increased by: \(ByteCountFormatter().string(fromByteCount: Int64(memoryIncrease)))")
    }

    private func getCurrentMemoryUsage() -> UInt64 {
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

// MARK: - Test Errors

public enum TestError: Error, LocalizedError {
    case timeout
    case unexpectedNil
    case invalidTestData
    case mockSetupFailed
    case assertionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test operation timed out"
        case .unexpectedNil:
            return "Unexpected nil value encountered in test"
        case .invalidTestData:
            return "Invalid or corrupted test data"
        case .mockSetupFailed:
            return "Failed to set up mock objects"
        case .assertionFailed(let message):
            return "Test assertion failed: \(message)"
        }
    }
}

// MARK: - Test Data Validation

public struct TestDataValidator {

    /// Validate that test user data is properly structured
    public static func validateUser(_ user: User) throws {
        guard !user.fullName.isEmpty else {
            throw TestError.invalidTestData
        }

        guard !user.email.isEmpty, user.email.contains("@") else {
            throw TestError.invalidTestData
        }

        guard !user.mortgageAccounts.isEmpty else {
            throw TestError.invalidTestData
        }

        for account in user.mortgageAccounts {
            try validateMortgageAccount(account)
        }
    }

    /// Validate that mortgage account data is realistic
    public static func validateMortgageAccount(_ account: User.MortgageAccount) throws {
        guard account.originalLoanAmount > 0 else {
            throw TestError.invalidTestData
        }

        guard account.interestRate > 0 && account.interestRate < 1.0 else {
            throw TestError.invalidTestData
        }

        guard account.monthlyPayment > 0 else {
            throw TestError.invalidTestData
        }

        guard !account.loanNumber.isEmpty else {
            throw TestError.invalidTestData
        }
    }

    /// Validate that document data is complete
    public static func validateDocument(_ document: MortgageDocument) throws {
        guard !document.fileName.isEmpty else {
            throw TestError.invalidTestData
        }

        guard !document.originalText.isEmpty else {
            throw TestError.invalidTestData
        }

        guard document.uploadDate <= Date() else {
            throw TestError.invalidTestData
        }
    }

    /// Validate that audit result is properly formed
    public static func validateAuditResult(_ result: AuditResult) throws {
        guard result.confidence >= 0.0 && result.confidence <= 1.0 else {
            throw TestError.invalidTestData
        }

        guard !result.title.isEmpty else {
            throw TestError.invalidTestData
        }

        guard !result.description.isEmpty else {
            throw TestError.invalidTestData
        }

        if let amount = result.affectedAmount {
            guard amount >= 0 else {
                throw TestError.invalidTestData
            }
        }
    }
}

// MARK: - Test Environment Setup

public class TestEnvironment {
    public static let shared = TestEnvironment()

    private var isSetUp = false
    private let logger = Logger(subsystem: "com.mortgageguardian.tests", category: "TestEnvironment")

    private init() {}

    /// Set up test environment
    public func setUp() {
        guard !isSetUp else { return }

        // Configure logging for tests
        configureTestLogging()

        // Set up test-specific configurations
        configureTestDefaults()

        // Prepare test data directories
        prepareTestDirectories()

        isSetUp = true
        logger.info("Test environment set up successfully")
    }

    /// Clean up test environment
    public func tearDown() {
        // Clean up temporary files
        cleanupTestFiles()

        // Reset any global state
        resetGlobalState()

        isSetUp = false
        logger.info("Test environment cleaned up")
    }

    private func configureTestLogging() {
        // Configure more verbose logging for tests
        UserDefaults.standard.set(true, forKey: "TestMode")
    }

    private func configureTestDefaults() {
        // Set test-specific default values
        UserDefaults.standard.set(TestConfiguration.timeout, forKey: "DefaultTimeout")
        UserDefaults.standard.set(false, forKey: "AnalyticsEnabled") // Disable analytics in tests
    }

    private func prepareTestDirectories() {
        let testDirectory = getTestDirectory()
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }

    private func cleanupTestFiles() {
        let testDirectory = getTestDirectory()
        try? FileManager.default.removeItem(at: testDirectory)
    }

    private func resetGlobalState() {
        // Reset any singleton states that might affect tests
        UserDefaults.standard.removeObject(forKey: "TestMode")
        UserDefaults.standard.removeObject(forKey: "DefaultTimeout")
        UserDefaults.standard.removeObject(forKey: "AnalyticsEnabled")
    }

    public func getTestDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("MortgageGuardianTests")
    }
}

// MARK: - Test Case Base Classes

/// Base test case for unit tests
open class MortgageGuardianUnitTestCase: XCTestCase {

    override open func setUp() {
        super.setUp()
        TestEnvironment.shared.setUp()
    }

    override open func tearDown() {
        TestEnvironment.shared.tearDown()
        super.tearDown()
    }
}

/// Base test case for integration tests
open class MortgageGuardianIntegrationTestCase: XCTestCase {

    override open func setUp() {
        super.setUp()
        TestEnvironment.shared.setUp()

        // Additional setup for integration tests
        setupNetworkMocking()
    }

    override open func tearDown() {
        cleanupNetworkMocking()
        TestEnvironment.shared.tearDown()
        super.tearDown()
    }

    private func setupNetworkMocking() {
        // Set up network mocking for integration tests
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    private func cleanupNetworkMocking() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }
}

/// Base test case for UI tests
open class MortgageGuardianUITestCase: XCTestCase {

    override open func setUp() {
        super.setUp()
        TestEnvironment.shared.setUp()

        // Configure UI testing
        continueAfterFailure = false
    }

    override open func tearDown() {
        TestEnvironment.shared.tearDown()
        super.tearDown()
    }
}

// MARK: - Mock URL Protocol

public class MockURLProtocol: URLProtocol {
    public static var mockData: [URL: (Data?, URLResponse?, Error?)] = [:]

    override public class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override public func startLoading() {
        guard let url = request.url,
              let (data, response, error) = MockURLProtocol.mockData[url] else {
            client?.urlProtocol(self, didFailWithError: TestError.mockSetupFailed)
            return
        }

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override public func stopLoading() {
        // No cleanup needed
    }

    public static func setMockData(_ data: Data?, response: URLResponse?, error: Error?, for url: URL) {
        mockData[url] = (data, response, error)
    }

    public static func clearMockData() {
        mockData.removeAll()
    }
}

// MARK: - Test Extensions

public extension Date {
    /// Create a date for testing purposes
    static func testDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date()
    }
}

public extension String {
    /// Generate a random string for testing
    static func random(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

public extension Double {
    /// Generate a random monetary amount for testing
    static func randomMoney(min: Double = 100, max: Double = 10000) -> Double {
        let random = Double.random(in: min...max)
        return round(random * 100) / 100 // Round to cents
    }
}

// MARK: - Debugging Helpers

public struct TestDebugger {

    /// Print detailed information about a test failure
    public static func debugFailure<T>(
        actual: T,
        expected: T,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        print("🔍 Test Failure Debug Info:")
        print("📍 Location: \(URL(fileURLWithPath: file).lastPathComponent):\(line) in \(function)")
        print("❌ Expected: \(expected)")
        print("🔄 Actual: \(actual)")
        print("📊 Type: \(type(of: actual))")
    }

    /// Capture and print memory state
    public static func captureMemoryState() {
        let formatter = ByteCountFormatter()
        let memoryUsage = getCurrentMemoryUsage()
        print("💾 Current memory usage: \(formatter.string(fromByteCount: Int64(memoryUsage)))")
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