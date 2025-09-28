import Foundation
import SwiftUI

struct AuditResult: Identifiable, Codable {
    let id = UUID()
    let issueType: IssueType
    let severity: Severity
    let title: String
    let description: String
    let detailedExplanation: String
    let suggestedAction: String
    let affectedAmount: Double?
    let detectionMethod: DetectionMethod
    let confidence: Double
    let evidenceText: String?
    let calculationDetails: CalculationDetails?
    let createdDate: Date

    enum IssueType: String, CaseIterable, Codable {
        case misappliedPayment = "misapplied_payment"
        case latePaymentError = "late_payment_error"
        case incorrectInterest = "incorrect_interest"
        case unauthorizedFee = "unauthorized_fee"
        case escrowError = "escrow_error"
        case missingPayment = "missing_payment"
        case incorrectBalance = "incorrect_balance"
        case lateInsurancePayment = "late_insurance_payment"
        case lateTaxPayment = "late_tax_payment"
        case forcePlacedInsurance = "force_placed_insurance"
        case duplicateCharge = "duplicate_charge"

        var displayName: String {
            switch self {
            case .misappliedPayment:
                return "Misapplied Payment"
            case .latePaymentError:
                return "Late Payment Error"
            case .incorrectInterest:
                return "Incorrect Interest Calculation"
            case .unauthorizedFee:
                return "Unauthorized Fee"
            case .escrowError:
                return "Escrow Account Error"
            case .missingPayment:
                return "Missing Payment"
            case .incorrectBalance:
                return "Incorrect Balance"
            case .lateInsurancePayment:
                return "Late Insurance Payment"
            case .lateTaxPayment:
                return "Late Tax Payment"
            case .forcePlacedInsurance:
                return "Force-Placed Insurance"
            case .duplicateCharge:
                return "Duplicate Charge"
            }
        }

        var icon: String {
            switch self {
            case .misappliedPayment:
                return "arrow.triangle.2.circlepath"
            case .latePaymentError:
                return "clock.fill"
            case .incorrectInterest:
                return "percent"
            case .unauthorizedFee:
                return "exclamationmark.triangle.fill"
            case .escrowError:
                return "shield.slash.fill"
            case .missingPayment:
                return "questionmark.circle.fill"
            case .incorrectBalance:
                return "equal.circle.fill"
            case .lateInsurancePayment:
                return "umbrella.fill"
            case .lateTaxPayment:
                return "building.columns.fill"
            case .forcePlacedInsurance:
                return "exclamationmark.shield.fill"
            case .duplicateCharge:
                return "doc.on.doc.fill"
            }
        }
    }

    enum Severity: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"

        var color: Color {
            switch self {
            case .low:
                return .green
            case .medium:
                return .yellow
            case .high:
                return .orange
            case .critical:
                return .red
            }
        }

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum DetectionMethod: String, Codable {
        case aiAnalysis = "ai_analysis"
        case manualCalculation = "manual_calculation"
        case plaidVerification = "plaid_verification"
        case combinedAnalysis = "combined_analysis"

        var displayName: String {
            switch self {
            case .aiAnalysis:
                return "AI Analysis"
            case .manualCalculation:
                return "Manual Calculation"
            case .plaidVerification:
                return "Bank Data Verification"
            case .combinedAnalysis:
                return "Combined Analysis"
            }
        }
    }

    struct CalculationDetails: Codable {
        let expectedValue: Double?
        let actualValue: Double?
        let difference: Double?
        let formula: String?
        let assumptions: [String]
        let warningFlags: [String]
    }
}

extension AuditResult {
    static func sampleResult() -> AuditResult {
        return AuditResult(
            issueType: .latePaymentError,
            severity: .high,
            title: "Incorrect Late Fee Charged",
            description: "A late fee was charged despite payment being received on time",
            detailedExplanation: "Payment due 01/01/2025 was received 01/05/2025, but your bank records show the payment was actually sent on 12/30/2024. The servicer incorrectly applied a $25 late fee.",
            suggestedAction: "Send a Notice of Error letter requesting removal of the late fee and correction of payment application date",
            affectedAmount: 25.00,
            detectionMethod: .plaidVerification,
            confidence: 0.95,
            evidenceText: "Payment due 01/01/2025 was received 01/05/2025, late fee charged",
            calculationDetails: CalculationDetails(
                expectedValue: 0.00,
                actualValue: 25.00,
                difference: 25.00,
                formula: "Late fee should be $0 when payment sent before due date",
                assumptions: ["Grace period of 15 days", "Payment sent 2 days before due date"],
                warningFlags: ["Payment application delay", "Potential RESPA violation"]
            ),
            createdDate: Date()
        )
    }
}