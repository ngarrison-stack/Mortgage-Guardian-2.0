import XCTest
import Combine
import Security
@testable import MortgageGuardian

/// Comprehensive unit tests for SecureKeyManager
/// Tests keychain operations, API key management, error handling, and service integration
final class SecureKeyManagerTests: MortgageGuardianUnitTestCase {

    private var secureKeyManager: MockSecureKeyManager!
    private var testAPIKey: String!
    private var testPlaidClientId: String!
    private var testPlaidSecret: String!
    private var testMarketDataKey: String!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        setupTestObjects()
    }

    override func tearDown() {
        secureKeyManager = nil
        testAPIKey = nil
        testPlaidClientId = nil
        testPlaidSecret = nil
        testMarketDataKey = nil
        cancellables = nil
        super.tearDown()
    }

    private func setupTestObjects() {
        secureKeyManager = MockSecureKeyManager()
        testAPIKey = "sk-test-claude-api-key-12345"
        testPlaidClientId = "test-plaid-client-id"
        testPlaidSecret = "test-plaid-secret"
        testMarketDataKey = "test-market-data-key"
        cancellables = Set<AnyCancellable>()
    }

    // MARK: - Save API Key Tests

    func testSaveAPIKey_Success() throws {
        // Given
        secureKeyManager.resetErrorSimulation()

        // When
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // Then
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), testAPIKey)
    }

    func testSaveAPIKey_AllServices() throws {
        // Given
        let testKeys: [APIService: String] = [
            .claude: testAPIKey,
            .plaidClientId: testPlaidClientId,
            .plaidSecret: testPlaidSecret,
            .marketData: testMarketDataKey,
            .realEstate: "test-real-estate-key",
            .federalReserve: "test-fed-key"
        ]

        // When
        for (service, key) in testKeys {
            try secureKeyManager.saveAPIKey(key, forService: service)
        }

        // Then
        for (service, expectedKey) in testKeys {
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: service), expectedKey)
        }

        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)
    }

    func testSaveAPIKey_DuplicateItem() {
        // Given
        secureKeyManager.simulateDuplicateItem = true
        try? secureKeyManager.saveAPIKey("existing-key", forService: .claude)

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.duplicateItem = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.duplicateItem, got \(error)")
            }
        }
    }

    func testSaveAPIKey_Failure() {
        // Given
        secureKeyManager.shouldFailSave = true

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.unexpectedStatus = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.unexpectedStatus, got \(error)")
            }
        }
    }

    func testSaveAPIKey_EmptyKey() {
        // When/Then
        XCTAssertNoThrow(try secureKeyManager.saveAPIKey("", forService: .claude))
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), "")
    }

    func testSaveAPIKey_LongKey() throws {
        // Given
        let longKey = String(repeating: "a", count: 10000)

        // When
        try secureKeyManager.saveAPIKey(longKey, forService: .claude)

        // Then
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), longKey)
    }

    func testSaveAPIKey_SpecialCharacters() throws {
        // Given
        let specialKey = "sk-test-🔑-key-with-special-chars-ñáéíóú-中文-!@#$%^&*()"

        // When
        try secureKeyManager.saveAPIKey(specialKey, forService: .claude)

        // Then
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), specialKey)
    }

    // MARK: - Retrieve API Key Tests

    func testGetAPIKey_Success() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When
        let retrievedKey = try secureKeyManager.getAPIKey(forService: .claude)

        // Then
        XCTAssertEqual(retrievedKey, testAPIKey)
    }

    func testGetAPIKey_NotFound() {
        // Given
        secureKeyManager.clearAllKeys()

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.itemNotFound = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.itemNotFound, got \(error)")
            }
        }
    }

    func testGetAPIKey_InvalidData() {
        // Given
        secureKeyManager.simulateInvalidData = true

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.invalidData = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.invalidData, got \(error)")
            }
        }
    }

    func testGetAPIKey_RetrievalFailure() {
        // Given
        secureKeyManager.shouldFailRetrieve = true

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.unexpectedStatus = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.unexpectedStatus, got \(error)")
            }
        }
    }

    func testGetAPIKey_AllServices() throws {
        // Given
        let testKeys: [APIService: String] = [
            .claude: testAPIKey,
            .plaidClientId: testPlaidClientId,
            .plaidSecret: testPlaidSecret,
            .marketData: testMarketDataKey
        ]

        for (service, key) in testKeys {
            try secureKeyManager.saveAPIKey(key, forService: service)
        }

        // When/Then
        for (service, expectedKey) in testKeys {
            let retrievedKey = try secureKeyManager.getAPIKey(forService: service)
            XCTAssertEqual(retrievedKey, expectedKey)
        }
    }

    // MARK: - Update API Key Tests

    func testUpdateAPIKey_ExistingKey() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        let updatedKey = "sk-updated-claude-key"

        // When
        try secureKeyManager.updateAPIKey(updatedKey, forService: .claude)

        // Then
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), updatedKey)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
    }

    func testUpdateAPIKey_NonExistingKey() throws {
        // Given
        secureKeyManager.clearAllKeys()

        // When
        try secureKeyManager.updateAPIKey(testAPIKey, forService: .claude)

        // Then
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), testAPIKey)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
    }

    func testUpdateAPIKey_Failure() {
        // Given
        secureKeyManager.shouldFailUpdate = true

        // When/Then
        XCTAssertThrowsError(try secureKeyManager.updateAPIKey(testAPIKey, forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.unexpectedStatus = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.unexpectedStatus, got \(error)")
            }
        }
    }

    func testUpdateAPIKey_MultipleTimes() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When
        let updates = ["key1", "key2", "key3", testAPIKey]
        for updatedKey in updates {
            try secureKeyManager.updateAPIKey(updatedKey, forService: .claude)
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), updatedKey)
        }

        // Then
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), testAPIKey)
    }

    // MARK: - Delete API Key Tests

    func testDeleteAPIKey_Success() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)

        // When
        secureKeyManager.deleteAPIKey(forService: .claude)

        // Then
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude)) { error in
            XCTAssertTrue(error is KeychainError)
            if case KeychainError.itemNotFound = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.itemNotFound, got \(error)")
            }
        }
    }

    func testDeleteAPIKey_NonExistingKey() {
        // Given
        secureKeyManager.clearAllKeys()

        // When/Then - Should not throw or crash
        XCTAssertNoThrow(secureKeyManager.deleteAPIKey(forService: .claude))
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
    }

    func testDeleteAPIKey_AllKeys() throws {
        // Given
        let services: [APIService] = [.claude, .plaidClientId, .plaidSecret, .marketData]
        for (index, service) in services.enumerated() {
            try secureKeyManager.saveAPIKey("key-\(index)", forService: service)
        }

        // When
        for service in services {
            secureKeyManager.deleteAPIKey(forService: service)
        }

        // Then
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertFalse(secureKeyManager.hasMarketDataKey)

        for service in services {
            XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: service))
        }
    }

    func testDeleteAPIKey_Failure() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        secureKeyManager.shouldFailDelete = true

        // When
        secureKeyManager.deleteAPIKey(forService: .claude)

        // Then - Delete doesn't throw in real implementation, key should still exist
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), testAPIKey)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
    }

    // MARK: - Status Checking Tests

    func testCheckAPIKeysStatus_EmptyKeychain() {
        // Given
        secureKeyManager.clearAllKeys()

        // When
        secureKeyManager.checkAPIKeysStatus()

        // Then
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertFalse(secureKeyManager.hasMarketDataKey)
    }

    func testCheckAPIKeysStatus_PartialKeys() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        // Note: Missing plaidSecret

        // When
        secureKeyManager.checkAPIKeysStatus()

        // Then
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys) // Requires both client ID and secret
        XCTAssertFalse(secureKeyManager.hasMarketDataKey)
    }

    func testCheckAPIKeysStatus_AllKeys() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)
        try secureKeyManager.saveAPIKey(testMarketDataKey, forService: .marketData)

        // When
        secureKeyManager.checkAPIKeysStatus()

        // Then
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)
    }

    func testCheckAPIKeysStatus_PublishedUpdates() throws {
        // Given
        var hasClaudeKeyUpdates: [Bool] = []
        var hasPlaidKeysUpdates: [Bool] = []

        secureKeyManager.$hasClaudeKey
            .sink { hasClaudeKeyUpdates.append($0) }
            .store(in: &cancellables)

        secureKeyManager.$hasPlaidKeys
            .sink { hasPlaidKeysUpdates.append($0) }
            .store(in: &cancellables)

        // When
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // Then
        XCTAssertTrue(hasClaudeKeyUpdates.contains(true))
        XCTAssertTrue(hasPlaidKeysUpdates.contains(true))
    }

    // MARK: - Convenience Method Tests

    func testHasAllRequiredKeys_True() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // When/Then
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())
    }

    func testHasAllRequiredKeys_MissingClaude() throws {
        // Given
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // When/Then
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())
    }

    func testHasAllRequiredKeys_MissingPlaid() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When/Then
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())
    }

    func testHasAllRequiredKeys_Empty() {
        // Given
        secureKeyManager.clearAllKeys()

        // When/Then
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())
    }

    func testGetMissingKeys_AllMissing() {
        // Given
        secureKeyManager.clearAllKeys()

        // When
        let missingKeys = secureKeyManager.getMissingKeys()

        // Then
        XCTAssertEqual(missingKeys.count, 3)
        XCTAssertContainsElements(missingKeys, [.claude, .plaidClientId, .plaidSecret])
    }

    func testGetMissingKeys_PartiallyMissing() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When
        let missingKeys = secureKeyManager.getMissingKeys()

        // Then
        XCTAssertEqual(missingKeys.count, 2)
        XCTAssertContainsElements(missingKeys, [.plaidClientId, .plaidSecret])
        XCTAssertFalse(missingKeys.contains(.claude))
    }

    func testGetMissingKeys_NoneMissing() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // When
        let missingKeys = secureKeyManager.getMissingKeys()

        // Then
        XCTAssertTrue(missingKeys.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testKeychainError_LocalizedDescription() {
        let errors: [KeychainError] = [
            .itemNotFound,
            .duplicateItem,
            .unexpectedStatus(errSecAuthFailed),
            .invalidData
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testKeychainError_ItemNotFound() {
        let error = KeychainError.itemNotFound
        XCTAssertTrue(error.errorDescription!.contains("not found"))
        XCTAssertTrue(error.errorDescription!.contains("Settings"))
    }

    func testKeychainError_DuplicateItem() {
        let error = KeychainError.duplicateItem
        XCTAssertTrue(error.errorDescription!.contains("already exists"))
        XCTAssertTrue(error.errorDescription!.contains("update"))
    }

    func testKeychainError_UnexpectedStatus() {
        let error = KeychainError.unexpectedStatus(errSecAuthFailed)
        XCTAssertTrue(error.errorDescription!.contains("Keychain error"))
        XCTAssertTrue(error.errorDescription!.contains("\(errSecAuthFailed)"))
    }

    func testKeychainError_InvalidData() {
        let error = KeychainError.invalidData
        XCTAssertTrue(error.errorDescription!.contains("Invalid data"))
        XCTAssertTrue(error.errorDescription!.contains("keychain"))
    }

    // MARK: - APIService Configuration Tests

    func testAPIService_RawValues() {
        XCTAssertEqual(APIService.claude.rawValue, "com.mortgageguardian.api.claude")
        XCTAssertEqual(APIService.plaidClientId.rawValue, "com.mortgageguardian.api.plaid.client")
        XCTAssertEqual(APIService.plaidSecret.rawValue, "com.mortgageguardian.api.plaid.secret")
        XCTAssertEqual(APIService.marketData.rawValue, "com.mortgageguardian.api.marketdata")
        XCTAssertEqual(APIService.realEstate.rawValue, "com.mortgageguardian.api.realestate")
        XCTAssertEqual(APIService.federalReserve.rawValue, "com.mortgageguardian.api.fedreserve")
    }

    func testAPIService_DisplayNames() {
        XCTAssertEqual(APIService.claude.displayName, "Claude API Key")
        XCTAssertEqual(APIService.plaidClientId.displayName, "Plaid Client ID")
        XCTAssertEqual(APIService.plaidSecret.displayName, "Plaid Secret")
        XCTAssertEqual(APIService.marketData.displayName, "Market Data API")
        XCTAssertEqual(APIService.realEstate.displayName, "Real Estate API")
        XCTAssertEqual(APIService.federalReserve.displayName, "Federal Reserve API")
    }

    func testAPIService_Descriptions() {
        XCTAssertTrue(APIService.claude.description.contains("AI-powered"))
        XCTAssertTrue(APIService.plaidClientId.description.contains("bank account"))
        XCTAssertTrue(APIService.plaidSecret.description.contains("bank account"))
        XCTAssertTrue(APIService.marketData.description.contains("market data"))
        XCTAssertTrue(APIService.realEstate.description.contains("property valuations"))
        XCTAssertTrue(APIService.federalReserve.description.contains("interest rate"))
    }

    func testAPIService_RequiredFlags() {
        XCTAssertTrue(APIService.claude.isRequired)
        XCTAssertTrue(APIService.plaidClientId.isRequired)
        XCTAssertTrue(APIService.plaidSecret.isRequired)
        XCTAssertFalse(APIService.marketData.isRequired)
        XCTAssertFalse(APIService.realEstate.isRequired)
        XCTAssertFalse(APIService.federalReserve.isRequired)
    }

    func testAPIService_BaseURLs() {
        XCTAssertEqual(APIService.baseURLs[.claude], "https://api.anthropic.com/v1")
        XCTAssertEqual(APIService.baseURLs[.realEstate], "https://api.realestatedata.com/v1")
        XCTAssertEqual(APIService.baseURLs[.marketData], "https://api.marketdata.com/v1")
        XCTAssertEqual(APIService.baseURLs[.federalReserve], "https://api.federalreserve.gov/v1")
        XCTAssertNil(APIService.baseURLs[.plaidClientId])
        XCTAssertNil(APIService.baseURLs[.plaidSecret])
    }

    func testAPIService_AllCases() {
        let allCases = APIService.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertContainsElements(allCases, [.claude, .plaidClientId, .plaidSecret, .marketData, .realEstate, .federalReserve])
    }

    // MARK: - Edge Cases and Validation Tests

    func testAPIKey_EmptyAndWhitespace() throws {
        let edgeCaseKeys = ["", " ", "\t", "\n", "   \t\n   "]

        for edgeKey in edgeCaseKeys {
            try secureKeyManager.saveAPIKey(edgeKey, forService: .claude)
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), edgeKey)

            secureKeyManager.deleteAPIKey(forService: .claude)
        }
    }

    func testAPIKey_VeryLongKey() throws {
        let veryLongKey = String(repeating: "abcdefghij", count: 1000) // 10,000 characters

        try secureKeyManager.saveAPIKey(veryLongKey, forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), veryLongKey)
    }

    func testAPIKey_UnicodeCharacters() throws {
        let unicodeKey = "🔑-test-key-with-unicode-中文-العربية-русский-日本語"

        try secureKeyManager.saveAPIKey(unicodeKey, forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), unicodeKey)
    }

    func testAPIKey_ControlCharacters() throws {
        let controlCharKey = "key\u{0000}with\u{0001}control\u{001F}chars"

        try secureKeyManager.saveAPIKey(controlCharKey, forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), controlCharKey)
    }

    func testMultipleOperations_SameService() throws {
        // Test rapid save/update/delete cycles
        for i in 0..<10 {
            let key = "test-key-\(i)"
            try secureKeyManager.saveAPIKey(key, forService: .claude)
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), key)

            let updatedKey = "updated-key-\(i)"
            try secureKeyManager.updateAPIKey(updatedKey, forService: .claude)
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), updatedKey)

            secureKeyManager.deleteAPIKey(forService: .claude)
            XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude))
        }
    }

    func testAllServices_Operations() throws {
        let allServices = APIService.allCases

        // Save keys for all services
        for (index, service) in allServices.enumerated() {
            let key = "test-key-for-\(service.rawValue)-\(index)"
            try secureKeyManager.saveAPIKey(key, forService: service)
        }

        // Verify all keys exist
        for (index, service) in allServices.enumerated() {
            let expectedKey = "test-key-for-\(service.rawValue)-\(index)"
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: service), expectedKey)
        }

        // Update all keys
        for (index, service) in allServices.enumerated() {
            let updatedKey = "updated-key-for-\(service.rawValue)-\(index)"
            try secureKeyManager.updateAPIKey(updatedKey, forService: service)
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: service), updatedKey)
        }

        // Delete all keys
        for service in allServices {
            secureKeyManager.deleteAPIKey(forService: service)
            XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: service))
        }
    }

    // MARK: - Mock-Specific Test Helpers

    func testMockHelpers_SetMockKey() {
        // Given
        secureKeyManager.setMockKey(testAPIKey, forService: .claude)

        // Then
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertEqual(try? secureKeyManager.getAPIKey(forService: .claude), testAPIKey)
    }

    func testMockHelpers_ClearAllKeys() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)

        // When
        secureKeyManager.clearAllKeys()

        // Then
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude))
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .plaidClientId))
    }

    func testMockHelpers_GetMockKeychain() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)

        // When
        let mockKeychain = secureKeyManager.getMockKeychain()

        // Then
        XCTAssertEqual(mockKeychain.count, 2)
        XCTAssertEqual(mockKeychain[APIService.claude.rawValue], testAPIKey)
        XCTAssertEqual(mockKeychain[APIService.plaidClientId.rawValue], testPlaidClientId)
    }

    func testMockHelpers_SimulateErrors() {
        // Test simulating different error types
        secureKeyManager.simulateError(.itemNotFound, for: .retrieve)
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude))

        secureKeyManager.resetErrorSimulation()
        secureKeyManager.simulateError(.duplicateItem, for: .save)
        secureKeyManager.setMockKey("existing", forService: .claude)
        XCTAssertThrowsError(try secureKeyManager.saveAPIKey("new", forService: .claude))

        secureKeyManager.resetErrorSimulation()
        secureKeyManager.simulateError(.invalidData, for: .retrieve)
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude))
    }

    func testMockHelpers_ResetErrorSimulation() {
        // Given
        secureKeyManager.shouldFailSave = true
        secureKeyManager.shouldFailRetrieve = true
        secureKeyManager.simulateKeyNotFound = true

        // When
        secureKeyManager.resetErrorSimulation()

        // Then
        XCTAssertFalse(secureKeyManager.shouldFailSave)
        XCTAssertFalse(secureKeyManager.shouldFailRetrieve)
        XCTAssertFalse(secureKeyManager.simulateKeyNotFound)
    }

    // MARK: - Service Integration Tests

    func testIntegration_MarketDataServiceCredentialRetrieval() throws {
        // Given
        try secureKeyManager.saveAPIKey(testMarketDataKey, forService: .marketData)

        // When - Simulate MarketDataService checking for credentials
        let hasMarketDataKey = secureKeyManager.hasMarketDataKey
        let retrievedKey = try? secureKeyManager.getAPIKey(forService: .marketData)

        // Then
        XCTAssertTrue(hasMarketDataKey)
        XCTAssertEqual(retrievedKey, testMarketDataKey)
    }

    func testIntegration_MarketDataServiceMissingCredentials() {
        // Given
        secureKeyManager.clearAllKeys()

        // When - Simulate MarketDataService checking for credentials
        let hasMarketDataKey = secureKeyManager.hasMarketDataKey
        let retrievedKey = try? secureKeyManager.getAPIKey(forService: .marketData)

        // Then
        XCTAssertFalse(hasMarketDataKey)
        XCTAssertNil(retrievedKey)
    }

    func testIntegration_AIAnalysisServiceCredentialValidation() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When - Simulate AIAnalysisService validating credentials
        let hasClaudeKey = secureKeyManager.hasClaudeKey
        let retrievedKey = try? secureKeyManager.getAPIKey(forService: .claude)
        let isValidKey = retrievedKey?.hasPrefix("sk-") == true

        // Then
        XCTAssertTrue(hasClaudeKey)
        XCTAssertNotNil(retrievedKey)
        XCTAssertTrue(isValidKey)
    }

    func testIntegration_AIAnalysisServiceInvalidCredentials() {
        // Given
        secureKeyManager.clearAllKeys()

        // When - Simulate AIAnalysisService checking for credentials
        let hasClaudeKey = secureKeyManager.hasClaudeKey
        let retrievedKey = try? secureKeyManager.getAPIKey(forService: .claude)

        // Then
        XCTAssertFalse(hasClaudeKey)
        XCTAssertNil(retrievedKey)
    }

    func testIntegration_PlaidServiceConfigurationStatus() throws {
        // Given - Save only client ID initially
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)

        // When/Then - Plaid requires both client ID and secret
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)

        // When - Add secret
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // Then - Now Plaid should be fully configured
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .plaidClientId), testPlaidClientId)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .plaidSecret), testPlaidSecret)
    }

    func testIntegration_PlaidServicePartialConfiguration() throws {
        // Given
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)

        // When - Check status with only client ID
        let hasPlaidKeys = secureKeyManager.hasPlaidKeys
        let missingKeys = secureKeyManager.getMissingKeys()

        // Then
        XCTAssertFalse(hasPlaidKeys)
        XCTAssertContainsElements(missingKeys, [.plaidSecret])
        XCTAssertFalse(missingKeys.contains(.plaidClientId))
    }

    func testIntegration_MultiServiceSetup() throws {
        // Given - Simulate setting up all services
        let serviceKeys: [APIService: String] = [
            .claude: testAPIKey,
            .plaidClientId: testPlaidClientId,
            .plaidSecret: testPlaidSecret,
            .marketData: testMarketDataKey,
            .realEstate: "test-real-estate-key",
            .federalReserve: "test-fed-key"
        ]

        // When
        for (service, key) in serviceKeys {
            try secureKeyManager.saveAPIKey(key, forService: service)
        }

        // Then - Check comprehensive status
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)
        XCTAssertTrue(secureKeyManager.getMissingKeys().isEmpty)

        // Verify all services can retrieve their credentials
        for (service, expectedKey) in serviceKeys {
            XCTAssertEqual(try secureKeyManager.getAPIKey(forService: service), expectedKey)
        }
    }

    func testIntegration_ServiceConfigurationFlow() throws {
        // Simulate the typical app configuration flow

        // Step 1: Check initial status (empty)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())
        let initialMissing = secureKeyManager.getMissingKeys()
        XCTAssertEqual(initialMissing.count, 3) // Claude, PlaidClient, PlaidSecret

        // Step 2: Add Claude key
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys()) // Still missing Plaid

        // Step 3: Add Plaid credentials
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys()) // Missing secret

        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys()) // All required keys present

        // Step 4: Add optional services
        try secureKeyManager.saveAPIKey(testMarketDataKey, forService: .marketData)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)

        // Step 5: Final verification
        XCTAssertTrue(secureKeyManager.getMissingKeys().isEmpty)
    }

    // MARK: - Performance Tests

    func testPerformance_SaveAPIKey() {
        measure {
            for i in 0..<100 {
                try? secureKeyManager.saveAPIKey("test-key-\(i)", forService: .claude)
            }
        }
    }

    func testPerformance_GetAPIKey() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When/Then
        measure {
            for _ in 0..<100 {
                _ = try? secureKeyManager.getAPIKey(forService: .claude)
            }
        }
    }

    func testPerformance_UpdateAPIKey() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)

        // When/Then
        measure {
            for i in 0..<100 {
                try? secureKeyManager.updateAPIKey("updated-key-\(i)", forService: .claude)
            }
        }
    }

    func testPerformance_DeleteAPIKey() throws {
        measure {
            for i in 0..<100 {
                try? secureKeyManager.saveAPIKey("test-key-\(i)", forService: .claude)
                secureKeyManager.deleteAPIKey(forService: .claude)
            }
        }
    }

    func testPerformance_StatusChecking() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // When/Then
        measure {
            for _ in 0..<100 {
                secureKeyManager.checkAPIKeysStatus()
                _ = secureKeyManager.hasAllRequiredKeys()
                _ = secureKeyManager.getMissingKeys()
            }
        }
    }

    func testPerformance_BulkOperations() {
        let services = APIService.allCases

        measure {
            // Save all keys
            for (index, service) in services.enumerated() {
                try? secureKeyManager.saveAPIKey("bulk-key-\(index)", forService: service)
            }

            // Read all keys
            for service in services {
                _ = try? secureKeyManager.getAPIKey(forService: service)
            }

            // Update all keys
            for (index, service) in services.enumerated() {
                try? secureKeyManager.updateAPIKey("updated-bulk-key-\(index)", forService: service)
            }

            // Delete all keys
            for service in services {
                secureKeyManager.deleteAPIKey(forService: service)
            }
        }
    }

    func testPerformance_LargeKeyHandling() {
        let largeKey = String(repeating: "a", count: 10000) // 10KB key

        measure {
            try? secureKeyManager.saveAPIKey(largeKey, forService: .claude)
            _ = try? secureKeyManager.getAPIKey(forService: .claude)
            try? secureKeyManager.updateAPIKey(largeKey + "updated", forService: .claude)
            secureKeyManager.deleteAPIKey(forService: .claude)
        }
    }

    // MARK: - Memory Tests

    func testMemory_BulkKeyStorage() {
        measureMemory {
            let services = APIService.allCases
            let largeKey = String(repeating: "memory-test", count: 1000)

            for service in services {
                try? secureKeyManager.saveAPIKey(largeKey, forService: service)
            }
        }
    }

    func testMemory_RepeatedOperations() {
        measureMemory {
            for i in 0..<1000 {
                try? secureKeyManager.saveAPIKey("memory-test-\(i)", forService: .claude)
                _ = try? secureKeyManager.getAPIKey(forService: .claude)
                secureKeyManager.deleteAPIKey(forService: .claude)
            }
        }
    }

    // MARK: - Thread Safety and Concurrency Tests

    func testConcurrency_ParallelSaveOperations() async throws {
        let concurrentOperations = 50
        let services = Array(repeating: APIService.allCases, count: concurrentOperations / APIService.allCases.count + 1).flatMap { $0 }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, service) in services.prefix(concurrentOperations).enumerated() {
                group.addTask { [weak self] in
                    try? await MainActor.run {
                        try self?.secureKeyManager.saveAPIKey("concurrent-key-\(index)", forService: service)
                    }
                }
            }

            for try await _ in group {}
        }

        // Verify operations completed successfully
        let keychainState = secureKeyManager.getMockKeychain()
        XCTAssertGreaterThan(keychainState.count, 0)
    }

    func testConcurrency_ParallelReadOperations() async throws {
        // Given
        let services = APIService.allCases
        for (index, service) in services.enumerated() {
            try secureKeyManager.saveAPIKey("read-test-\(index)", forService: service)
        }

        // When
        try await withThrowingTaskGroup(of: String?.self) { group in
            for service in services {
                group.addTask { [weak self] in
                    return await MainActor.run {
                        return try? self?.secureKeyManager.getAPIKey(forService: service)
                    }
                }
            }

            var results: [String?] = []
            for try await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, services.count)
            XCTAssertTrue(results.allSatisfy { $0 != nil })
        }
    }

    func testConcurrency_MixedOperations() async throws {
        let iterations = 20

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Save operations
            for i in 0..<iterations {
                group.addTask { [weak self] in
                    try? await MainActor.run {
                        try self?.secureKeyManager.saveAPIKey("mixed-save-\(i)", forService: .claude)
                    }
                }
            }

            // Read operations
            for i in 0..<iterations {
                group.addTask { [weak self] in
                    _ = await MainActor.run {
                        return try? self?.secureKeyManager.getAPIKey(forService: .claude)
                    }
                }
            }

            // Update operations
            for i in 0..<iterations {
                group.addTask { [weak self] in
                    try? await MainActor.run {
                        try self?.secureKeyManager.updateAPIKey("mixed-update-\(i)", forService: .marketData)
                    }
                }
            }

            // Status checking operations
            for i in 0..<iterations {
                group.addTask { [weak self] in
                    await MainActor.run {
                        self?.secureKeyManager.checkAPIKeysStatus()
                        _ = self?.secureKeyManager.hasAllRequiredKeys()
                        _ = self?.secureKeyManager.getMissingKeys()
                    }
                }
            }

            for try await _ in group {}
        }

        // Verify the keychain is in a consistent state
        await MainActor.run {
            secureKeyManager.checkAPIKeysStatus()
            let keychain = secureKeyManager.getMockKeychain()
            XCTAssertGreaterThan(keychain.count, 0)
        }
    }

    func testConcurrency_PublishedPropertyUpdates() async throws {
        var hasClaudeKeyUpdates: [Bool] = []
        var hasPlaidKeysUpdates: [Bool] = []
        var hasMarketDataKeyUpdates: [Bool] = []

        secureKeyManager.$hasClaudeKey
            .sink { hasClaudeKeyUpdates.append($0) }
            .store(in: &cancellables)

        secureKeyManager.$hasPlaidKeys
            .sink { hasPlaidKeysUpdates.append($0) }
            .store(in: &cancellables)

        secureKeyManager.$hasMarketDataKey
            .sink { hasMarketDataKeyUpdates.append($0) }
            .store(in: &cancellables)

        // Perform concurrent operations that should trigger published property updates
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try? await MainActor.run {
                    try self?.secureKeyManager.saveAPIKey(self?.testAPIKey ?? "", forService: .claude)
                }
            }

            group.addTask { [weak self] in
                try? await MainActor.run {
                    try self?.secureKeyManager.saveAPIKey(self?.testPlaidClientId ?? "", forService: .plaidClientId)
                    try self?.secureKeyManager.saveAPIKey(self?.testPlaidSecret ?? "", forService: .plaidSecret)
                }
            }

            group.addTask { [weak self] in
                try? await MainActor.run {
                    try self?.secureKeyManager.saveAPIKey(self?.testMarketDataKey ?? "", forService: .marketData)
                }
            }

            for try await _ in group {}
        }

        // Allow time for published property updates
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify published properties were updated
        XCTAssertTrue(hasClaudeKeyUpdates.contains(true))
        XCTAssertTrue(hasPlaidKeysUpdates.contains(true))
        XCTAssertTrue(hasMarketDataKeyUpdates.contains(true))
    }

    // MARK: - Keychain Isolation and Cleanup Tests

    func testIsolation_TestsDoNotAffectEachOther() throws {
        // This test verifies that tests are properly isolated

        // Test 1: Save a key
        try secureKeyManager.saveAPIKey("isolation-test-1", forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), "isolation-test-1")

        // Simulate test teardown/setup cycle
        tearDown()
        setUp()

        // Test 2: Key should not exist in new test (due to mock reset)
        XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: .claude))

        // Save different key
        try secureKeyManager.saveAPIKey("isolation-test-2", forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), "isolation-test-2")
    }

    func testCleanup_ClearAllKeysResetsState() throws {
        // Given
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)
        try secureKeyManager.saveAPIKey(testMarketDataKey, forService: .marketData)

        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)

        // When
        secureKeyManager.clearAllKeys()

        // Then
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertFalse(secureKeyManager.hasMarketDataKey)
        XCTAssertTrue(secureKeyManager.getMockKeychain().isEmpty)

        for service in APIService.allCases {
            XCTAssertThrowsError(try secureKeyManager.getAPIKey(forService: service))
        }
    }

    func testCleanup_ErrorSimulationReset() {
        // Given
        secureKeyManager.shouldFailSave = true
        secureKeyManager.shouldFailRetrieve = true
        secureKeyManager.shouldFailUpdate = true
        secureKeyManager.shouldFailDelete = true
        secureKeyManager.simulateKeyNotFound = true
        secureKeyManager.simulateInvalidData = true
        secureKeyManager.simulateDuplicateItem = true

        // When
        secureKeyManager.resetErrorSimulation()

        // Then
        XCTAssertFalse(secureKeyManager.shouldFailSave)
        XCTAssertFalse(secureKeyManager.shouldFailRetrieve)
        XCTAssertFalse(secureKeyManager.shouldFailUpdate)
        XCTAssertFalse(secureKeyManager.shouldFailDelete)
        XCTAssertFalse(secureKeyManager.simulateKeyNotFound)
        XCTAssertFalse(secureKeyManager.simulateInvalidData)
        XCTAssertFalse(secureKeyManager.simulateDuplicateItem)

        // Verify operations work normally
        XCTAssertNoThrow(try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude))
        XCTAssertNoThrow(try secureKeyManager.getAPIKey(forService: .claude))
    }

    func testCleanup_MockKeychainConsistency() throws {
        // Test that mock keychain state is consistent with published properties

        // Initially empty
        XCTAssertTrue(secureKeyManager.getMockKeychain().isEmpty)
        XCTAssertFalse(secureKeyManager.hasClaudeKey)

        // Add Claude key
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        let keychainAfterSave = secureKeyManager.getMockKeychain()
        XCTAssertEqual(keychainAfterSave.count, 1)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)

        // Add Plaid keys
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)
        let keychainAfterPlaid = secureKeyManager.getMockKeychain()
        XCTAssertEqual(keychainAfterPlaid.count, 3)
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)

        // Delete one Plaid key
        secureKeyManager.deleteAPIKey(forService: .plaidClientId)
        let keychainAfterDelete = secureKeyManager.getMockKeychain()
        XCTAssertEqual(keychainAfterDelete.count, 2)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys) // Should be false because both are required

        // Clear all
        secureKeyManager.clearAllKeys()
        XCTAssertTrue(secureKeyManager.getMockKeychain().isEmpty)
        XCTAssertFalse(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertFalse(secureKeyManager.hasMarketDataKey)
    }

    // MARK: - Integration Test with Real-World Scenarios

    func testRealWorldScenario_FirstTimeAppSetup() throws {
        // Simulate a user setting up the app for the first time

        // Step 1: Check if any keys are configured (should be none)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())
        let missingKeys = secureKeyManager.getMissingKeys()
        XCTAssertEqual(missingKeys.count, 3) // Claude, PlaidClient, PlaidSecret

        // Step 2: User enters Claude API key first
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())

        // Step 3: User attempts to use features - some should work, others should fail
        let claudeKey = try? secureKeyManager.getAPIKey(forService: .claude)
        XCTAssertNotNil(claudeKey)

        let plaidClientKey = try? secureKeyManager.getAPIKey(forService: .plaidClientId)
        XCTAssertNil(plaidClientKey)

        // Step 4: User completes Plaid setup
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // Step 5: All required keys should now be available
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())
        XCTAssertTrue(secureKeyManager.getMissingKeys().isEmpty)

        // Step 6: User optionally sets up market data
        try secureKeyManager.saveAPIKey(testMarketDataKey, forService: .marketData)
        XCTAssertTrue(secureKeyManager.hasMarketDataKey)
    }

    func testRealWorldScenario_KeyRotation() throws {
        // Simulate updating API keys (common security practice)

        // Setup initial keys
        try secureKeyManager.saveAPIKey("old-claude-key", forService: .claude)
        try secureKeyManager.saveAPIKey("old-plaid-client", forService: .plaidClientId)
        try secureKeyManager.saveAPIKey("old-plaid-secret", forService: .plaidSecret)

        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())

        // Rotate Claude key
        try secureKeyManager.updateAPIKey("new-claude-key", forService: .claude)
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .claude), "new-claude-key")
        XCTAssertTrue(secureKeyManager.hasClaudeKey)

        // Rotate Plaid keys
        try secureKeyManager.updateAPIKey("new-plaid-client", forService: .plaidClientId)
        try secureKeyManager.updateAPIKey("new-plaid-secret", forService: .plaidSecret)

        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .plaidClientId), "new-plaid-client")
        XCTAssertEqual(try secureKeyManager.getAPIKey(forService: .plaidSecret), "new-plaid-secret")
        XCTAssertTrue(secureKeyManager.hasPlaidKeys)

        // Verify all services still work
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())
    }

    func testRealWorldScenario_PartialServiceFailure() throws {
        // Simulate a scenario where some keys work and others fail

        // Setup working keys
        try secureKeyManager.saveAPIKey(testAPIKey, forService: .claude)
        try secureKeyManager.saveAPIKey(testPlaidClientId, forService: .plaidClientId)
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)

        // Verify initial state
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())

        // Simulate Plaid credentials becoming invalid (delete one)
        secureKeyManager.deleteAPIKey(forService: .plaidSecret)

        // Check status - Claude should still work, Plaid should not
        XCTAssertTrue(secureKeyManager.hasClaudeKey)
        XCTAssertFalse(secureKeyManager.hasPlaidKeys)
        XCTAssertFalse(secureKeyManager.hasAllRequiredKeys())

        let missingKeys = secureKeyManager.getMissingKeys()
        XCTAssertContainsElements(missingKeys, [.plaidSecret])
        XCTAssertFalse(missingKeys.contains(.claude))

        // Fix the Plaid issue
        try secureKeyManager.saveAPIKey(testPlaidSecret, forService: .plaidSecret)
        XCTAssertTrue(secureKeyManager.hasAllRequiredKeys())
    }
}