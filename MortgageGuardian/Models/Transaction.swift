import Foundation

struct Transaction: Identifiable, Codable {
    let id = UUID()
    let accountId: String
    let transactionId: String
    let amount: Double
    let date: Date
    let description: String
    let category: TransactionCategory
    let isRecurring: Bool
    let merchantName: String?
    let confidence: Double
    let plaidTransactionId: String?
    let isVerified: Bool
    let relatedMortgagePayment: Bool

    enum TransactionCategory: String, CaseIterable, Codable {
        case mortgagePayment = "mortgage_payment"
        case escrowPayment = "escrow_payment"
        case lateFeePenalty = "late_fee_penalty"
        case refinanceClosing = "refinance_closing"
        case homeInsurance = "home_insurance"
        case propertyTax = "property_tax"
        case other = "other"

        var displayName: String {
            switch self {
            case .mortgagePayment:
                return "Mortgage Payment"
            case .escrowPayment:
                return "Escrow Payment"
            case .lateFeePenalty:
                return "Late Fee/Penalty"
            case .refinanceClosing:
                return "Refinance/Closing"
            case .homeInsurance:
                return "Home Insurance"
            case .propertyTax:
                return "Property Tax"
            case .other:
                return "Other"
            }
        }

        var icon: String {
            switch self {
            case .mortgagePayment:
                return "house.fill"
            case .escrowPayment:
                return "shield.fill"
            case .lateFeePenalty:
                return "exclamationmark.triangle.fill"
            case .refinanceClosing:
                return "doc.text.fill"
            case .homeInsurance:
                return "umbrella.fill"
            case .propertyTax:
                return "building.columns.fill"
            case .other:
                return "creditcard.fill"
            }
        }
    }
}

struct PaymentCorrelation: Identifiable, Codable {
    let id = UUID()
    let bankTransaction: Transaction
    let servicerRecord: ExtractedData.PaymentRecord?
    let correlationStatus: CorrelationStatus
    let timingDiscrepancy: TimeInterval?
    let amountDiscrepancy: Double?
    let suggestedActions: [String]
    let confidenceScore: Double

    enum CorrelationStatus: String, CaseIterable, Codable {
        case perfectMatch = "perfect_match"
        case amountMismatch = "amount_mismatch"
        case timingMismatch = "timing_mismatch"
        case bothMismatch = "both_mismatch"
        case noServicerRecord = "no_servicer_record"
        case noBankRecord = "no_bank_record"

        var displayName: String {
            switch self {
            case .perfectMatch:
                return "Perfect Match"
            case .amountMismatch:
                return "Amount Mismatch"
            case .timingMismatch:
                return "Timing Mismatch"
            case .bothMismatch:
                return "Amount & Timing Mismatch"
            case .noServicerRecord:
                return "Missing from Servicer Records"
            case .noBankRecord:
                return "Missing from Bank Records"
            }
        }

        var severity: AuditResult.Severity {
            switch self {
            case .perfectMatch:
                return .low
            case .amountMismatch, .timingMismatch:
                return .medium
            case .bothMismatch, .noServicerRecord:
                return .high
            case .noBankRecord:
                return .critical
            }
        }
    }
}

struct PlaidAccount: Identifiable, Codable {
    let id = UUID()
    let accountId: String
    let accountName: String
    let accountType: String
    let accountSubtype: String?
    let institutionName: String
    let mask: String?
    let isConnected: Bool
    let lastSyncDate: Date?
    let accessToken: String?

    var displayName: String {
        if let mask = mask {
            return "\(accountName) ••••\(mask)"
        }
        return accountName
    }
}

extension Transaction {
    static func sampleMortgagePayment() -> Transaction {
        Transaction(
            accountId: "account_123",
            transactionId: "txn_456",
            amount: -1750.00,
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            description: "MORTGAGE PAYMENT ABC MORTGAGE",
            category: .mortgagePayment,
            isRecurring: true,
            merchantName: "ABC Mortgage",
            confidence: 0.98,
            plaidTransactionId: "plaid_txn_789",
            isVerified: true,
            relatedMortgagePayment: true
        )
    }

    static func samplePropertyTax() -> Transaction {
        Transaction(
            accountId: "account_123",
            transactionId: "txn_789",
            amount: -4500.00,
            date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
            description: "COUNTY TAX COLLECTOR PROPERTY TAX",
            category: .propertyTax,
            isRecurring: false,
            merchantName: "County Tax Collector",
            confidence: 0.95,
            plaidTransactionId: "plaid_txn_101",
            isVerified: true,
            relatedMortgagePayment: false
        )
    }
}