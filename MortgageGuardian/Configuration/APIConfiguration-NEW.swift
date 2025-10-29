import Foundation

/// API Configuration for Mortgage Guardian Backend
/// Updated for AWS-free backend (Railway/Vercel + Supabase)
struct APIConfiguration {
    // Backend API Configuration
    // IMPORTANT: Update this URL after deploying to Railway/Vercel/Render
    //
    // Examples:
    // - Railway: https://mortgage-guardian-production.up.railway.app
    // - Vercel: https://mortgage-guardian.vercel.app
    // - Render: https://mortgage-guardian.onrender.com
    //
    // For development/testing: http://localhost:3000
    //
    static let baseURL = "REPLACE_WITH_YOUR_DEPLOYMENT_URL"

    // API Endpoints
    enum Endpoints {
        static let claudeAnalyze = "/v1/ai/claude/analyze"
        static let claudeTest = "/v1/ai/claude/test"

        static let plaidLinkToken = "/v1/plaid/link_token"
        static let plaidSandboxToken = "/v1/plaid/sandbox_public_token"
        static let plaidExchangeToken = "/v1/plaid/exchange_token"
        static let plaidAccounts = "/v1/plaid/accounts"
        static let plaidTransactions = "/v1/plaid/transactions"

        static let documentsUpload = "/v1/documents/upload"
        static let documentsList = "/v1/documents"
        static let documentsGet = "/v1/documents"

        static let health = "/health"
    }

    // Request Headers
    static func defaultHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json",
            "User-Agent": "MortgageGuardian/2.0",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        ]
    }

    // Build full URL for endpoint
    static func buildURL(for endpoint: String) -> URL? {
        return URL(string: baseURL + endpoint)
    }

    // Test backend connection
    static func testConnection() async throws -> Bool {
        guard let url = buildURL(for: Endpoints.health) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }
}

/// Network service for backend communication
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
    func analyzeDocument(documentContent: String, documentType: String = "mortgage_statement") async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: APIConfiguration.Endpoints.claudeAnalyze) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let payload: [String: Any] = [
            "documentText": documentContent,
            "documentType": documentType,
            "model": "claude-3-5-sonnet-20241022",
            "maxTokens": 4096,
            "temperature": 0.1
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
    func callPlaidEndpoint(_ path: String, method: String = "POST", body: [String: Any]) async throws -> Data {
        let fullPath = "/v1/plaid/" + path
        guard let url = APIConfiguration.buildURL(for: fullPath) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    /// Upload document to backend
    func uploadDocument(
        documentId: String,
        userId: String,
        fileName: String,
        documentType: String,
        content: String,
        analysisResults: [String: Any]? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: APIConfiguration.Endpoints.documentsUpload) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        var payload: [String: Any] = [
            "documentId": documentId,
            "userId": userId,
            "fileName": fileName,
            "documentType": documentType,
            "content": content
        ]

        if let analysisResults = analysisResults {
            payload["analysisResults"] = analysisResults
        }

        if let metadata = metadata {
            payload["metadata"] = metadata
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    /// Get documents for user
    func getDocuments(userId: String, limit: Int = 50, offset: Int = 0) async throws -> Data {
        var components = URLComponents(string: APIConfiguration.baseURL + APIConfiguration.Endpoints.documentsList)!
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    /// Test backend health
    func testHealth() async throws -> Bool {
        return try await APIConfiguration.testConnection()
    }
}
