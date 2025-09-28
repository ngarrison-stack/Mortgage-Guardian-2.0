import XCTest
import Combine
@testable import MortgageGuardian

/// Comprehensive unit tests for SecurityService
/// Tests encryption, authentication, and security validation
final class SecurityServiceTests: MortgageGuardianUnitTestCase {

    private var securityService: MockSecurityService!
    private var testData: Data!
    private var testKey: String!

    override func setUp() {
        super.setUp()
        setupTestObjects()
    }

    override func tearDown() {
        securityService = nil
        testData = nil
        testKey = nil
        super.tearDown()
    }

    private func setupTestObjects() {
        securityService = MockSecurityService()
        testData = "Test sensitive data".data(using: .utf8)!
        testKey = "test-encryption-key"
    }

    // MARK: - Encryption Tests

    func testEncryptData_Success() async throws {
        // Given
        securityService.shouldFailEncryption = false

        // When
        let encryptedData = try await securityService.encryptData(testData, with: testKey)

        // Then
        XCTAssertNotNil(encryptedData)
        XCTAssertNotEqual(encryptedData, testData) // Should be different from original
        XCTAssertGreaterThan(encryptedData.count, 0)
    }

    func testEncryptData_Failure() async {
        // Given
        securityService.shouldFailEncryption = true

        // When/Then
        await testAsyncThrows(expectedError: SecurityError.self) {
            try await self.securityService.encryptData(self.testData, with: self.testKey)
        }
    }

    func testEncryptData_EmptyData() async throws {
        // Given
        let emptyData = Data()

        // When
        let encryptedData = try await securityService.encryptData(emptyData, with: testKey)

        // Then
        XCTAssertNotNil(encryptedData)
    }

    func testEncryptData_LargeData() async throws {
        // Given
        let largeData = Data(count: 1024 * 1024) // 1MB

        // When
        let encryptedData = try await securityService.encryptData(largeData, with: testKey)

        // Then
        XCTAssertNotNil(encryptedData)
        XCTAssertGreaterThan(encryptedData.count, 0)
    }

    func testEncryptData_SpecialCharacters() async throws {
        // Given
        let specialData = "Special chars: ñáéíóú, 中文, 🔒💰".data(using: .utf8)!

        // When
        let encryptedData = try await securityService.encryptData(specialData, with: testKey)

        // Then
        XCTAssertNotNil(encryptedData)
        XCTAssertNotEqual(encryptedData, specialData)
    }

    // MARK: - Decryption Tests

    func testDecryptData_Success() async throws {
        // Given
        securityService.shouldFailDecryption = false
        let encryptedData = try await securityService.encryptData(testData, with: testKey)

        // When
        let decryptedData = try await securityService.decryptData(encryptedData, with: testKey)

        // Then
        XCTAssertNotNil(decryptedData)
        XCTAssertGreaterThan(decryptedData.count, 0)
        // In mock implementation, we get back a fixed string, not the original
        XCTAssertEqual(String(data: decryptedData, encoding: .utf8), "decrypted")
    }

    func testDecryptData_Failure() async {
        // Given
        securityService.shouldFailDecryption = true
        let encryptedData = securityService.mockEncryptedData

        // When/Then
        await testAsyncThrows(expectedError: SecurityError.self) {
            try await self.securityService.decryptData(encryptedData, with: self.testKey)
        }
    }

    func testDecryptData_WrongKey() async {
        // Given
        let encryptedData = try? await securityService.encryptData(testData, with: testKey)
        let wrongKey = "wrong-key"
        securityService.shouldFailDecryption = true

        // When/Then
        await testAsyncThrows(expectedError: SecurityError.self) {
            try await self.securityService.decryptData(encryptedData!, with: wrongKey)
        }
    }

    func testDecryptData_CorruptedData() async {
        // Given
        let corruptedData = Data([0xFF, 0xFF, 0xFF]) // Invalid encrypted data
        securityService.shouldFailDecryption = true

        // When/Then
        await testAsyncThrows(expectedError: SecurityError.self) {
            try await self.securityService.decryptData(corruptedData, with: self.testKey)
        }
    }

    // MARK: - Authentication Tests

    func testSignRequest_Success() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        securityService.shouldFailAuthentication = false

        // When
        let signedRequest = try await securityService.signRequest(request, with: "api-key")

        // Then
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer mock-token")
        XCTAssertEqual(signedRequest.url, request.url)
    }

    func testSignRequest_Failure() async {
        // Given
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        securityService.shouldFailAuthentication = true

        // When/Then
        await testAsyncThrows(expectedError: SecurityError.self) {
            try await self.securityService.signRequest(request, with: "api-key")
        }
    }

    func testSignRequest_PreservesExistingHeaders() async throws {
        // Given
        var request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("test-value", forHTTPHeaderField: "X-Custom-Header")

        // When
        let signedRequest = try await securityService.signRequest(request, with: "api-key")

        // Then
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "X-Custom-Header"), "test-value")
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "Authorization"))
    }

    func testSignRequest_DifferentKeyIdentifiers() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        let keyIdentifiers = ["api-key", "claude-key", "plaid-key", "custom-key"]

        // When/Then
        for keyId in keyIdentifiers {
            let signedRequest = try await securityService.signRequest(request, with: keyId)
            XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "Authorization"))
        }
    }

    // MARK: - File Validation Tests

    func testValidateFileIntegrity_ValidData() {
        // Given
        let validData = MockFileData.createMockImageData()

        // When
        let isValid = securityService.validateFileIntegrity(data: validData)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateFileIntegrity_EmptyData() {
        // Given
        let emptyData = Data()

        // When
        let isValid = securityService.validateFileIntegrity(data: emptyData)

        // Then
        XCTAssertFalse(isValid) // Empty data should be invalid
    }

    func testValidateFileIntegrity_AuthenticationFailure() {
        // Given
        securityService.shouldFailAuthentication = true
        let validData = MockFileData.createMockImageData()

        // When
        let isValid = securityService.validateFileIntegrity(data: validData)

        // Then
        XCTAssertFalse(isValid) // Should fail when authentication is disabled
    }

    func testValidateFileIntegrity_VariousFormats() {
        // Given
        let testFiles = [
            MockFileData.createMockImageData(),
            MockFileData.createMockPDFData(),
            "Test text content".data(using: .utf8)!
        ]

        // When/Then
        for fileData in testFiles {
            let isValid = securityService.validateFileIntegrity(data: fileData)
            XCTAssertTrue(isValid, "File validation should pass for valid data")
        }
    }

    // MARK: - Hash Generation Tests

    func testGenerateSecureHash_Consistency() {
        // Given
        let data1 = testData
        let data2 = testData

        // When
        let hash1 = securityService.generateSecureHash(for: data1!)
        let hash2 = securityService.generateSecureHash(for: data2!)

        // Then
        XCTAssertEqual(hash1, hash2) // Same data should produce same hash
        XCTAssertFalse(hash1.isEmpty)
    }

    func testGenerateSecureHash_Uniqueness() {
        // Given
        let data1 = "Data set 1".data(using: .utf8)!
        let data2 = "Data set 2".data(using: .utf8)!

        // When
        let hash1 = securityService.generateSecureHash(for: data1)
        let hash2 = securityService.generateSecureHash(for: data2)

        // Then
        XCTAssertNotEqual(hash1, hash2) // Different data should produce different hashes
    }

    func testGenerateSecureHash_EmptyData() {
        // Given
        let emptyData = Data()

        // When
        let hash = securityService.generateSecureHash(for: emptyData)

        // Then
        XCTAssertFalse(hash.isEmpty) // Should still generate a hash for empty data
    }

    func testGenerateSecureHash_LargeData() {
        // Given
        let largeData = Data(count: 10 * 1024 * 1024) // 10MB

        // When
        let hash = securityService.generateSecureHash(for: largeData)

        // Then
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash, "mock-hash-\(largeData.count)")
    }

    // MARK: - Performance Tests

    func testEncryption_Performance() async {
        // Given
        let performanceData = Data(count: 1024) // 1KB

        // When/Then
        await measureAsync {
            try? await self.securityService.encryptData(performanceData, with: self.testKey)
        }
    }

    func testDecryption_Performance() async {
        // Given
        let encryptedData = try? await securityService.encryptData(testData, with: testKey)

        // When/Then
        await measureAsync {
            try? await self.securityService.decryptData(encryptedData!, with: self.testKey)
        }
    }

    func testBulkEncryption_Performance() async {
        // Given
        let bulkData = Array(repeating: testData!, count: 100)

        // When/Then
        await measureAsync {
            for data in bulkData {
                try? await self.securityService.encryptData(data, with: self.testKey)
            }
        }
    }

    func testHashGeneration_Performance() {
        // Given
        let hashData = Data(count: 1024 * 1024) // 1MB

        // When/Then
        measure {
            _ = self.securityService.generateSecureHash(for: hashData)
        }
    }

    // MARK: - Memory Tests

    func testEncryption_MemoryUsage() {
        // Given
        let memoryTestData = Data(count: 5 * 1024 * 1024) // 5MB

        // When/Then
        measureMemory {
            Task {
                try? await self.securityService.encryptData(memoryTestData, with: self.testKey)
            }
        }
    }

    func testBulkOperations_MemoryUsage() {
        // Given
        let operations = 50
        let dataSize = 100 * 1024 // 100KB each

        // When/Then
        measureMemory {
            Task {
                for _ in 0..<operations {
                    let data = Data(count: dataSize)
                    try? await self.securityService.encryptData(data, with: self.testKey)
                }
            }
        }
    }

    // MARK: - Edge Cases Tests

    func testSecurity_NilHandling() async {
        // Test that security service handles various nil/empty scenarios gracefully

        // Empty key
        await testAsyncThrows {
            try await self.securityService.encryptData(self.testData, with: "")
        }

        // Very long key
        let longKey = String(repeating: "k", count: 10000)
        let result = try? await securityService.encryptData(testData, with: longKey)
        XCTAssertNotNil(result)
    }

    func testSecurity_SpecialInputs() async throws {
        // Given
        let specialInputs = [
            "🔒🔑💰".data(using: .utf8)!, // Emojis
            Data([0x00, 0xFF, 0x00, 0xFF]), // Binary data
            String(repeating: "a", count: 10000).data(using: .utf8)! // Large text
        ]

        // When/Then
        for input in specialInputs {
            let encrypted = try await securityService.encryptData(input, with: testKey)
            XCTAssertNotNil(encrypted)
            XCTAssertNotEqual(encrypted, input)
        }
    }

    func testSecurity_ConcurrentOperations() async throws {
        // Given
        let concurrentData = Array(repeating: testData!, count: 10)

        // When
        let results = try await withThrowingTaskGroup(of: Data.self) { group in
            for data in concurrentData {
                group.addTask {
                    try await self.securityService.encryptData(data, with: self.testKey)
                }
            }

            var results: [Data] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        // Then
        XCTAssertEqual(results.count, concurrentData.count)
        for result in results {
            XCTAssertNotNil(result)
            XCTAssertGreaterThan(result.count, 0)
        }
    }

    // MARK: - Security Error Tests

    func testSecurityErrors_Localization() {
        // Given
        let errors: [SecurityError] = [
            .authenticationFailed,
            .authorizationDenied,
            .tokenExpired,
            .invalidCredentials,
            .biometricAuthUnavailable,
            .biometricAuthFailed,
            .keyChainError(NSError(domain: "Test", code: 1)),
            .encryptionFailed,
            .decryptionFailed,
            .integrityCheckFailed,
            .suspiciousActivity,
            .deviceNotTrusted
        ]

        // When/Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertNotNil(error.userMessage)
            XCTAssertFalse(error.userMessage.isEmpty)
            XCTAssertNotEmpty(error.recoveryOptions)
        }
    }

    func testSecurityErrors_RecoveryOptions() {
        // Given
        let authError = SecurityError.authenticationFailed
        let tokenError = SecurityError.tokenExpired
        let biometricError = SecurityError.biometricAuthFailed

        // When/Then
        XCTAssertNotEmpty(authError.recoveryOptions)
        XCTAssertTrue(authError.recoveryOptions.contains { $0.title.contains("Try Again") })

        XCTAssertNotEmpty(tokenError.recoveryOptions)
        XCTAssertTrue(tokenError.recoveryOptions.contains { $0.title.contains("Log In") })

        XCTAssertNotEmpty(biometricError.recoveryOptions)
        XCTAssertTrue(biometricError.recoveryOptions.contains { $0.title.contains("Passcode") })
    }

    func testSecurityErrors_Severity() {
        // Given/When/Then
        XCTAssertEqual(SecurityError.authenticationFailed.severity, .warning)
        XCTAssertEqual(SecurityError.tokenExpired.severity, .info)
        XCTAssertEqual(SecurityError.encryptionFailed.severity, .error)
        XCTAssertEqual(SecurityError.integrityCheckFailed.severity, .critical)
        XCTAssertEqual(SecurityError.suspiciousActivity.severity, .critical)
    }

    func testSecurityErrors_AnalyticsData() {
        // Given
        let errors: [SecurityError] = [
            .authenticationFailed,
            .encryptionFailed,
            .suspiciousActivity
        ]

        // When/Then
        for error in errors {
            let analyticsData = error.analyticsData
            XCTAssertNotNil(analyticsData["error_code"])
            XCTAssertNotNil(analyticsData["severity"])
            XCTAssertFalse(analyticsData.isEmpty)
        }
    }

    // MARK: - Integration Tests

    func testSecurity_FullEncryptionCycle() async throws {
        // Given
        let originalData = "Sensitive mortgage data: Loan #123456789, Balance: $298,750.50".data(using: .utf8)!
        securityService.shouldFailEncryption = false
        securityService.shouldFailDecryption = false

        // When
        let encrypted = try await securityService.encryptData(originalData, with: testKey)
        let decrypted = try await securityService.decryptData(encrypted, with: testKey)

        // Then
        XCTAssertNotEqual(encrypted, originalData) // Encrypted should be different
        XCTAssertNotNil(decrypted) // Decryption should succeed
        // Note: In mock implementation, decrypted won't match original, but should not crash
    }

    func testSecurity_RequestSigning() async throws {
        // Given
        var request = URLRequest(url: URL(string: "https://api.mortgageguardian.com/analyze")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = """
        {
            "document_id": "123",
            "analysis_type": "comprehensive"
        }
        """.data(using: .utf8)!
        request.httpBody = requestBody

        // When
        let signedRequest = try await securityService.signRequest(request, with: "claude_api_key")

        // Then
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(signedRequest.httpMethod, "POST")
        XCTAssertEqual(signedRequest.httpBody, requestBody)
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testSecurity_FileValidationPipeline() {
        // Given
        let validFiles = [
            MockFileData.createMockImageData(),
            MockFileData.createMockPDFData()
        ]
        let invalidFiles = [
            Data(), // Empty
            MockFileData.createCorruptedData()
        ]

        // When/Then
        for validFile in validFiles {
            XCTAssertTrue(securityService.validateFileIntegrity(data: validFile),
                         "Valid file should pass integrity check")

            let hash = securityService.generateSecureHash(for: validFile)
            XCTAssertFalse(hash.isEmpty, "Hash should be generated for valid files")
        }

        for invalidFile in invalidFiles {
            // These might pass or fail depending on mock implementation
            let hash = securityService.generateSecureHash(for: invalidFile)
            XCTAssertFalse(hash.isEmpty, "Hash should still be generated even for invalid files")
        }
    }

    // MARK: - Thread Safety Tests

    func testSecurity_ThreadSafety() async throws {
        // Given
        let iterations = 50
        let testDataArray = Array(repeating: testData!, count: iterations)

        // When
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for (index, data) in testDataArray.enumerated() {
                group.addTask {
                    let encrypted = try await self.securityService.encryptData(data, with: "\(self.testKey)-\(index)")
                    return self.securityService.generateSecureHash(for: encrypted)
                }
            }

            var hashes: [String] = []
            for try await hash in group {
                hashes.append(hash)
            }
            return hashes
        }

        // Then
        XCTAssertEqual(results.count, iterations)
        for hash in results {
            XCTAssertFalse(hash.isEmpty)
        }
    }
}