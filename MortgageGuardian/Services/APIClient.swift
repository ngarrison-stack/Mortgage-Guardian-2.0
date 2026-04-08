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
}

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
        }
    }
}