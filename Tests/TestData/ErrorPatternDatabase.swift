import Foundation
@testable import MortgageGuardian

/// Comprehensive Error Pattern Database for Zero-Tolerance Testing
/// Contains all known mortgage servicing violation patterns for validation
class ErrorPatternDatabase {

    // MARK: - Error Pattern Categories

    enum ViolationCategory: String, CaseIterable {
        case paymentProcessing = "Payment Processing"
        case interestCalculation = "Interest Calculation"
        case escrowManagement = "Escrow Management"
        case feeAssessment = "Fee Assessment"
        case regulatoryCompliance = "Regulatory Compliance"
        case dataIntegrity = "Data Integrity"
        case foreClosureProcess = "Foreclosure Process"
        case loanModification = "Loan Modification"
        case servicingTransfer = "Servicing Transfer"
        case militaryProtection = "Military Protection"
    }

    // MARK: - Error Pattern Definitions

    static let knownErrorPatterns: [ErrorPattern] = [
        // Payment Processing Violations (6 patterns)
        ErrorPattern(
            id: "PAY001",
            category: .paymentProcessing,
            name: "Payment Allocation Mismatch",
            description: "Payment allocated incorrectly between principal, interest, escrow, and fees",
            regulatoryBasis: "RESPA Section 10",
            severity: .high,
            testData: PaymentAllocationMismatchData()
        ),
        ErrorPattern(
            id: "PAY002",
            category: .paymentProcessing,
            name: "Duplicate Payment Processing",
            description: "Same payment processed multiple times",
            regulatoryBasis: "Fair Debt Collection Practices Act",
            severity: .critical,
            testData: DuplicatePaymentData()
        ),
        ErrorPattern(
            id: "PAY003",
            category: .paymentProcessing,
            name: "Payment Without Bank Transaction",
            description: "Payment recorded without corresponding bank transaction",
            regulatoryBasis: "Banking Regulations",
            severity: .high,
            testData: PaymentWithoutBankTransactionData()
        ),
        ErrorPattern(
            id: "PAY004",
            category: .paymentProcessing,
            name: "Unauthorized Payment Reversal",
            description: "Payment reversed without proper authorization",
            regulatoryBasis: "UCC Article 4A",
            severity: .critical,
            testData: UnauthorizedPaymentReversalData()
        ),
        ErrorPattern(
            id: "PAY005",
            category: .paymentProcessing,
            name: "Payment Timing Violations",
            description: "Payment processed on incorrect date affecting grace period",
            regulatoryBasis: "Contract Terms",
            severity: .medium,
            testData: PaymentTimingViolationData()
        ),
        ErrorPattern(
            id: "PAY006",
            category: .paymentProcessing,
            name: "Payment Application Order Error",
            description: "Payment applied in wrong order (fees before principal/interest)",
            regulatoryBasis: "RESPA Requirements",
            severity: .high,
            testData: PaymentApplicationOrderErrorData()
        ),

        // Interest Calculation Violations (5 patterns)
        ErrorPattern(
            id: "INT001",
            category: .interestCalculation,
            name: "Interest Rate Misapplication",
            description: "Wrong interest rate applied to loan balance",
            regulatoryBasis: "Truth in Lending Act",
            severity: .critical,
            testData: InterestRateMisapplicationData()
        ),
        ErrorPattern(
            id: "INT002",
            category: .interestCalculation,
            name: "Compounding Frequency Error",
            description: "Interest compounded more frequently than contract terms",
            regulatoryBasis: "Contract Terms",
            severity: .high,
            testData: CompoundingFrequencyErrorData()
        ),
        ErrorPattern(
            id: "INT003",
            category: .interestCalculation,
            name: "Interest Accrual Calculation Error",
            description: "Incorrect per diem interest calculation",
            regulatoryBasis: "Mathematical Standards",
            severity: .high,
            testData: InterestAccrualErrorData()
        ),
        ErrorPattern(
            id: "INT004",
            category: .interestCalculation,
            name: "ARM Interest Cap Violation",
            description: "Adjustable rate exceeds contractual caps",
            regulatoryBasis: "Truth in Lending Act",
            severity: .critical,
            testData: ARMCapViolationData()
        ),
        ErrorPattern(
            id: "INT005",
            category: .interestCalculation,
            name: "Interest-Only Period Violation",
            description: "Principal reduction during interest-only period",
            regulatoryBasis: "Contract Terms",
            severity: .medium,
            testData: InterestOnlyViolationData()
        ),

        // Escrow Management Violations (5 patterns)
        ErrorPattern(
            id: "ESC001",
            category: .escrowManagement,
            name: "Escrow Shortage Miscalculation",
            description: "Escrow shortage calculated incorrectly",
            regulatoryBasis: "RESPA Section 10",
            severity: .high,
            testData: EscrowShortageErrorData()
        ),
        ErrorPattern(
            id: "ESC002",
            category: .escrowManagement,
            name: "Unauthorized Escrow Deduction",
            description: "Funds deducted from escrow without proper notice",
            regulatoryBasis: "RESPA Section 10",
            severity: .high,
            testData: UnauthorizedEscrowDeductionData()
        ),
        ErrorPattern(
            id: "ESC003",
            category: .escrowManagement,
            name: "Escrow Analysis Timing Violation",
            description: "Escrow analysis not performed within required timeframe",
            regulatoryBasis: "RESPA Section 10",
            severity: .medium,
            testData: EscrowAnalysisTimingData()
        ),
        ErrorPattern(
            id: "ESC004",
            category: .escrowManagement,
            name: "Force-Placed Insurance Violation",
            description: "Force-placed insurance without proper notice or excessive charges",
            regulatoryBasis: "RESPA Section 8",
            severity: .critical,
            testData: ForcePlacedInsuranceData()
        ),
        ErrorPattern(
            id: "ESC005",
            category: .escrowManagement,
            name: "Escrow Surplus Retention",
            description: "Escrow surplus not refunded when required",
            regulatoryBasis: "RESPA Section 10",
            severity: .medium,
            testData: EscrowSurplusRetentionData()
        ),

        // Fee Assessment Violations (5 patterns)
        ErrorPattern(
            id: "FEE001",
            category: .feeAssessment,
            name: "Unauthorized Late Fee",
            description: "Late fee charged outside grace period or without authorization",
            regulatoryBasis: "Contract Terms",
            severity: .high,
            testData: UnauthorizedLateFeeData()
        ),
        ErrorPattern(
            id: "FEE002",
            category: .feeAssessment,
            name: "Late Fee Calculation Error",
            description: "Late fee amount exceeds contractual limits",
            regulatoryBasis: "Contract Terms",
            severity: .medium,
            testData: LateFeeCalculationErrorData()
        ),
        ErrorPattern(
            id: "FEE003",
            category: .feeAssessment,
            name: "Duplicate Fee Assessment",
            description: "Same fee charged multiple times",
            regulatoryBasis: "Fair Debt Collection",
            severity: .high,
            testData: DuplicateFeeData()
        ),
        ErrorPattern(
            id: "FEE004",
            category: .feeAssessment,
            name: "Fee Cap Violation",
            description: "Cumulative fees exceed state or federal caps",
            regulatoryBasis: "State Regulations",
            severity: .high,
            testData: FeeCapViolationData()
        ),
        ErrorPattern(
            id: "FEE005",
            category: .feeAssessment,
            name: "Grace Period Violation",
            description: "Fee assessed before grace period expires",
            regulatoryBasis: "Contract Terms",
            severity: .medium,
            testData: GracePeriodViolationData()
        ),

        // Regulatory Compliance Violations (8 patterns)
        ErrorPattern(
            id: "REG001",
            category: .regulatoryCompliance,
            name: "RESPA Section 6 Violation",
            description: "Improper servicing transfer notice",
            regulatoryBasis: "RESPA Section 6",
            severity: .critical,
            testData: RESPASection6Data()
        ),
        ErrorPattern(
            id: "REG002",
            category: .regulatoryCompliance,
            name: "RESPA Section 8 Violation",
            description: "Kickback or referral fee arrangement",
            regulatoryBasis: "RESPA Section 8",
            severity: .critical,
            testData: RESPASection8Data()
        ),
        ErrorPattern(
            id: "REG003",
            category: .regulatoryCompliance,
            name: "RESPA Section 10 Violation",
            description: "Escrow account mismanagement",
            regulatoryBasis: "RESPA Section 10",
            severity: .high,
            testData: RESPASection10Data()
        ),
        ErrorPattern(
            id: "REG004",
            category: .regulatoryCompliance,
            name: "TILA Disclosure Violation",
            description: "Missing or inadequate Truth in Lending disclosures",
            regulatoryBasis: "Truth in Lending Act",
            severity: .critical,
            testData: TILAViolationData()
        ),
        ErrorPattern(
            id: "REG005",
            category: .regulatoryCompliance,
            name: "Dual Tracking Violation",
            description: "Foreclosure pursued while modification is pending",
            regulatoryBasis: "Dodd-Frank Act",
            severity: .critical,
            testData: DualTrackingData()
        ),
        ErrorPattern(
            id: "REG006",
            category: .regulatoryCompliance,
            name: "Bankruptcy Automatic Stay Violation",
            description: "Collection activity during bankruptcy automatic stay",
            regulatoryBasis: "Bankruptcy Code",
            severity: .critical,
            testData: AutomaticStayViolationData()
        ),
        ErrorPattern(
            id: "REG007",
            category: .regulatoryCompliance,
            name: "SCRA Violation",
            description: "Servicemembers Civil Relief Act protection not applied",
            regulatoryBasis: "SCRA",
            severity: .critical,
            testData: SCRAViolationData()
        ),
        ErrorPattern(
            id: "REG008",
            category: .regulatoryCompliance,
            name: "Foreclosure Timeline Violation",
            description: "Foreclosure initiated without proper notice period",
            regulatoryBasis: "State Foreclosure Laws",
            severity: .critical,
            testData: ForeclosureTimelineData()
        ),

        // Data Integrity Violations (5 patterns)
        ErrorPattern(
            id: "DATA001",
            category: .dataIntegrity,
            name: "Missing Critical Data",
            description: "Required loan or payment data missing from records",
            regulatoryBasis: "Recordkeeping Requirements",
            severity: .high,
            testData: MissingDataPattern()
        ),
        ErrorPattern(
            id: "DATA002",
            category: .dataIntegrity,
            name: "Inconsistent Data Across Records",
            description: "Conflicting information in different system records",
            regulatoryBasis: "Data Accuracy Requirements",
            severity: .medium,
            testData: InconsistentDataPattern()
        ),
        ErrorPattern(
            id: "DATA003",
            category: .dataIntegrity,
            name: "Data Corruption Detection",
            description: "Corrupted or invalid data in loan records",
            regulatoryBasis: "System Integrity Requirements",
            severity: .high,
            testData: DataCorruptionPattern()
        ),
        ErrorPattern(
            id: "DATA004",
            category: .dataIntegrity,
            name: "Audit Trail Tampering",
            description: "Missing or altered audit trail entries",
            regulatoryBasis: "SOX Compliance",
            severity: .critical,
            testData: AuditTrailTamperingPattern()
        ),
        ErrorPattern(
            id: "DATA005",
            category: .dataIntegrity,
            name: "System Calculation Error",
            description: "Mathematical calculation errors in system processing",
            regulatoryBasis: "Accuracy Standards",
            severity: .high,
            testData: CalculationErrorPattern()
        )
    ]

    // MARK: - Complex Scenario Patterns

    static let complexScenarios: [ComplexScenario] = [
        ComplexScenario(
            id: "COMPLEX001",
            name: "Multiple Simultaneous Violations",
            description: "Payment allocation error combined with unauthorized fee",
            involvedPatterns: ["PAY001", "FEE001"],
            expectedDetections: 2
        ),
        ComplexScenario(
            id: "COMPLEX002",
            name: "Cascading Error Effects",
            description: "Interest miscalculation leading to escrow shortage",
            involvedPatterns: ["INT001", "ESC001"],
            expectedDetections: 2
        ),
        ComplexScenario(
            id: "COMPLEX003",
            name: "Regulatory Conflict",
            description: "SCRA violation during bankruptcy proceedings",
            involvedPatterns: ["REG006", "REG007"],
            expectedDetections: 2
        ),
        ComplexScenario(
            id: "COMPLEX004",
            name: "High-Value Loan Processing",
            description: "Jumbo loan with multiple compliance requirements",
            involvedPatterns: ["INT001", "ESC001", "REG004"],
            expectedDetections: 3
        ),
        ComplexScenario(
            id: "COMPLEX005",
            name: "Multi-State Jurisdiction",
            description: "Loan with properties in multiple states",
            involvedPatterns: ["REG008", "FEE004"],
            expectedDetections: 2
        ),
        ComplexScenario(
            id: "COMPLEX006",
            name: "Loan Modification Errors",
            description: "Errors during loan modification processing",
            involvedPatterns: ["PAY001", "INT001", "REG005"],
            expectedDetections: 3
        )
    ]

    // MARK: - Edge Case Patterns

    static let edgeCasePatterns: [EdgeCasePattern] = [
        EdgeCasePattern(
            id: "EDGE001",
            name: "Leap Year Interest Calculation",
            description: "Interest calculation errors in leap years",
            rarity: .rare,
            testData: LeapYearInterestData()
        ),
        EdgeCasePattern(
            id: "EDGE002",
            name: "Payment on Non-Business Day",
            description: "Payment processing on bank holidays",
            rarity: .uncommon,
            testData: HolidayPaymentData()
        ),
        EdgeCasePattern(
            id: "EDGE003",
            name: "Extreme High-Value Transaction",
            description: "Payments exceeding normal processing limits",
            rarity: .rare,
            testData: HighValueTransactionData()
        ),
        EdgeCasePattern(
            id: "EDGE004",
            name: "Zero-Balance Escrow Account",
            description: "Escrow account with exactly zero balance",
            rarity: .uncommon,
            testData: ZeroBalanceEscrowData()
        ),
        EdgeCasePattern(
            id: "EDGE005",
            name: "Loan at Maturity Date",
            description: "Loan processing at exact maturity date",
            rarity: .rare,
            testData: MaturityDateData()
        )
    ]

    // MARK: - Test Data Validation

    /// Validates that all error patterns have corresponding test data
    static func validatePatterns() -> ValidationResult {
        var missingTestData: [String] = []
        var invalidPatterns: [String] = []

        for pattern in knownErrorPatterns {
            // Validate test data exists
            if pattern.testData == nil {
                missingTestData.append(pattern.id)
            }

            // Validate pattern completeness
            if pattern.name.isEmpty || pattern.description.isEmpty {
                invalidPatterns.append(pattern.id)
            }
        }

        return ValidationResult(
            isValid: missingTestData.isEmpty && invalidPatterns.isEmpty,
            missingTestData: missingTestData,
            invalidPatterns: invalidPatterns,
            totalPatterns: knownErrorPatterns.count
        )
    }

    // MARK: - Pattern Retrieval Methods

    static func getPattern(byId id: String) -> ErrorPattern? {
        return knownErrorPatterns.first { $0.id == id }
    }

    static func getPatterns(byCategory category: ViolationCategory) -> [ErrorPattern] {
        return knownErrorPatterns.filter { $0.category == category }
    }

    static func getCriticalPatterns() -> [ErrorPattern] {
        return knownErrorPatterns.filter { $0.severity == .critical }
    }

    static func getAllPatternIds() -> [String] {
        return knownErrorPatterns.map { $0.id }
    }

    static func getComplexScenario(byId id: String) -> ComplexScenario? {
        return complexScenarios.first { $0.id == id }
    }

    static func getEdgeCasePattern(byId id: String) -> EdgeCasePattern? {
        return edgeCasePatterns.first { $0.id == id }
    }
}

// MARK: - Supporting Structures

struct ErrorPattern {
    let id: String
    let category: ErrorPatternDatabase.ViolationCategory
    let name: String
    let description: String
    let regulatoryBasis: String
    let severity: Severity
    let testData: TestDataGeneratable?

    enum Severity {
        case low, medium, high, critical
    }
}

struct ComplexScenario {
    let id: String
    let name: String
    let description: String
    let involvedPatterns: [String]
    let expectedDetections: Int
}

struct EdgeCasePattern {
    let id: String
    let name: String
    let description: String
    let rarity: Rarity
    let testData: TestDataGeneratable?

    enum Rarity {
        case common, uncommon, rare, veryRare
    }
}

struct ValidationResult {
    let isValid: Bool
    let missingTestData: [String]
    let invalidPatterns: [String]
    let totalPatterns: Int
}

// MARK: - Test Data Generation Protocol

protocol TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData
    func generateExpectedErrors() -> [ExpectedError]
}

struct ExpectedError {
    let category: String
    let description: String
    let confidence: Double
    let severity: String
}

// MARK: - Concrete Test Data Implementations

struct PaymentAllocationMismatchData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generatePaymentAllocationMismatchData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Payment Misallocation",
                description: "Payment principal portion miscalculated",
                confidence: 0.95,
                severity: "High"
            )
        ]
    }
}

struct DuplicatePaymentData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateDuplicatePaymentData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Duplicate Payment",
                description: "Identical payment processed multiple times",
                confidence: 0.98,
                severity: "Critical"
            )
        ]
    }
}

struct PaymentWithoutBankTransactionData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generatePaymentWithoutBankTransactionData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Payment Verification",
                description: "Payment recorded without bank transaction",
                confidence: 0.92,
                severity: "High"
            )
        ]
    }
}

struct UnauthorizedPaymentReversalData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateUnauthorizedPaymentReversalData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Unauthorized Reversal",
                description: "Payment reversed without authorization",
                confidence: 0.97,
                severity: "Critical"
            )
        ]
    }
}

struct PaymentTimingViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generatePaymentTimingViolationsData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Payment Timing",
                description: "Payment processed with incorrect timing",
                confidence: 0.85,
                severity: "Medium"
            )
        ]
    }
}

struct PaymentApplicationOrderErrorData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generatePaymentApplicationOrderErrorsData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Payment Application Order",
                description: "Payment applied in incorrect order",
                confidence: 0.90,
                severity: "High"
            )
        ]
    }
}

// MARK: - Interest Calculation Test Data

struct InterestRateMisapplicationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateInterestRateMisapplicationData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Interest Rate Error",
                description: "Wrong interest rate applied",
                confidence: 0.94,
                severity: "Critical"
            )
        ]
    }
}

struct CompoundingFrequencyErrorData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateCompoundingFrequencyErrorsData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Compounding Error",
                description: "Incorrect compounding frequency",
                confidence: 0.89,
                severity: "High"
            )
        ]
    }
}

struct InterestAccrualErrorData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateInterestAccrualCalculationErrorsData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Interest Accrual",
                description: "Per diem interest calculation error",
                confidence: 0.91,
                severity: "High"
            )
        ]
    }
}

struct ARMCapViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateARMInterestCapViolationData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "ARM Cap Violation",
                description: "Interest rate exceeds contractual cap",
                confidence: 0.96,
                severity: "Critical"
            )
        ]
    }
}

struct InterestOnlyViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateInterestOnlyPeriodViolationData()
    }

    func generateExpectedErrors() -> [ExpectedError] {
        return [
            ExpectedError(
                category: "Interest Only Violation",
                description: "Principal reduction during I/O period",
                confidence: 0.87,
                severity: "Medium"
            )
        ]
    }
}

// MARK: - Placeholder implementations for remaining patterns
// (Similar structure for all remaining test data types)

struct EscrowShortageErrorData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateEscrowShortageCalculationErrorData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct UnauthorizedEscrowDeductionData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateUnauthorizedEscrowDeductionData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct EscrowAnalysisTimingData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateEscrowAnalysisTimingViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct ForcePlacedInsuranceData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateForcePlacedInsuranceViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct EscrowSurplusRetentionData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateEscrowRefundViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

// Fee Assessment Test Data (placeholder implementations)
struct UnauthorizedLateFeeData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct LateFeeCalculationErrorData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct DuplicateFeeData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct FeeCapViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct GracePeriodViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

// Regulatory Compliance Test Data
struct RESPASection6Data: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateRESPASection6ViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct RESPASection8Data: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateRESPASection8ViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct RESPASection10Data: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateRESPASection10ViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct TILAViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateTILADisclosureViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct DualTrackingData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateDualTrackingViolationData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct AutomaticStayViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateBankruptcyAutomaticStayViolationsData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct SCRAViolationData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateSCRAViolationsData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct ForeclosureTimelineData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData {
        return MortgageTestDataGenerator().generateForeclosureTimelineViolationsData()
    }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

// Data Integrity Test Data (placeholder implementations)
struct MissingDataPattern: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct InconsistentDataPattern: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct DataCorruptionPattern: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct AuditTrailTamperingPattern: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct CalculationErrorPattern: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

// Edge Case Test Data (placeholder implementations)
struct LeapYearInterestData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct HolidayPaymentData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct HighValueTransactionData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct ZeroBalanceEscrowData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

struct MaturityDateData: TestDataGeneratable {
    func generateTestData() -> ExtractedMortgageData { return ExtractedMortgageData.empty }
    func generateExpectedErrors() -> [ExpectedError] { return [] }
}

// MARK: - Empty Data Extension
extension ExtractedMortgageData {
    static var empty: ExtractedMortgageData {
        return ExtractedMortgageData(
            accountNumber: "",
            balanceInformation: BalanceInformation(
                principalBalance: 0,
                interestBalance: 0,
                escrowBalance: 0,
                feesBalance: 0,
                totalBalance: 0
            ),
            paymentHistory: [],
            transactionHistory: [],
            loanTerms: LoanTerms(
                originalAmount: 0,
                interestRate: 0,
                termInMonths: 0,
                paymentAmount: 0
            ),
            escrowAnalysis: nil,
            contactInformation: ContactInformation(
                servicerName: "",
                servicerAddress: "",
                customerServicePhone: ""
            ),
            statementDate: Date(),
            documentMetadata: DocumentMetadata(
                documentType: "",
                pageCount: 0,
                confidence: 0
            )
        )
    }
}