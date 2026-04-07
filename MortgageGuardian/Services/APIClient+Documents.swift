// APIClient+Documents.swift
import Foundation

// MARK: - Document Type

enum ExpressDocumentType: String, Codable, CaseIterable {
    case bankStatement = "bank_statement"
    case payStub = "pay_stub"
    case taxReturn = "tax_return"
    case propertyAppraisal = "property_appraisal"
    case mortgageStatement = "mortgage_statement"
    case closingDisclosure = "closing_disclosure"
    case escrowAnalysis = "escrow_analysis"
    case other = "other"
}

// MARK: - Claude Analysis Models

struct ClaudeAnalysisRequest: Encodable {
    let documentText: String
    let documentType: String
    let prompt: String?
    let model: String?
    let maxTokens: Int?
    let temperature: Double?
}

struct ClaudeAnalysisResponse: Decodable {
    let success: Bool
    let analysis: String
    let model: String?
    let usage: TokenUsage?
    let timestamp: String?
}

struct TokenUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Document Upload Models

struct DocumentUploadRequest: Encodable {
    let documentId: String
    let fileName: String
    let documentType: String
    let content: String // base64
    let analysisResults: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
}

struct DocumentUploadResponse: Decodable {
    let success: Bool
    let documentId: String?
    let storagePath: String?
    let message: String?
}

// MARK: - Document List Models

struct DocumentListResponse: Decodable {
    let documents: [ExpressDocument]
    let total: Int?
    let userId: String?
}

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

// MARK: - Document Analysis Models

struct ExpressDocumentAnalysisResponse: Decodable {
    let documentId: String?
    let status: String?
    let analysis: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case status
        case analysis
    }
}

// MARK: - Document Status Models

struct DocumentStatusResponse: Decodable {
    let documentId: String?
    let step: String?
    let status: String?
    let progress: Double?

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case step
        case status
        case progress
    }
}

// MARK: - Document Process Request

struct DocumentProcessRequest: Encodable {
    let documentId: String
    let documentText: String?
    let documentType: String?
}

// MARK: - Delete Response

struct DeleteResponse: Decodable {
    let success: Bool
    let message: String?
}

// MARK: - APIClient Document & Claude Methods

extension APIClient {

    // MARK: Claude Analysis

    func analyzeDocumentWithClaude(
        documentText: String,
        documentType: String,
        prompt: String? = nil,
        model: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) async throws -> ClaudeAnalysisResponse {
        let requestBody = ClaudeAnalysisRequest(
            documentText: documentText,
            documentType: documentType,
            prompt: prompt,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
        )
        let body = try JSONEncoder().encode(requestBody)
        return try await request(
            endpoint: "/v1/ai/claude/analyze",
            method: .POST,
            body: body,
            responseType: ClaudeAnalysisResponse.self
        )
    }

    // MARK: Document Upload

    func uploadDocument(
        documentId: String,
        fileName: String,
        documentType: String,
        content: String,
        analysisResults: [String: AnyCodable]? = nil,
        metadata: [String: AnyCodable]? = nil
    ) async throws -> DocumentUploadResponse {
        let requestBody = DocumentUploadRequest(
            documentId: documentId,
            fileName: fileName,
            documentType: documentType,
            content: content,
            analysisResults: analysisResults,
            metadata: metadata
        )
        let body = try JSONEncoder().encode(requestBody)
        return try await request(
            endpoint: "/v1/documents/upload",
            method: .POST,
            body: body,
            responseType: DocumentUploadResponse.self
        )
    }

    // MARK: Document List

    func fetchDocuments(limit: Int? = nil, offset: Int? = nil) async throws -> DocumentListResponse {
        var endpoint = "/v1/documents"
        var queryItems: [String] = []
        if let limit { queryItems.append("limit=\(limit)") }
        if let offset { queryItems.append("offset=\(offset)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return try await request(
            endpoint: endpoint,
            method: .GET,
            responseType: DocumentListResponse.self
        )
    }

    // MARK: Get Single Document

    func getDocument(documentId: String) async throws -> ExpressDocument {
        return try await request(
            endpoint: "/v1/documents/\(documentId)",
            method: .GET,
            responseType: ExpressDocument.self
        )
    }

    // MARK: Document Analysis

    func getDocumentAnalysis(documentId: String) async throws -> ExpressDocumentAnalysisResponse {
        return try await request(
            endpoint: "/v1/documents/\(documentId)/analysis",
            method: .GET,
            responseType: ExpressDocumentAnalysisResponse.self
        )
    }

    // MARK: Delete Document

    func deleteDocument(documentId: String) async throws {
        let _: DeleteResponse = try await request(
            endpoint: "/v1/documents/\(documentId)",
            method: .DELETE,
            responseType: DeleteResponse.self
        )
    }

    // MARK: Process Document

    func processDocument(
        documentId: String,
        documentText: String? = nil,
        documentType: String? = nil
    ) async throws {
        let requestBody = DocumentProcessRequest(
            documentId: documentId,
            documentText: documentText,
            documentType: documentType
        )
        let body = try JSONEncoder().encode(requestBody)
        let _: DeleteResponse = try await request(
            endpoint: "/v1/documents/process",
            method: .POST,
            body: body,
            responseType: DeleteResponse.self
        )
    }

    // MARK: Document Status

    func getDocumentStatus(documentId: String) async throws -> DocumentStatusResponse {
        return try await request(
            endpoint: "/v1/documents/\(documentId)/status",
            method: .GET,
            responseType: DocumentStatusResponse.self
        )
    }

    // MARK: Health Check

    func checkHealth() async throws -> HealthResponse {
        return try await request(
            endpoint: "/health",
            method: .GET,
            responseType: HealthResponse.self
        )
    }
}

// MARK: - Health Response

struct HealthResponse: Decodable {
    let status: String
    let version: String?
    let uptime: Double?
}
