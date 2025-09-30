import Foundation

/// API Configuration for Mortgage Guardian Backend
struct APIConfiguration {
    // AWS API Gateway Configuration - Public endpoint, no API key needed!
    static let baseURL = "https://h4rj2gpdza.execute-api.us-east-1.amazonaws.com/prod"

    // API Endpoints
    enum Endpoints {
        static let claudeAnalyze = "/v1/ai/claude/analyze"
        static let plaidBase = "/v1/plaid"
        static let health = "/health"
    }

    // Request Headers - No API key needed, just standard headers
    static func defaultHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json",
            "User-Agent": "MortgageGuardian/1.0",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
    }

    // Build full URL for endpoint
    static func buildURL(for endpoint: String) -> URL? {
        return URL(string: baseURL + endpoint)
    }
}

/// Network service for AWS backend communication
class BackendAPIService {
    static let shared = BackendAPIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    /// Send document for Claude analysis via backend
    func analyzeDocument(documentContent: String) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: APIConfiguration.Endpoints.claudeAnalyze) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let payload = [
            "document": documentContent,
            "analysisType": "comprehensive"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    /// Call Plaid API via backend proxy
    func callPlaidEndpoint(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let fullPath = APIConfiguration.Endpoints.plaidBase + "/" + path
        guard let url = APIConfiguration.buildURL(for: fullPath) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}