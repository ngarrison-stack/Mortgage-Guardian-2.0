// APIClient.swift
import Foundation

class APIClient {
    static let shared = APIClient()

    private var authToken: String = ""
    let baseURL = "https://h4rj2gpdza.execute-api.us-east-1.amazonaws.com/prod"

    private init() {}

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    private var authHeaders: [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]

        if !authToken.isEmpty {
            headers["Authorization"] = "Bearer \(authToken)"
        }

        return headers
    }

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Document Operations

    /// Delete a document from the backend.
    /// - Parameter documentId: The server-side document identifier.
    func deleteDocument(documentId: String) async throws {
        guard let url = URL(string: "\(baseURL)/v1/documents/\(documentId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.DELETE.rawValue

        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationError
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    /// Trigger backend document processing pipeline.
    /// - Parameters:
    ///   - documentId: The server-side document identifier.
    ///   - documentText: Optional extracted text to send for analysis.
    ///   - documentType: Optional document type hint (e.g. "mortgage_statement").
    func processDocument(documentId: String, documentText: String?, documentType: String?) async throws {
        guard let url = URL(string: "\(baseURL)/v1/documents/process") else {
            throw APIError.invalidURL
        }

        var body: [String: Any] = ["documentId": documentId]
        if let text = documentText {
            body["documentText"] = text
        }
        if let type = documentType {
            body["documentType"] = type
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.httpBody = bodyData

        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationError
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError
    case authenticationError

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
        case .networkError:
            return "Network connection unavailable"
        case .authenticationError:
            return "Authentication failed"
        }
    }
}