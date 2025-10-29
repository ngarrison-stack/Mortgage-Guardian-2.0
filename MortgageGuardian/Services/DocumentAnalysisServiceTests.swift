import Foundation
import SwiftUI
import OSLog

/// Test utilities for DocumentAnalysisService AWS integration
@MainActor
class DocumentAnalysisServiceTests: ObservableObject {
    private let logger = Logger(subsystem: "com.mortgageguardian.tests", category: "DocumentAnalysisTests")
    private let documentAnalysisService = DocumentAnalysisService()

    @Published var testResults: [TestResult] = []
    @Published var isRunningTests = false

    struct TestResult {
        let testName: String
        let success: Bool
        let message: String
        let duration: TimeInterval
        let timestamp: Date
    }

    /// Run all integration tests
    func runAllTests() async {
        isRunningTests = true
        testResults.removeAll()

        logger.info("Starting AWS integration tests")

        // Test AWS backend availability
        await testAWSBackendAvailability()

        // Test image validation
        await testImageValidation()

        // Test processing preferences
        await testProcessingPreferences()

        // Test error handling
        await testErrorHandling()

        isRunningTests = false
        logger.info("Completed AWS integration tests")
    }

    /// Test AWS backend availability
    private func testAWSBackendAvailability() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let isAvailable = await documentAnalysisService.isAWSBackendAvailable()
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            let result = TestResult(
                testName: "AWS Backend Availability",
                success: isAvailable,
                message: isAvailable ? "AWS backend is available" : "AWS backend is not available",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.info("AWS Backend Availability Test: \(isAvailable ? "PASS" : "FAIL")")
        }
    }

    /// Test image validation logic
    private func testImageValidation() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test with minimal valid image
        let testImage = createTestImage(width: 200, height: 200)
        let testType = DocumentAnalysisService.DocumentType.bankStatement

        do {
            // This should succeed with a valid image
            documentAnalysisService.setProcessingPreferences(preferCloud: false, enableFallback: true)
            let _ = try await documentAnalysisService.analyzeDocument(testImage, expectedType: testType)

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let result = TestResult(
                testName: "Image Validation",
                success: true,
                message: "Image validation and processing succeeded",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.info("Image Validation Test: PASS")

        } catch let error as DocumentAnalysisError {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let result = TestResult(
                testName: "Image Validation",
                success: false,
                message: "Image validation failed: \(error.userFriendlyMessage)",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.warning("Image Validation Test: FAIL - \(error.localizedDescription)")

        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let result = TestResult(
                testName: "Image Validation",
                success: false,
                message: "Unexpected error: \(error.localizedDescription)",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.error("Image Validation Test: FAIL - \(error.localizedDescription)")
        }
    }

    /// Test processing preferences
    private func testProcessingPreferences() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test preference changes
        documentAnalysisService.setProcessingPreferences(preferCloud: true, enableFallback: false)
        let cloudPreferred = documentAnalysisService.preferCloudProcessing
        let fallbackEnabled = documentAnalysisService.enableFallbackProcessing

        let success = cloudPreferred && !fallbackEnabled

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let result = TestResult(
            testName: "Processing Preferences",
            success: success,
            message: success ? "Preferences set correctly" : "Failed to set preferences",
            duration: duration,
            timestamp: Date()
        )
        testResults.append(result)

        logger.info("Processing Preferences Test: \(success ? "PASS" : "FAIL")")
    }

    /// Test error handling scenarios
    private func testErrorHandling() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test with invalid image (too small)
        let tinyImage = createTestImage(width: 50, height: 50)
        let testType = DocumentAnalysisService.DocumentType.bankStatement

        do {
            let _ = try await documentAnalysisService.analyzeDocument(tinyImage, expectedType: testType)

            // If we get here, the test failed (should have thrown an error)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let result = TestResult(
                testName: "Error Handling",
                success: false,
                message: "Expected error for tiny image, but processing succeeded",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.warning("Error Handling Test: FAIL - Expected error but got success")

        } catch let error as DocumentAnalysisError {
            // This is expected - check if it's the right error type
            let isCorrectError = case .imageTooSmall = error
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            let result = TestResult(
                testName: "Error Handling",
                success: isCorrectError,
                message: isCorrectError ? "Correctly caught image too small error" : "Caught wrong error type: \(error.localizedDescription)",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.info("Error Handling Test: \(isCorrectError ? "PASS" : "FAIL")")

        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let result = TestResult(
                testName: "Error Handling",
                success: false,
                message: "Unexpected error type: \(error.localizedDescription)",
                duration: duration,
                timestamp: Date()
            )
            testResults.append(result)

            logger.warning("Error Handling Test: FAIL - Unexpected error type")
        }
    }

    /// Create a test image with specified dimensions
    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            fatalError("Could not create test CGContext")
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Add some black text to make it look like a document
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
        context.fill(CGRect(x: 10, y: 10, width: width - 20, height: 5))
        context.fill(CGRect(x: 10, y: 20, width: width - 30, height: 5))
        context.fill(CGRect(x: 10, y: 30, width: width - 25, height: 5))

        guard let cgImage = context.makeImage() else {
            fatalError("Could not create test CGImage")
        }

        return cgImage
    }

    /// Get test summary
    var testSummary: String {
        let totalTests = testResults.count
        let passedTests = testResults.filter { $0.success }.count
        let failedTests = totalTests - passedTests

        return """
        Test Summary:
        Total: \(totalTests)
        Passed: \(passedTests)
        Failed: \(failedTests)
        Success Rate: \(totalTests > 0 ? String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100) : "0.0")%
        """
    }
}

// MARK: - SwiftUI Test View

struct DocumentAnalysisTestView: View {
    @StateObject private var testManager = DocumentAnalysisServiceTests()

    var body: some View {
        NavigationView {
            List {
                Section("Test Controls") {
                    Button(action: {
                        Task {
                            await testManager.runAllTests()
                        }
                    }) {
                        HStack {
                            if testManager.isRunningTests {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Running Tests...")
                            } else {
                                Image(systemName: "play.circle.fill")
                                Text("Run All Tests")
                            }
                        }
                    }
                    .disabled(testManager.isRunningTests)
                }

                if !testManager.testResults.isEmpty {
                    Section("Test Results") {
                        ForEach(testManager.testResults.indices, id: \.self) { index in
                            let result = testManager.testResults[index]

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)

                                    Text(result.testName)
                                        .font(.headline)

                                    Spacer()

                                    Text("\(String(format: "%.2f", result.duration))s")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section("Summary") {
                        Text(testManager.testSummary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("AWS Integration Tests")
        }
    }
}

#Preview {
    DocumentAnalysisTestView()
}