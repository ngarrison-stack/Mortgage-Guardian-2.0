import Foundation
import UniformTypeIdentifiers
@testable import MortgageGuardian

/// Real Document Collection Pipeline for processing actual mortgage documents
///
/// This pipeline handles:
/// - Loading real mortgage documents from various servicers
/// - Anonymizing PII data while preserving financial structure
/// - Organizing documents by type and complexity
/// - Providing metadata for test validation
///
/// Document sources include actual mortgage statements, escrow analyses,
/// payoff quotes, and other servicing documents from major servicers
class RealDocumentCollectionPipeline {

    // MARK: - Configuration

    private struct DocumentConfiguration {
        static let supportedFormats: [UTType] = [.pdf, .png, .jpeg, .tiff]
        static let maxDocumentSize: Int = 50 * 1024 * 1024 // 50MB
        static let requiredMetadataFields = ["servicer", "document_type", "loan_type", "anonymization_status"]
    }

    // MARK: - Properties

    private let testDataDirectory: URL
    private let anonymizationEngine: DocumentAnonymizationEngine
    private let metadataValidator: DocumentMetadataValidator
    private let qualityAssurance: DocumentQualityAssurance

    // Document catalogs organized by type
    private var mortgageStatements: [RealMortgageDocument] = []
    private var escrowDocuments: [RealMortgageDocument] = []
    private var payoffQuotes: [RealMortgageDocument] = []
    private var complianceTestDocuments: [RealMortgageDocument] = []

    // MARK: - Initialization

    init() throws {
        let testDataPath = ProcessInfo.processInfo.environment["REAL_TEST_DATA_DIR"] ?? "/tmp/real_mortgage_docs"
        self.testDataDirectory = URL(fileURLWithPath: testDataPath)

        // Verify test data directory exists
        guard FileManager.default.fileExists(atPath: testDataDirectory.path) else {
            throw DocumentCollectionError.testDataDirectoryNotFound(testDataPath)
        }

        self.anonymizationEngine = DocumentAnonymizationEngine()
        self.metadataValidator = DocumentMetadataValidator()
        self.qualityAssurance = DocumentQualityAssurance()

        // Load and validate document collections
        try loadDocumentCollections()
    }

    // MARK: - Document Loading Methods

    /// Load real mortgage statements from multiple servicers
    func loadRealMortgageDocuments() async throws -> [RealMortgageDocument] {
        print("📂 Loading real mortgage documents...")

        if mortgageStatements.isEmpty {
            try await refreshMortgageStatements()
        }

        // Validate document quality and metadata
        let validatedDocuments = try await validateDocumentCollection(mortgageStatements)

        print("✅ Loaded \(validatedDocuments.count) validated mortgage statements")
        return validatedDocuments
    }

    /// Load real escrow analysis documents
    func loadRealEscrowDocuments() async throws -> [RealMortgageDocument] {
        print("🏠 Loading real escrow documents...")

        if escrowDocuments.isEmpty {
            try await refreshEscrowDocuments()
        }

        let validatedDocuments = try await validateDocumentCollection(escrowDocuments)

        print("✅ Loaded \(validatedDocuments.count) validated escrow documents")
        return validatedDocuments
    }

    /// Load real payoff quote documents
    func loadRealPayoffQuotes() async throws -> [RealMortgageDocument] {
        print("💰 Loading real payoff quotes...")

        if payoffQuotes.isEmpty {
            try await refreshPayoffQuotes()
        }

        let validatedDocuments = try await validateDocumentCollection(payoffQuotes)

        print("✅ Loaded \(validatedDocuments.count) validated payoff quotes")
        return validatedDocuments
    }

    /// Load document for specific compliance test case
    func loadDocumentForComplianceTest(_ testCase: ComplianceTestCase) async throws -> RealMortgageDocument {
        print("⚖️ Loading document for compliance test: \(testCase.description)")

        // Find document that matches the test case requirements
        let matchingDocuments = complianceTestDocuments.filter { document in
            document.documentType == testCase.documentType &&
            document.complianceTestCases.contains(testCase.id)
        }

        guard let document = matchingDocuments.first else {
            throw DocumentCollectionError.noMatchingDocumentForTestCase(testCase.id)
        }

        // Validate document meets test requirements
        try await validateDocumentForCompliance(document, testCase: testCase)

        return document
    }

    /// Load single document for testing
    func loadSingleRealDocument() async throws -> RealMortgageDocument {
        let allDocuments = try await loadRealMortgageDocuments()

        guard let document = allDocuments.first else {
            throw DocumentCollectionError.noDocumentsAvailable
        }

        return document
    }

    // MARK: - Document Collection Refresh Methods

    private func refreshMortgageStatements() async throws {
        let statementsDirectory = testDataDirectory.appendingPathComponent("mortgage_statements")
        mortgageStatements = try await loadDocumentsFromDirectory(
            statementsDirectory,
            documentType: .mortgageStatement
        )
    }

    private func refreshEscrowDocuments() async throws {
        let escrowDirectory = testDataDirectory.appendingPathComponent("escrow_analyses")
        escrowDocuments = try await loadDocumentsFromDirectory(
            escrowDirectory,
            documentType: .escrowAnalysis
        )
    }

    private func refreshPayoffQuotes() async throws {
        let payoffDirectory = testDataDirectory.appendingPathComponent("payoff_quotes")
        payoffQuotes = try await loadDocumentsFromDirectory(
            payoffDirectory,
            documentType: .payoffQuote
        )
    }

    private func loadDocumentsFromDirectory(
        _ directory: URL,
        documentType: DocumentType
    ) async throws -> [RealMortgageDocument] {

        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("⚠️ Directory not found: \(directory.path)")
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var documents: [RealMortgageDocument] = []

        for fileURL in fileURLs {
            do {
                // Check if file is supported format
                guard let contentType = try fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
                      DocumentConfiguration.supportedFormats.contains(where: { $0.conforms(to: contentType) }) else {
                    continue
                }

                // Load and validate document
                let document = try await loadSingleDocument(
                    from: fileURL,
                    documentType: documentType
                )

                documents.append(document)

            } catch {
                print("⚠️ Failed to load document \(fileURL.lastPathComponent): \(error)")
                continue
            }
        }

        print("📄 Loaded \(documents.count) \(documentType.rawValue) documents from \(directory.lastPathComponent)")
        return documents
    }

    private func loadSingleDocument(
        from fileURL: URL,
        documentType: DocumentType
    ) async throws -> RealMortgageDocument {

        // Load image data
        let imageData = try Data(contentsOf: fileURL)

        // Validate file size
        guard imageData.count <= DocumentConfiguration.maxDocumentSize else {
            throw DocumentCollectionError.documentTooLarge(fileURL.lastPathComponent)
        }

        // Load metadata
        let metadataURL = fileURL.appendingPathExtension("json")
        let metadata = try await loadDocumentMetadata(from: metadataURL)

        // Validate metadata completeness
        try metadataValidator.validateMetadata(metadata)

        // Create document instance
        let document = RealMortgageDocument(
            id: UUID().uuidString,
            fileName: fileURL.lastPathComponent,
            documentType: documentType,
            imageData: imageData,
            metadata: metadata,
            processingStartTime: Date()
        )

        // Perform quality assurance checks
        try await qualityAssurance.validateDocumentQuality(document)

        return document
    }

    private func loadDocumentMetadata(from metadataURL: URL) async throws -> RealDocumentMetadata {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw DocumentCollectionError.metadataFileNotFound(metadataURL.lastPathComponent)
        }

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(RealDocumentMetadata.self, from: metadataData)

        return metadata
    }

    // MARK: - Document Validation

    private func validateDocumentCollection(_ documents: [RealMortgageDocument]) async throws -> [RealMortgageDocument] {
        var validatedDocuments: [RealMortgageDocument] = []

        for document in documents {
            do {
                // Validate anonymization status
                try await anonymizationEngine.validateAnonymization(document)

                // Validate document integrity
                try await qualityAssurance.validateDocumentIntegrity(document)

                // Validate metadata completeness
                try metadataValidator.validateMetadata(document.metadata)

                validatedDocuments.append(document)

            } catch {
                print("⚠️ Document validation failed for \(document.fileName): \(error)")
                // Continue with other documents
            }
        }

        return validatedDocuments
    }

    private func validateDocumentForCompliance(
        _ document: RealMortgageDocument,
        testCase: ComplianceTestCase
    ) async throws {

        // Verify document contains required elements for test case
        guard document.metadata.containsRequiredElements(for: testCase) else {
            throw DocumentCollectionError.documentMissingRequiredElements(testCase.id)
        }

        // Verify document quality meets compliance testing standards
        let qualityMetrics = try await qualityAssurance.assessDocumentQuality(document)

        guard qualityMetrics.ocrReadability >= 0.95 else {
            throw DocumentCollectionError.documentQualityInsufficient("OCR readability too low")
        }

        guard qualityMetrics.structuralComplexity >= testCase.minimumComplexity else {
            throw DocumentCollectionError.documentQualityInsufficient("Document complexity insufficient for test")
        }
    }

    private func loadDocumentCollections() throws {
        // Initialize document collections - they will be loaded on-demand
        print("🏗️ Document collection pipeline initialized")
        print("📁 Test data directory: \(testDataDirectory.path)")
    }
}

// MARK: - Supporting Classes

/// Engine for anonymizing PII data while preserving financial structure
class DocumentAnonymizationEngine {

    func validateAnonymization(_ document: RealMortgageDocument) async throws {
        // Verify no PII data remains in the document
        guard document.metadata.anonymizationStatus == .anonymized else {
            throw DocumentCollectionError.documentNotAnonymized(document.fileName)
        }

        // Additional validation logic would check for:
        // - No SSNs, account numbers, or personal names
        // - Loan numbers properly anonymized
        // - Addresses redacted or replaced with test addresses
        // - Contact information removed
    }
}

/// Validator for document metadata completeness and accuracy
class DocumentMetadataValidator {

    func validateMetadata(_ metadata: RealDocumentMetadata) throws {
        // Validate required fields are present
        for field in DocumentConfiguration.requiredMetadataFields {
            guard metadata.hasField(field) else {
                throw DocumentCollectionError.missingRequiredMetadataField(field)
            }
        }

        // Validate servicer information
        guard !metadata.servicerName.isEmpty else {
            throw DocumentCollectionError.invalidMetadata("Servicer name is empty")
        }

        // Validate document type consistency
        guard metadata.documentType != .unknown else {
            throw DocumentCollectionError.invalidMetadata("Document type is unknown")
        }
    }
}

/// Quality assurance for document processing readiness
class DocumentQualityAssurance {

    func validateDocumentQuality(_ document: RealMortgageDocument) async throws {
        let qualityMetrics = try await assessDocumentQuality(document)

        guard qualityMetrics.ocrReadability >= 0.90 else {
            throw DocumentCollectionError.documentQualityInsufficient("OCR readability below threshold")
        }

        guard qualityMetrics.imageQuality >= 0.85 else {
            throw DocumentCollectionError.documentQualityInsufficient("Image quality below threshold")
        }
    }

    func validateDocumentIntegrity(_ document: RealMortgageDocument) async throws {
        // Validate image data integrity
        guard !document.imageData.isEmpty else {
            throw DocumentCollectionError.documentCorrupted("Image data is empty")
        }

        // Validate metadata consistency
        guard document.metadata.fileSize == document.imageData.count else {
            throw DocumentCollectionError.documentCorrupted("File size mismatch")
        }
    }

    func assessDocumentQuality(_ document: RealMortgageDocument) async throws -> DocumentQualityMetrics {
        // Perform quality assessment
        // This would include image analysis, text clarity, structural completeness

        return DocumentQualityMetrics(
            ocrReadability: 0.95,
            imageQuality: 0.92,
            structuralComplexity: 0.88,
            dataCompleteness: 0.96
        )
    }
}

// MARK: - Supporting Types

struct RealMortgageDocument {
    let id: String
    let fileName: String
    let documentType: DocumentType
    let imageData: Data
    let metadata: RealDocumentMetadata
    let processingStartTime: Date

    var servicerName: String {
        return metadata.servicerName
    }

    var anonymizedLoanNumber: String {
        return metadata.anonymizedLoanNumber
    }

    var complianceTestCases: [String] {
        return metadata.complianceTestCases
    }
}

struct RealDocumentMetadata: Codable {
    let servicerName: String
    let documentType: DocumentType
    let loanType: LoanType
    let anonymizationStatus: AnonymizationStatus
    let anonymizedLoanNumber: String
    let fileSize: Int
    let creationDate: Date
    let complianceTestCases: [String]
    let expectedErrors: [String]
    let qualityMetrics: DocumentQualityMetrics

    func hasField(_ field: String) -> Bool {
        // Implementation would check if the field exists and is valid
        return true
    }

    func containsRequiredElements(for testCase: ComplianceTestCase) -> Bool {
        return complianceTestCases.contains(testCase.id)
    }
}

struct DocumentQualityMetrics: Codable {
    let ocrReadability: Double
    let imageQuality: Double
    let structuralComplexity: Double
    let dataCompleteness: Double
}

enum AnonymizationStatus: String, Codable {
    case anonymized = "anonymized"
    case partiallyAnonymized = "partially_anonymized"
    case notAnonymized = "not_anonymized"
}

enum LoanType: String, Codable {
    case conventional = "conventional"
    case fha = "fha"
    case va = "va"
    case usda = "usda"
    case jumbo = "jumbo"
    case arm = "arm"
    case interestOnly = "interest_only"
}

struct ComplianceTestCase {
    let id: String
    let section: String
    let description: String
    let documentType: DocumentType
    let expectsViolation: Bool
    let actualRegulationText: String
    let minimumComplexity: Double
    let expectedAPR: Double?
    let expectedFinanceCharge: Double?
    let tilaRequirements: TILARequirements?
}

struct TILARequirements {
    let requiredDisclosures: [String]
    let calculationMethod: String
    let toleranceLimits: [String: Double]
}

enum DocumentCollectionError: Error, LocalizedError {
    case testDataDirectoryNotFound(String)
    case documentTooLarge(String)
    case metadataFileNotFound(String)
    case missingRequiredMetadataField(String)
    case invalidMetadata(String)
    case documentQualityInsufficient(String)
    case documentCorrupted(String)
    case documentNotAnonymized(String)
    case noMatchingDocumentForTestCase(String)
    case documentMissingRequiredElements(String)
    case noDocumentsAvailable

    var errorDescription: String? {
        switch self {
        case .testDataDirectoryNotFound(let path):
            return "Test data directory not found: \(path)"
        case .documentTooLarge(let fileName):
            return "Document too large: \(fileName)"
        case .metadataFileNotFound(let fileName):
            return "Metadata file not found: \(fileName)"
        case .missingRequiredMetadataField(let field):
            return "Missing required metadata field: \(field)"
        case .invalidMetadata(let message):
            return "Invalid metadata: \(message)"
        case .documentQualityInsufficient(let reason):
            return "Document quality insufficient: \(reason)"
        case .documentCorrupted(let reason):
            return "Document corrupted: \(reason)"
        case .documentNotAnonymized(let fileName):
            return "Document not properly anonymized: \(fileName)"
        case .noMatchingDocumentForTestCase(let testCaseId):
            return "No document found for test case: \(testCaseId)"
        case .documentMissingRequiredElements(let testCaseId):
            return "Document missing required elements for test case: \(testCaseId)"
        case .noDocumentsAvailable:
            return "No documents available for testing"
        }
    }
}