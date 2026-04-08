import Foundation
import SwiftUI

struct MortgageDocument: Identifiable, Codable {
    let id = UUID()
    let fileName: String
    let documentType: DocumentType
    let uploadDate: Date
    let originalText: String
    let extractedData: ExtractedData?
    let analysisResults: [AuditResult]
    var isAnalyzed: Bool
    var serverDocumentId: String?
    var pipelineStatus: String?

    enum CodingKeys: String, CodingKey {
        case id, fileName, documentType, uploadDate, originalText
        case extractedData, analysisResults, isAnalyzed
        case serverDocumentId, pipelineStatus
    }

    init(
        fileName: String,
        documentType: DocumentType,
        uploadDate: Date,
        originalText: String,
        extractedData: ExtractedData?,
        analysisResults: [AuditResult],
        isAnalyzed: Bool,
        serverDocumentId: String? = nil,
        pipelineStatus: String? = nil
    ) {
        self.fileName = fileName
        self.documentType = documentType
        self.uploadDate = uploadDate
        self.originalText = originalText
        self.extractedData = extractedData
        self.analysisResults = analysisResults
        self.isAnalyzed = isAnalyzed
        self.serverDocumentId = serverDocumentId
        self.pipelineStatus = pipelineStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try container.decode(String.self, forKey: .fileName)
        documentType = try container.decode(DocumentType.self, forKey: .documentType)
        uploadDate = try container.decode(Date.self, forKey: .uploadDate)
        originalText = try container.decode(String.self, forKey: .originalText)
        extractedData = try container.decodeIfPresent(ExtractedData.self, forKey: .extractedData)
        analysisResults = try container.decode([AuditResult].self, forKey: .analysisResults)
        isAnalyzed = try container.decode(Bool.self, forKey: .isAnalyzed)
        serverDocumentId = try container.decodeIfPresent(String.self, forKey: .serverDocumentId)
        pipelineStatus = try container.decodeIfPresent(String.self, forKey: .pipelineStatus)
    }

    enum DocumentType: String, CaseIterable, Codable {
        case mortgageStatement = "mortgage_statement"
        case escrowStatement = "escrow_statement"
        case paymentHistory = "payment_history"
        case loanDocuments = "loan_documents"
        case taxStatement = "tax_statement"
        case insuranceStatement = "insurance_statement"
        case other = "other"

        var displayName: String {
            switch self {
            case .mortgageStatement:
                return "Mortgage Statement"
            case .escrowStatement:
                return "Escrow Statement"
            case .paymentHistory:
                return "Payment History"
            case .loanDocuments:
                return "Loan Documents"
            case .taxStatement:
                return "Tax Statement"
            case .insuranceStatement:
                return "Insurance Statement"
            case .other:
                return "Other"
            }
        }

        var icon: String {
            switch self {
            case .mortgageStatement:
                return "house.fill"
            case .escrowStatement:
                return "shield.fill"
            case .paymentHistory:
                return "calendar"
            case .loanDocuments:
                return "doc.text.fill"
            case .taxStatement:
                return "percent"
            case .insuranceStatement:
                return "umbrella.fill"
            case .other:
                return "doc.fill"
            }
        }
    }
}

struct ExtractedData: Codable {
    let loanNumber: String?
    let servicerName: String?
    let borrowerName: String?
    let propertyAddress: String?
    let principalBalance: Double?
    let interestRate: Double?
    let monthlyPayment: Double?
    let escrowBalance: Double?
    let dueDate: Date?
    let paymentHistory: [PaymentRecord]
    let escrowActivity: [EscrowTransaction]
    let fees: [Fee]

    struct PaymentRecord: Codable, Identifiable {
        let id = UUID()
        let paymentDate: Date
        let amount: Double
        let principalApplied: Double?
        let interestApplied: Double?
        let escrowApplied: Double?
        let lateFeesApplied: Double?
        let isLate: Bool
        let dayslate: Int?
    }

    struct EscrowTransaction: Codable, Identifiable {
        let id = UUID()
        let date: Date
        let description: String
        let amount: Double
        let type: TransactionType
        let category: EscrowCategory

        enum TransactionType: String, Codable {
            case deposit = "deposit"
            case withdrawal = "withdrawal"
        }

        enum EscrowCategory: String, Codable {
            case propertyTax = "property_tax"
            case homeownerInsurance = "homeowner_insurance"
            case mortgageInsurance = "mortgage_insurance"
            case other = "other"
        }
    }

    struct Fee: Codable, Identifiable {
        let id = UUID()
        let date: Date
        let description: String
        let amount: Double
        let category: FeeCategory

        enum FeeCategory: String, Codable {
            case lateFee = "late_fee"
            case inspectionFee = "inspection_fee"
            case attorneyFee = "attorney_fee"
            case processingFee = "processing_fee"
            case other = "other"
        }
    }
}