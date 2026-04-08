// APIClient.swift
import Foundation
import OSLog

// MARK: - Document API

/// Represents a document as returned by the Express backend.
struct ExpressDocument: Decodable {
    let id: String?
    let documentId: String?
    let userId: String?
    let fileName: String?
    let documentType: String?
    let status: String?
    let storagePath: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case userId = "user_id"
        case fileName = "file_name"
        case documentType = "document_type"
        case status
        case storagePath = "storage_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response wrapper for the Express backend document list endpoint.
struct ExpressDocumentListResponse: Decodable {
    let documents: [ExpressDocument]
    let total: Int?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case documents
        case total
        case userId = "user_id"
    }
}

extension APIClient {
    /// Fetches the list of documents from the Express backend.
    func fetchDocuments(limit: Int? = nil, offset: Int? = nil) async throws -> ExpressDocumentListResponse {
        var endpoint = "/v1/documents"
        var queryItems: [String] = []
        if let limit = limit { queryItems.append("limit=\(limit)") }
        if let offset = offset { queryItems.append("offset=\(offset)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return try await request(endpoint: endpoint, method: .GET, responseType: ExpressDocumentListResponse.self)
    }
}

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError
    case authenticationRequired
    case serverError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError:
            return "Failed to encode request data"
        case .authenticationRequired:
            return "Authentication required"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@Observable
class APIClient {
    static let shared = APIClient()

    private(set) var authToken: String = ""
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "APIClient")

    var baseURL: String { APIConfiguration.baseURL }
    var isAuthenticated: Bool { !authToken.isEmpty }

    // Retry configuration
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0
    private let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]

    var onAuthenticationRequired: (() async -> Void)?

    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Public API (backward-compatible)

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            responseType: responseType,
            attempt: 1
        )
    }

    // MARK: - Private retry logic

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        responseType: T.Type,
        attempt: Int
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MortgageGuardian-iOS/2.0", forHTTPHeaderField: "User-Agent")

        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        logger.info("Making \(method.rawValue) request to \(endpoint) (attempt \(attempt)/\(self.maxRetries + 1))")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Retry on retryable status codes
            if retryableStatusCodes.contains(httpResponse.statusCode) && attempt <= maxRetries {
                let delay = calculateBackoffDelay(for: attempt)
                logger.warning("Retryable error (status \(httpResponse.statusCode)), retrying in \(delay)s")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                logger.error("Authentication required - token may be expired")
                await onAuthenticationRequired?()
                throw APIError.authenticationRequired
            default:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        } catch let error as APIError {
            throw error
        } catch {
            // Network errors: retry with backoff
            if attempt <= maxRetries {
                let delay = calculateBackoffDelay(for: attempt)
                logger.warning("Network error, retrying in \(delay)s: \(error.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequest(
                    endpoint: endpoint,
                    method: method,
                    body: body,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }
            logger.error("Request failed after \(attempt) attempts: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }

    private func calculateBackoffDelay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.8...1.2)
        return min(exponentialDelay * jitter, maxDelay)
    }
}
