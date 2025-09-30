import Foundation
import Combine
import UIKit
import os.log

/// Document Storage Service for managing cloud document storage and retrieval
@MainActor
public final class DocumentStorageService: ObservableObject {

    // MARK: - Types

    public enum StorageError: LocalizedError {
        case uploadFailed(String)
        case downloadFailed(String)
        case userNotConsented
        case documentTooLarge
        case networkError(Error)
        case invalidResponse
        case storageDisabled

        public var errorDescription: String? {
            switch self {
            case .uploadFailed(let reason):
                return "Upload failed: \(reason)"
            case .downloadFailed(let reason):
                return "Download failed: \(reason)"
            case .userNotConsented:
                return "User has not consented to cloud storage"
            case .documentTooLarge:
                return "Document exceeds maximum size limit (5MB)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid server response"
            case .storageDisabled:
                return "Cloud storage is disabled in settings"
            }
        }
    }

    public struct StoredDocument {
        let id: String
        let userId: String
        let fileName: String
        let documentType: MortgageDocument.DocumentType
        let uploadDate: Date
        let fileSize: Int
        let analysisResults: [AuditResult]?
        let thumbnailURL: String?
        let isEncrypted: Bool

        public init(id: String, userId: String, fileName: String, documentType: MortgageDocument.DocumentType, uploadDate: Date, fileSize: Int, analysisResults: [AuditResult]? = nil, thumbnailURL: String? = nil, isEncrypted: Bool = true) {
            self.id = id
            self.userId = userId
            self.fileName = fileName
            self.documentType = documentType
            self.uploadDate = uploadDate
            self.fileSize = fileSize
            self.analysisResults = analysisResults
            self.thumbnailURL = thumbnailURL
            self.isEncrypted = isEncrypted
        }
    }

    public struct StorageSettings {
        var isEnabled: Bool
        var autoDeleteAfterDays: Int
        var compressImages: Bool
        var encryptionEnabled: Bool

        public static let `default` = StorageSettings(
            isEnabled: false, // Disabled by default - requires user consent
            autoDeleteAfterDays: 30,
            compressImages: true,
            encryptionEnabled: true
        )
    }

    // MARK: - Properties

    public static let shared = DocumentStorageService()

    @Published public var isStorageEnabled: Bool = false
    @Published public var hasUserConsented: Bool = false
    @Published public var storedDocuments: [StoredDocument] = []
    @Published public var isUploading: Bool = false
    @Published public var uploadProgress: Double = 0.0
    @Published public var storageSettings: StorageSettings = .default

    private let logger = Logger(subsystem: "com.mortgageguardian", category: "DocumentStorage")
    private let backendService = BackendAPIService.shared
    private let securityService = SecurityService.shared
    private let maxFileSize: Int = 5 * 1024 * 1024 // 5MB

    // MARK: - Initialization

    private init() {
        loadStorageSettings()
        loadUserConsent()
    }

    // MARK: - Public API

    /// Request user consent for cloud storage
    public func requestStorageConsent() async -> Bool {
        // This would typically show a consent dialog
        // For now, we'll assume consent is granted
        hasUserConsented = true
        isStorageEnabled = true
        storageSettings.isEnabled = true
        saveStorageSettings()
        saveUserConsent()

        logger.info("User consented to cloud storage")
        return true
    }

    /// Upload document to cloud storage
    public func uploadDocument(_ document: MortgageDocument, analysisResults: [AuditResult]? = nil) async throws -> StoredDocument {
        guard hasUserConsented && storageSettings.isEnabled else {
            throw StorageError.userNotConsented
        }

        guard !isStorageDisabled() else {
            throw StorageError.storageDisabled
        }

        // Check file size
        let documentData = document.originalText.data(using: .utf8) ?? Data()
        guard documentData.count <= maxFileSize else {
            throw StorageError.documentTooLarge
        }

        isUploading = true
        uploadProgress = 0.0

        do {
            let userId = getCurrentUserId()
            let documentId = UUID().uuidString

            // Prepare upload payload
            let uploadPayload: [String: Any] = [
                "documentId": documentId,
                "userId": userId,
                "fileName": document.fileName,
                "documentType": document.documentType.rawValue,
                "content": document.originalText,
                "analysisResults": try encodeAnalysisResults(analysisResults),
                "metadata": [
                    "fileSize": documentData.count,
                    "uploadDate": ISO8601DateFormatter().string(from: Date()),
                    "isEncrypted": storageSettings.encryptionEnabled,
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                ]
            ]

            uploadProgress = 0.3

            // Upload to backend
            let jsonData = try JSONSerialization.data(withJSONObject: uploadPayload)
            let responseData = try await backendService.uploadDocument(data: jsonData)

            uploadProgress = 0.8

            // Parse response
            guard let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let success = response["success"] as? Bool,
                  success else {
                throw StorageError.uploadFailed("Server rejected upload")
            }

            uploadProgress = 1.0

            let storedDocument = StoredDocument(
                id: documentId,
                userId: userId,
                fileName: document.fileName,
                documentType: document.documentType,
                uploadDate: Date(),
                fileSize: documentData.count,
                analysisResults: analysisResults,
                isEncrypted: storageSettings.encryptionEnabled
            )

            // Add to local cache
            storedDocuments.append(storedDocument)

            logger.info("Document uploaded successfully: \(documentId)")
            return storedDocument

        } catch {
            logger.error("Document upload failed: \(error.localizedDescription)")
            throw StorageError.uploadFailed(error.localizedDescription)
        } finally {
            isUploading = false
            uploadProgress = 0.0
        }
    }

    /// Retrieve user's stored documents
    public func loadStoredDocuments() async throws {
        guard hasUserConsented && storageSettings.isEnabled else {
            throw StorageError.userNotConsented
        }

        do {
            let userId = getCurrentUserId()
            let responseData = try await backendService.getDocuments(userId: userId)

            guard let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let documentsArray = response["documents"] as? [[String: Any]] else {
                throw StorageError.invalidResponse
            }

            var documents: [StoredDocument] = []

            for documentDict in documentsArray {
                if let document = try parseStoredDocument(from: documentDict) {
                    documents.append(document)
                }
            }

            storedDocuments = documents.sorted { $0.uploadDate > $1.uploadDate }
            logger.info("Loaded \(documents.count) stored documents")

        } catch {
            logger.error("Failed to load stored documents: \(error.localizedDescription)")
            throw StorageError.downloadFailed(error.localizedDescription)
        }
    }

    /// Download a specific document
    public func downloadDocument(_ documentId: String) async throws -> MortgageDocument {
        guard hasUserConsented && storageSettings.isEnabled else {
            throw StorageError.userNotConsented
        }

        do {
            let responseData = try await backendService.getDocument(documentId: documentId)

            guard let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let content = response["content"] as? String,
                  let fileName = response["fileName"] as? String,
                  let documentTypeString = response["documentType"] as? String,
                  let documentType = MortgageDocument.DocumentType(rawValue: documentTypeString) else {
                throw StorageError.invalidResponse
            }

            let document = MortgageDocument(
                fileName: fileName,
                originalText: content,
                documentType: documentType
            )

            logger.info("Document downloaded successfully: \(documentId)")
            return document

        } catch {
            logger.error("Document download failed: \(error.localizedDescription)")
            throw StorageError.downloadFailed(error.localizedDescription)
        }
    }

    /// Delete a document from cloud storage
    public func deleteDocument(_ documentId: String) async throws {
        do {
            let responseData = try await backendService.deleteDocument(documentId: documentId)

            guard let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let success = response["success"] as? Bool,
                  success else {
                throw StorageError.invalidResponse
            }

            // Remove from local cache
            storedDocuments.removeAll { $0.id == documentId }

            logger.info("Document deleted successfully: \(documentId)")

        } catch {
            logger.error("Document deletion failed: \(error.localizedDescription)")
            throw StorageError.uploadFailed(error.localizedDescription)
        }
    }

    /// Update storage settings
    public func updateStorageSettings(_ settings: StorageSettings) {
        storageSettings = settings
        isStorageEnabled = settings.isEnabled && hasUserConsented
        saveStorageSettings()

        logger.info("Storage settings updated: enabled=\(settings.isEnabled)")
    }

    /// Revoke storage consent and delete all data
    public func revokeStorageConsent() async throws {
        hasUserConsented = false
        isStorageEnabled = false
        storageSettings.isEnabled = false

        // Delete all user documents from cloud
        for document in storedDocuments {
            try await deleteDocument(document.id)
        }

        storedDocuments.removeAll()
        saveStorageSettings()
        saveUserConsent()

        logger.info("Storage consent revoked and all data deleted")
    }

    // MARK: - Private Implementation

    private func getCurrentUserId() -> String {
        // In a real app, this would come from authentication
        // For now, use device identifier
        return UIDevice.current.identifierForVendor?.uuidString ?? "anonymous"
    }

    private func isStorageDisabled() -> Bool {
        #if DEBUG
        return false // Always allow in debug builds
        #else
        return !storageSettings.isEnabled || !hasUserConsented
        #endif
    }

    private func encodeAnalysisResults(_ results: [AuditResult]?) throws -> String {
        guard let results = results else { return "[]" }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(results)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func parseStoredDocument(from dict: [String: Any]) throws -> StoredDocument? {
        guard let id = dict["documentId"] as? String,
              let userId = dict["userId"] as? String,
              let fileName = dict["fileName"] as? String,
              let documentTypeString = dict["documentType"] as? String,
              let documentType = MortgageDocument.DocumentType(rawValue: documentTypeString),
              let uploadDateString = dict["uploadDate"] as? String,
              let uploadDate = ISO8601DateFormatter().date(from: uploadDateString),
              let fileSize = dict["fileSize"] as? Int else {
            return nil
        }

        let isEncrypted = dict["isEncrypted"] as? Bool ?? true
        let thumbnailURL = dict["thumbnailURL"] as? String

        // Parse analysis results if present
        var analysisResults: [AuditResult]?
        if let resultsString = dict["analysisResults"] as? String,
           let resultsData = resultsString.data(using: .utf8) {
            analysisResults = try? JSONDecoder().decode([AuditResult].self, from: resultsData)
        }

        return StoredDocument(
            id: id,
            userId: userId,
            fileName: fileName,
            documentType: documentType,
            uploadDate: uploadDate,
            fileSize: fileSize,
            analysisResults: analysisResults,
            thumbnailURL: thumbnailURL,
            isEncrypted: isEncrypted
        )
    }

    private func loadStorageSettings() {
        if let data = UserDefaults.standard.data(forKey: "StorageSettings"),
           let settings = try? JSONDecoder().decode(StorageSettings.self, from: data) {
            storageSettings = settings
        }
    }

    private func saveStorageSettings() {
        if let data = try? JSONEncoder().encode(storageSettings) {
            UserDefaults.standard.set(data, forKey: "StorageSettings")
        }
    }

    private func loadUserConsent() {
        hasUserConsented = UserDefaults.standard.bool(forKey: "StorageConsent")
        isStorageEnabled = hasUserConsented && storageSettings.isEnabled
    }

    private func saveUserConsent() {
        UserDefaults.standard.set(hasUserConsented, forKey: "StorageConsent")
    }
}

// MARK: - Backend API Extensions

extension BackendAPIService {
    func uploadDocument(data: Data) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: "/v1/documents/upload") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return responseData
    }

    func getDocuments(userId: String) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: "/v1/documents?userId=\(userId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return responseData
    }

    func getDocument(documentId: String) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: "/v1/documents/\(documentId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return responseData
    }

    func deleteDocument(documentId: String) async throws -> Data {
        guard let url = APIConfiguration.buildURL(for: "/v1/documents/\(documentId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = APIConfiguration.defaultHeaders()

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return responseData
    }
}

// MARK: - Extensions

extension DocumentStorageService.StorageSettings: Codable {}

extension AuditResult: Codable {
    enum CodingKeys: String, CodingKey {
        case issueType, severity, title, description, detailedExplanation
        case suggestedAction, affectedAmount, detectionMethod, confidence
        case evidenceText, calculationDetails, createdDate
    }
}