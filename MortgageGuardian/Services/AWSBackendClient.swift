import Foundation
import SwiftUI
import OSLog

/// HTTP client for communicating with the AWS backend APIs
@Observable
class AWSBackendClient {
    enum BackendError: Error, LocalizedError {
        case invalidURL
        case noData
        case networkError(Error)
        case invalidResponse
        case serverError(Int, String)
        case encodingError
        case decodingError(Error)
        case authenticationRequired

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received from server"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let code, let message):
                return "Server error (\(code)): \(message)"
            case .encodingError:
                return "Failed to encode request data"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .authenticationRequired:
                return "Authentication required"
            }
        }
    }

    // AWS Backend Configuration
    private let baseURL = "https://h4rj2gpdza.execute-api.us-east-1.amazonaws.com/prod"
    private let logger = Logger(subsystem: "com.mortgageguardian.backend", category: "AWSBackendClient")

    // Authentication state for Cognito integration
    @Published var isAuthenticated = false
    @Published var cognitoToken: String?
    @Published var cognitoRefreshToken: String?

    // Shared URL session with optimized configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: - Document Analysis Endpoints

    /// Analyze document using Claude AI on AWS backend
    func analyzeDocumentWithClaude(
        imageData: Data,
        documentType: DocumentType,
        expectedType: String? = nil
    ) async throws -> ClaudeAnalysisResponse {
        let endpoint = "/v1/ai/claude/analyze"

        let request = ClaudeAnalysisRequest(
            image: imageData.base64EncodedString(),
            documentType: documentType.rawValue,
            expectedType: expectedType
        )

        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: request,
            responseType: ClaudeAnalysisResponse.self
        )
    }

    /// Upload document for processing using AWS Textract
    func uploadDocumentForTextract(
        imageData: Data,
        documentType: DocumentType
    ) async throws -> DocumentUploadResponse {
        let endpoint = "/v1/documents/upload"

        let request = DocumentUploadRequest(
            image: imageData.base64EncodedString(),
            documentType: documentType.rawValue,
            useTextract: true
        )

        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: request,
            responseType: DocumentUploadResponse.self
        )
    }

    /// Get document analysis results
    func getDocumentAnalysis(documentId: String) async throws -> DocumentAnalysisResponse {
        let endpoint = "/v1/documents/\(documentId)/analysis"

        return try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            responseType: DocumentAnalysisResponse.self
        )
    }

    // MARK: - Plaid Integration Endpoints

    /// Verify bank data with Plaid
    func verifyBankData(
        accountData: BankAccountData,
        extractedData: [String: Any]
    ) async throws -> PlaidVerificationResponse {
        let endpoint = "/v1/plaid/verify"

        let request = PlaidVerificationRequest(
            accountData: accountData,
            extractedData: extractedData
        )

        return try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: request,
            responseType: PlaidVerificationResponse.self
        )
    }

    // MARK: - Authentication Methods

    /// Set Cognito authentication token
    func setCognitoToken(_ token: String, refreshToken: String? = nil) {
        cognitoToken = token
        cognitoRefreshToken = refreshToken
        isAuthenticated = true
        logger.info("Cognito authentication token updated")
    }

    /// Clear authentication state
    func clearAuthentication() {
        cognitoToken = nil
        cognitoRefreshToken = nil
        isAuthenticated = false
        logger.info("Authentication state cleared")
    }

    /// Check if token needs refresh (placeholder for future implementation)
    func needsTokenRefresh() -> Bool {
        // TODO: Implement JWT token expiry check when Cognito is fully integrated
        return false
    }

    /// Refresh Cognito token (placeholder for future implementation)
    func refreshCognitoToken() async throws {
        // TODO: Implement token refresh logic when Cognito is fully integrated
        guard let refreshToken = cognitoRefreshToken else {
            throw BackendError.authenticationRequired
        }
        logger.info("Token refresh would be implemented here with refresh token")
    }

    // MARK: - Retry Configuration

    private struct RetryConfig {
        let maxRetries: Int = 3
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    }

    private let retryConfig = RetryConfig()

    // MARK: - Generic HTTP Request Method

    private func makeRequest<T: Codable, R: Codable>(
        endpoint: String,
        method: String = "GET",
        body: T? = nil,
        responseType: R.Type
    ) async throws -> R {
        return try await makeRequestWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            responseType: responseType,
            attempt: 1
        )
    }

    private func makeRequestWithRetry<T: Codable, R: Codable>(
        endpoint: String,
        method: String = "GET",
        body: T? = nil,
        responseType: R.Type,
        attempt: Int
    ) async throws -> R {
        guard let url = URL(string: baseURL + endpoint) else {
            logger.error("Invalid URL: \(self.baseURL + endpoint)")
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MortgageGuardian-iOS/2.0", forHTTPHeaderField: "User-Agent")

        // Add Cognito authentication header if available
        if let token = cognitoToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Added Cognito authentication header")
        }

        // Add request body if provided
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(body)
            } catch {
                logger.error("Failed to encode request body: \(error.localizedDescription)")
                throw BackendError.encodingError
            }
        }

        logger.info("Making \(method) request to \(endpoint) (attempt \(attempt)/\(retryConfig.maxRetries + 1))")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw BackendError.invalidResponse
            }

            logger.info("Received response with status code: \(httpResponse.statusCode)")

            // Check if we should retry for certain status codes
            if retryConfig.retryableStatusCodes.contains(httpResponse.statusCode) && attempt <= retryConfig.maxRetries {
                let delay = calculateBackoffDelay(for: attempt)
                logger.warning("Retryable error (status \(httpResponse.statusCode)), retrying in \(delay) seconds")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await makeRequestWithRetry(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }

            // Handle HTTP status codes with enhanced error handling
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 401:
                logger.error("Authentication required - token may be expired")

                // Clear invalid token
                if cognitoToken != nil {
                    logger.info("Clearing potentially expired authentication token")
                    clearAuthentication()
                }

                throw BackendError.authenticationRequired
            case 403:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Access forbidden"
                logger.error("Access forbidden \(httpResponse.statusCode): \(errorMessage)")
                throw BackendError.serverError(httpResponse.statusCode, errorMessage)
            case 429:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Rate limit exceeded"
                logger.warning("Rate limit exceeded: \(errorMessage)")
                throw BackendError.serverError(httpResponse.statusCode, errorMessage)
            case 500...599:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                logger.error("Server error \(httpResponse.statusCode): \(errorMessage)")
                throw BackendError.serverError(httpResponse.statusCode, errorMessage)
            case 400...499:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Client error"
                logger.error("Client error \(httpResponse.statusCode): \(errorMessage)")
                throw BackendError.serverError(httpResponse.statusCode, errorMessage)
            default:
                logger.error("Unexpected status code: \(httpResponse.statusCode)")
                throw BackendError.invalidResponse
            }

            // Decode response
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let result = try decoder.decode(responseType, from: data)
                logger.info("Successfully decoded response on attempt \(attempt)")
                return result
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription)")
                logger.debug("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw BackendError.decodingError(error)
            }

        } catch let error as BackendError {
            // Don't retry BackendErrors unless they're network errors
            if case .networkError = error, attempt <= retryConfig.maxRetries {
                let delay = calculateBackoffDelay(for: attempt)
                logger.warning("Network error, retrying in \(delay) seconds: \(error.localizedDescription)")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await makeRequestWithRetry(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }
            throw error
        } catch {
            // Handle other network errors with retry
            if attempt <= retryConfig.maxRetries {
                let delay = calculateBackoffDelay(for: attempt)
                logger.warning("Network error, retrying in \(delay) seconds: \(error.localizedDescription)")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await makeRequestWithRetry(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }

            logger.error("Network request failed after \(attempt) attempts: \(error.localizedDescription)")
            throw BackendError.networkError(error)
        }
    }

    private func calculateBackoffDelay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = retryConfig.baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.8...1.2) // Add jitter to prevent thundering herd
        return min(exponentialDelay * jitter, retryConfig.maxDelay)
    }

    private func makeRequest<R: Codable>(
        endpoint: String,
        method: String = "GET",
        responseType: R.Type
    ) async throws -> R {
        return try await makeRequest(
            endpoint: endpoint,
            method: method,
            body: Optional<EmptyRequestBody>.none,
            responseType: responseType
        )
    }
}

// MARK: - Request/Response Models

enum DocumentType: String, Codable, CaseIterable {
    case bankStatement = "bank_statement"
    case payStub = "pay_stub"
    case taxReturn = "tax_return"
    case propertyAppraisal = "property_appraisal"
}

struct EmptyRequestBody: Codable {}

// Claude Analysis
struct ClaudeAnalysisRequest: Codable {
    let image: String // base64 encoded
    let documentType: String
    let expectedType: String?
}

struct ClaudeAnalysisResponse: Codable {
    let analysisId: String
    let documentType: String
    let extractedData: [String: AnyCodable]
    let confidence: Double
    let aiInsights: AIInsights?
    let processingTime: Double
    let timestamp: Date
}

struct AIInsights: Codable {
    let summary: String
    let keyFindings: [String]
    let confidenceScore: Double
    let recommendations: [String]?
}

// Document Upload
struct DocumentUploadRequest: Codable {
    let image: String // base64 encoded
    let documentType: String
    let useTextract: Bool
}

struct DocumentUploadResponse: Codable {
    let documentId: String
    let status: String
    let processingStarted: Date
    let estimatedCompletion: Date?
}

// Document Analysis
struct DocumentAnalysisResponse: Codable {
    let documentId: String
    let status: String // "processing", "completed", "failed"
    let extractedData: [String: AnyCodable]?
    let textractResults: TextractResults?
    let confidence: Double?
    let error: String?
    let completedAt: Date?
}

struct TextractResults: Codable {
    let blocks: [TextractBlock]
    let rawText: String
    let confidence: Double
}

struct TextractBlock: Codable {
    let blockType: String
    let text: String?
    let confidence: Double?
    let geometry: TextractGeometry?
}

struct TextractGeometry: Codable {
    let boundingBox: BoundingBox
}

struct BoundingBox: Codable {
    let width: Double
    let height: Double
    let left: Double
    let top: Double
}

// Plaid Integration
struct BankAccountData: Codable {
    let accountId: String?
    let bankName: String?
    let accountType: String?
    let balance: Double?
}

struct PlaidVerificationRequest: Codable {
    let accountData: BankAccountData
    let extractedData: [String: AnyCodable]
}

struct PlaidVerificationResponse: Codable {
    let verificationId: String
    let isVerified: Bool
    let discrepancies: [Discrepancy]
    let confidenceScore: Double
    let timestamp: Date
}

struct Discrepancy: Codable {
    let field: String
    let extractedValue: String
    let plaidValue: String
    let severity: String // "low", "medium", "high"
    let description: String
}

// MARK: - AnyCodable Helper

/// Helper type for encoding/decoding heterogeneous JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode AnyCodable")
            )
        }
    }
}

extension AnyCodable: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self.init(NSNull())
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, Any)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}