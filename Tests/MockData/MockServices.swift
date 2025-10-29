import Foundation
import Combine
import UIKit
@testable import MortgageGuardian

/// Mock service implementations for testing
/// Provides controllable, predictable service behavior for unit and integration tests

// MARK: - Mock AI Analysis Service

public final class MockAIAnalysisService: ObservableObject {

    @Published public var currentProgress: AIAnalysisService.AnalysisProgress?
    @Published public var isAnalyzing = false
    @Published public var analysisHistory: [AIAnalysisService.AIAnalysisResult] = []
    @Published public var configuration: AIAnalysisService.AIConfiguration = .default

    // Test configuration
    public var shouldFail = false
    public var failureError: Error = AIAnalysisService.AIAnalysisError.networkError(URLError(.notConnectedToInternet))
    public var simulateSlowResponse = false
    public var responseDelay: TimeInterval = 0.1
    public var mockResults: [AuditResult] = MockAuditResults.allResults

    public init() {}

    @MainActor
    public func analyzeDocument(
        _ document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction] = [],
        configuration: AIAnalysisService.AIConfiguration? = nil
    ) async throws -> AIAnalysisService.AIAnalysisResult {

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Simulate progress updates
        updateProgress(.initialization, percentComplete: 10, message: "Starting analysis")

        if simulateSlowResponse {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        updateProgress(.aiAnalysis, percentComplete: 50, message: "Analyzing document")

        if shouldFail {
            updateProgress(.completion, percentComplete: 100, message: "Analysis failed")
            throw failureError
        }

        updateProgress(.completion, percentComplete: 100, message: "Analysis complete")

        let result = AIAnalysisService.AIAnalysisResult(
            findings: mockResults,
            confidence: 0.92,
            analysisMetadata: AIAnalysisService.AIAnalysisResult.AnalysisMetadata(
                documentType: document.documentType,
                analysisType: .comprehensive,
                modelUsed: configuration?.model ?? self.configuration.model,
                promptVersion: "test-v1.0",
                analysisDate: Date(),
                contextLength: document.originalText.count
            ),
            rawResponse: MockServiceResponses.claudeAnalysisResponse,
            processingTime: responseDelay,
            tokensUsed: AIAnalysisService.AIAnalysisResult.TokenUsage(
                inputTokens: 1000,
                outputTokens: 500,
                totalTokens: 1500,
                estimatedCost: 0.004
            )
        )

        analysisHistory.append(result)
        return result
    }

    @MainActor
    public func performHybridAnalysis(
        document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction] = [],
        manualResults: [AuditResult] = []
    ) async throws -> [AuditResult] {

        let aiResult = try await analyzeDocument(
            document,
            userContext: userContext,
            bankTransactions: bankTransactions
        )

        // Combine AI and manual results
        var combinedResults = manualResults
        combinedResults.append(contentsOf: aiResult.findings)

        return combinedResults
    }

    @MainActor
    public func generateNoticeOfErrorLetter(
        for issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount,
        letterType: AIAnalysisService.LetterGenerationResult.LetterType = .noticeOfError
    ) async throws -> AIAnalysisService.LetterGenerationResult {

        if shouldFail {
            throw failureError
        }

        let mockLetterContent = """
        Notice of Error Letter

        Date: \(DateFormatter.fullDate.string(from: Date()))

        \(mortgageAccount.servicerName)
        RE: Loan Number \(mortgageAccount.loanNumber)

        Dear Sir or Madam,

        This letter serves as formal notice of errors in the servicing of my mortgage loan.

        Issues identified:
        \(issues.map { "• \($0.title)" }.joined(separator: "\n"))

        Please investigate and correct these errors within 30 days.

        Sincerely,
        \(userInfo.fullName)
        """

        return AIAnalysisService.LetterGenerationResult(
            letterContent: mockLetterContent,
            letterType: letterType,
            confidence: 0.95,
            metadata: AIAnalysisService.LetterGenerationResult.LetterMetadata(
                generatedDate: Date(),
                userInfo: userInfo,
                mortgageAccount: mortgageAccount,
                issues: issues,
                totalAffectedAmount: issues.compactMap { $0.affectedAmount }.reduce(0, +),
                urgencyLevel: .routine
            ),
            pdfData: MockFileData.createMockPDFData()
        )
    }

    private func updateProgress(
        _ step: AIAnalysisService.AnalysisProgress.AnalysisStep,
        percentComplete: Double,
        message: String
    ) {
        currentProgress = AIAnalysisService.AnalysisProgress(
            step: step,
            percentComplete: percentComplete,
            message: message,
            estimatedTimeRemaining: nil
        )
    }
}

// MARK: - Mock Document Processor

public final class MockDocumentProcessor: ObservableObject {

    @Published public var currentProgress: DocumentProcessor.ProcessingProgress?
    @Published public var isProcessing = false

    // Test configuration
    public var shouldFail = false
    public var failureError: Error = DocumentProcessor.ProcessingError.ocrProcessingFailed(NSError(domain: "Test", code: -1))
    public var simulateSlowProcessing = false
    public var processingDelay: TimeInterval = 0.1
    public var mockExtractedData: ExtractedData?

    public init() {}

    @MainActor
    public func processDocument(
        from imageData: Data,
        fileName: String,
        configuration: DocumentProcessor.OCRConfiguration = .default
    ) async throws -> MortgageDocument {

        isProcessing = true
        defer { isProcessing = false }

        // Simulate progress
        updateProgress(.validation, percentComplete: 10, message: "Validating document")

        if simulateSlowProcessing {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }

        updateProgress(.ocrProcessing, percentComplete: 50, message: "Extracting text")

        if shouldFail {
            updateProgress(.completion, percentComplete: 100, message: "Processing failed")
            throw failureError
        }

        updateProgress(.completion, percentComplete: 100, message: "Processing complete")

        let documentType = detectDocumentType(from: fileName)
        let extractedData = mockExtractedData ?? MockExtractedData.mortgageStatementData

        return MortgageDocument(
            fileName: fileName,
            documentType: documentType,
            uploadDate: Date(),
            originalText: MockDocumentTexts.mortgageStatementText,
            extractedData: extractedData,
            analysisResults: [],
            isAnalyzed: false
        )
    }

    @MainActor
    public func processDocument(
        from pdfData: Data,
        fileName: String,
        configuration: DocumentProcessor.OCRConfiguration = .default
    ) async throws -> MortgageDocument {

        return try await processDocument(from: pdfData, fileName: fileName, configuration: configuration)
    }

    @MainActor
    public func processBatch(
        documents: [(data: Data, fileName: String)],
        configuration: DocumentProcessor.OCRConfiguration = .default
    ) async throws -> [MortgageDocument] {

        var results: [MortgageDocument] = []

        for (index, document) in documents.enumerated() {
            updateProgress(.ocrProcessing, percentComplete: Double(index) / Double(documents.count) * 100, message: "Processing document \(index + 1)")

            do {
                let processed = try await processDocument(from: document.data, fileName: document.fileName, configuration: configuration)
                results.append(processed)
            } catch {
                // Continue processing other documents
                continue
            }
        }

        return results
    }

    private func detectDocumentType(from fileName: String) -> MortgageDocument.DocumentType {
        let lowercased = fileName.lowercased()

        if lowercased.contains("statement") {
            return .mortgageStatement
        } else if lowercased.contains("escrow") {
            return .escrowStatement
        } else if lowercased.contains("payment") || lowercased.contains("history") {
            return .paymentHistory
        } else {
            return .other
        }
    }

    private func updateProgress(
        _ step: DocumentProcessor.ProcessingProgress.ProcessingStep,
        percentComplete: Double,
        message: String
    ) {
        currentProgress = DocumentProcessor.ProcessingProgress(
            currentStep: step,
            percentComplete: percentComplete,
            message: message
        )
    }
}

// MARK: - Mock Audit Engine

public final class MockAuditEngine: ObservableObject {

    // Test configuration
    public var mockResults: [AuditResult] = MockAuditResults.allResults
    public var shouldFail = false
    public var failureError: Error = AuditEngine.AuditError.calculationError("Mock calculation failed")
    public var processingDelay: TimeInterval = 0.1

    public init() {}

    public func performAudit(
        on document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction] = []
    ) async throws -> [AuditResult] {

        if processingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        // Filter results based on document type
        return mockResults.filter { result in
            switch document.documentType {
            case .mortgageStatement:
                return true // All issues can appear in mortgage statements
            case .escrowStatement:
                return result.issueType == .escrowError || result.issueType == .lateTaxPayment || result.issueType == .lateInsurancePayment
            case .paymentHistory:
                return result.issueType == .latePaymentError || result.issueType == .misappliedPayment
            default:
                return false
            }
        }
    }

    public func validatePaymentAccuracy(
        paymentHistory: [ExtractedData.PaymentRecord],
        expectedPayment: Double,
        interestRate: Double
    ) async throws -> [AuditResult] {

        if shouldFail {
            throw failureError
        }

        return mockResults.filter { $0.issueType == .misappliedPayment || $0.issueType == .incorrectInterest }
    }

    public func analyzeEscrowAccount(
        escrowActivity: [ExtractedData.EscrowTransaction],
        monthlyEscrowPayment: Double
    ) async throws -> [AuditResult] {

        if shouldFail {
            throw failureError
        }

        return mockResults.filter { $0.issueType == .escrowError }
    }

    public func detectUnauthorizedFees(
        fees: [ExtractedData.Fee],
        userContext: User
    ) async throws -> [AuditResult] {

        if shouldFail {
            throw failureError
        }

        return mockResults.filter { $0.issueType == .unauthorizedFee }
    }
}

// MARK: - Mock Security Service

public final class MockSecurityService {

    // Test configuration
    public var shouldFailEncryption = false
    public var shouldFailDecryption = false
    public var shouldFailAuthentication = false
    public var mockEncryptedData: Data = Data("encrypted".utf8)

    public init() {}

    public func encryptData(_ data: Data, with key: String) async throws -> Data {
        if shouldFailEncryption {
            throw SecurityError.encryptionFailed
        }
        return mockEncryptedData
    }

    public func decryptData(_ encryptedData: Data, with key: String) async throws -> Data {
        if shouldFailDecryption {
            throw SecurityError.decryptionFailed
        }
        return Data("decrypted".utf8)
    }

    public func signRequest(_ request: URLRequest, with keyIdentifier: String) async throws -> URLRequest {
        if shouldFailAuthentication {
            throw SecurityError.authenticationFailed
        }

        var signedRequest = request
        signedRequest.setValue("Bearer mock-token", forHTTPHeaderField: "Authorization")
        return signedRequest
    }

    public func validateFileIntegrity(data: Data) -> Bool {
        return !shouldFailAuthentication && data.count > 0
    }

    public func generateSecureHash(for data: Data) -> String {
        return "mock-hash-\(data.count)"
    }
}

// MARK: - Mock Plaid Service

public final class MockPlaidService: ObservableObject {

    @Published public var isLinked = false
    @Published public var accounts: [PlaidAccount] = []
    @Published public var linkToken: String?

    // Test configuration
    public var shouldFailLinking = false
    public var shouldFailAccountFetch = false
    public var shouldFailTransactionFetch = false
    public var mockAccounts: [PlaidAccount] = [
        PlaidAccount(
            id: "ACC123",
            name: "Checking Account",
            type: "depository",
            subtype: "checking",
            balance: 5250.75
        )
    ]
    public var mockTransactions: [Transaction] = MockTransactions.mortgagePayments

    public init() {}

    @MainActor
    public func initializeLinkToken() async throws {
        if shouldFailLinking {
            throw PlaidService.PlaidError.initializationFailed("Mock initialization failed")
        }
        linkToken = "mock-link-token"
    }

    @MainActor
    public func handleLinkSuccess(publicToken: String, metadata: [String: Any]) async throws {
        if shouldFailLinking {
            throw PlaidService.PlaidError.linkingFailed("Mock linking failed")
        }
        isLinked = true
        accounts = mockAccounts
    }

    @MainActor
    public func fetchAccounts() async throws -> [PlaidAccount] {
        if shouldFailAccountFetch {
            throw PlaidService.PlaidError.networkError(URLError(.notConnectedToInternet))
        }
        accounts = mockAccounts
        return mockAccounts
    }

    @MainActor
    public func fetchTransactions(
        accountIds: [String],
        startDate: Date,
        endDate: Date
    ) async throws -> [Transaction] {
        if shouldFailTransactionFetch {
            throw PlaidService.PlaidError.networkError(URLError(.timedOut))
        }
        return mockTransactions.filter { transaction in
            accountIds.contains(transaction.accountId) &&
            transaction.date >= startDate &&
            transaction.date <= endDate
        }
    }

    @MainActor
    public func unlinkAccount() async throws {
        isLinked = false
        accounts = []
        linkToken = nil
    }
}

// MARK: - Mock Letter Generation Service

public final class MockLetterGenerationService {

    // Test configuration
    public var shouldFail = false
    public var failureError: Error = LetterGenerationService.LetterError.templateNotFound
    public var processingDelay: TimeInterval = 0.1

    public init() {}

    public func generateNoticeOfError(
        for issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) async throws -> LetterGenerationService.GeneratedLetter {

        if processingDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        let content = """
        Notice of Error Letter

        Date: \(DateFormatter.fullDate.string(from: Date()))

        \(mortgageAccount.servicerName)
        RE: Loan Number \(mortgageAccount.loanNumber)

        Dear Sir or Madam,

        This letter serves as formal notice of errors in the servicing of my mortgage loan.

        Issues identified:
        \(issues.map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))

        Please investigate and correct these errors within 30 days as required by RESPA.

        Sincerely,
        \(userInfo.fullName)
        """

        return LetterGenerationService.GeneratedLetter(
            content: content,
            type: .noticeOfError,
            generatedDate: Date(),
            userInfo: userInfo,
            mortgageAccount: mortgageAccount,
            issues: issues,
            pdfData: MockFileData.createMockPDFData()
        )
    }

    public func generateQualifiedWrittenRequest(
        for issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) async throws -> LetterGenerationService.GeneratedLetter {

        if shouldFail {
            throw failureError
        }

        let content = "Mock Qualified Written Request content"

        return LetterGenerationService.GeneratedLetter(
            content: content,
            type: .qualifiedWrittenRequest,
            generatedDate: Date(),
            userInfo: userInfo,
            mortgageAccount: mortgageAccount,
            issues: issues,
            pdfData: MockFileData.createMockPDFData()
        )
    }
}

// MARK: - Mock Network Session

public class MockURLSession: URLSession {

    public var mockData: Data?
    public var mockResponse: URLResponse?
    public var mockError: Error?
    public var requestDelay: TimeInterval = 0

    override public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }

        if let error = mockError {
            throw error
        }

        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, response)
    }

    public func setMockResponse(data: Data?, response: URLResponse?, error: Error?) {
        self.mockData = data
        self.mockResponse = response
        self.mockError = error
    }
}

// MARK: - Mock Supporting Types

public struct PlaidAccount {
    public let id: String
    public let name: String
    public let type: String
    public let subtype: String
    public let balance: Double

    public init(id: String, name: String, type: String, subtype: String, balance: Double) {
        self.id = id
        self.name = name
        self.type = type
        self.subtype = subtype
        self.balance = balance
    }
}

// MARK: - Mock Errors for Testing

public enum MockError: Error, LocalizedError {
    case intentionalFailure
    case timeoutSimulation
    case dataCorruption
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .intentionalFailure:
            return "Intentional test failure"
        case .timeoutSimulation:
            return "Simulated timeout"
        case .dataCorruption:
            return "Simulated data corruption"
        case .networkUnavailable:
            return "Simulated network unavailable"
        }
    }
}

// MARK: - Mock Secure Key Manager

@MainActor
public final class MockSecureKeyManager: ObservableObject {

    @Published public var hasClaudeKey = false
    @Published public var hasPlaidKeys = false
    @Published public var hasMarketDataKey = false

    // Test configuration
    public var shouldFailSave = false
    public var shouldFailRetrieve = false
    public var shouldFailUpdate = false
    public var shouldFailDelete = false
    public var simulateKeyNotFound = false
    public var simulateInvalidData = false
    public var simulateDuplicateItem = false

    // Mock storage
    private var mockKeychain: [String: String] = [:]

    public init() {}

    // MARK: - Save API Keys

    public func saveAPIKey(_ key: String, forService service: APIService) throws {
        if shouldFailSave {
            throw KeychainError.unexpectedStatus(errSecDuplicateItem)
        }

        if simulateDuplicateItem && mockKeychain[service.rawValue] != nil {
            throw KeychainError.duplicateItem
        }

        mockKeychain[service.rawValue] = key
        updatePublishedStatus()
    }

    // MARK: - Retrieve API Keys

    public func getAPIKey(forService service: APIService) throws -> String {
        if shouldFailRetrieve {
            throw KeychainError.unexpectedStatus(errSecAuthFailed)
        }

        if simulateKeyNotFound {
            throw KeychainError.itemNotFound
        }

        if simulateInvalidData {
            throw KeychainError.invalidData
        }

        guard let key = mockKeychain[service.rawValue] else {
            throw KeychainError.itemNotFound
        }

        return key
    }

    // MARK: - Update API Keys

    public func updateAPIKey(_ key: String, forService service: APIService) throws {
        if shouldFailUpdate {
            throw KeychainError.unexpectedStatus(errSecWritePerm)
        }

        // If key doesn't exist, create it (matching real implementation)
        if mockKeychain[service.rawValue] == nil {
            try saveAPIKey(key, forService: service)
        } else {
            mockKeychain[service.rawValue] = key
        }

        updatePublishedStatus()
    }

    // MARK: - Delete API Keys

    public func deleteAPIKey(forService service: APIService) {
        if shouldFailDelete {
            // In real implementation, delete doesn't throw, so we just ignore the failure
            return
        }

        mockKeychain.removeValue(forKey: service.rawValue)
        updatePublishedStatus()
    }

    // MARK: - Check Status

    public func checkAPIKeysStatus() {
        updatePublishedStatus()
    }

    // MARK: - Convenience Methods

    public func hasAllRequiredKeys() -> Bool {
        return hasClaudeKey && hasPlaidKeys
    }

    public func getMissingKeys() -> [APIService] {
        var missing: [APIService] = []

        if !hasClaudeKey {
            missing.append(.claude)
        }

        if (try? getAPIKey(forService: .plaidClientId)) == nil {
            missing.append(.plaidClientId)
        }

        if (try? getAPIKey(forService: .plaidSecret)) == nil {
            missing.append(.plaidSecret)
        }

        return missing
    }

    // MARK: - Test Helpers

    public func setMockKey(_ key: String, forService service: APIService) {
        mockKeychain[service.rawValue] = key
        updatePublishedStatus()
    }

    public func clearAllKeys() {
        mockKeychain.removeAll()
        updatePublishedStatus()
    }

    public func getMockKeychain() -> [String: String] {
        return mockKeychain
    }

    public func simulateError(_ error: KeychainError, for operation: MockOperation) {
        switch operation {
        case .save:
            shouldFailSave = true
        case .retrieve:
            shouldFailRetrieve = true
        case .update:
            shouldFailUpdate = true
        case .delete:
            shouldFailDelete = true
        }

        switch error {
        case .itemNotFound:
            simulateKeyNotFound = true
        case .duplicateItem:
            simulateDuplicateItem = true
        case .invalidData:
            simulateInvalidData = true
        case .unexpectedStatus:
            break // Handled by specific operation flags
        }
    }

    public func resetErrorSimulation() {
        shouldFailSave = false
        shouldFailRetrieve = false
        shouldFailUpdate = false
        shouldFailDelete = false
        simulateKeyNotFound = false
        simulateInvalidData = false
        simulateDuplicateItem = false
    }

    private func updatePublishedStatus() {
        hasClaudeKey = mockKeychain[APIService.claude.rawValue] != nil
        hasPlaidKeys = mockKeychain[APIService.plaidClientId.rawValue] != nil &&
                       mockKeychain[APIService.plaidSecret.rawValue] != nil
        hasMarketDataKey = mockKeychain[APIService.marketData.rawValue] != nil
    }

    public enum MockOperation {
        case save, retrieve, update, delete
    }
}

// MARK: - Service Factory for Tests

public class MockServiceFactory {

    public static func createAIAnalysisService(
        shouldFail: Bool = false,
        results: [AuditResult] = MockAuditResults.allResults
    ) -> MockAIAnalysisService {
        let service = MockAIAnalysisService()
        service.shouldFail = shouldFail
        service.mockResults = results
        return service
    }

    public static func createDocumentProcessor(
        shouldFail: Bool = false,
        extractedData: ExtractedData? = nil
    ) -> MockDocumentProcessor {
        let processor = MockDocumentProcessor()
        processor.shouldFail = shouldFail
        processor.mockExtractedData = extractedData
        return processor
    }

    public static func createAuditEngine(
        shouldFail: Bool = false,
        results: [AuditResult] = MockAuditResults.allResults
    ) -> MockAuditEngine {
        let engine = MockAuditEngine()
        engine.shouldFail = shouldFail
        engine.mockResults = results
        return engine
    }

    public static func createPlaidService(
        shouldFail: Bool = false,
        accounts: [PlaidAccount] = [],
        transactions: [Transaction] = []
    ) -> MockPlaidService {
        let service = MockPlaidService()
        service.shouldFailLinking = shouldFail
        service.shouldFailAccountFetch = shouldFail
        service.shouldFailTransactionFetch = shouldFail
        service.mockAccounts = accounts.isEmpty ? [PlaidAccount(id: "ACC123", name: "Test Account", type: "depository", subtype: "checking", balance: 1000.00)] : accounts
        service.mockTransactions = transactions.isEmpty ? MockTransactions.mortgagePayments : transactions
        return service
    }

    public static func createSecureKeyManager(
        withKeys keys: [APIService: String] = [:],
        shouldFail: Bool = false
    ) -> MockSecureKeyManager {
        let manager = MockSecureKeyManager()

        // Set up mock keys
        for (service, key) in keys {
            manager.setMockKey(key, forService: service)
        }

        // Configure failure modes if needed
        if shouldFail {
            manager.shouldFailRetrieve = true
            manager.shouldFailSave = true
        }

        return manager
    }
}