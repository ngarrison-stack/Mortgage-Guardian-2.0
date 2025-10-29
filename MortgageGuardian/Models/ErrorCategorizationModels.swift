import Foundation

// MARK: - Comprehensive Error Categorization and Severity Scoring Models

/// Comprehensive error categorization system for mortgage servicing errors
public struct MortgageErrorCategory {
    let id: UUID
    let name: String
    let description: String
    let parentCategory: String?
    let severity: ErrorSeverityRating
    let financialImpactRange: FinancialImpactRange
    let regulatoryImplications: [RegulatoryImplication]
    let typicalDetectionMethods: [DetectionMethod]
    let commonCauses: [String]
    let resolutionComplexity: ResolutionComplexity
    let timeToResolve: TimeToResolve

    /// Primary error categories based on mortgage servicing practices
    public enum Category: String, CaseIterable {
        // Payment Processing Errors
        case paymentMisallocation = "payment_misallocation"
        case paymentTiming = "payment_timing"
        case paymentCalculation = "payment_calculation"
        case paymentApplication = "payment_application"

        // Interest and Principal Errors
        case interestMiscalculation = "interest_miscalculation"
        case principalMisallocation = "principal_misallocation"
        case amortizationErrors = "amortization_errors"
        case rateApplicationErrors = "rate_application_errors"

        // Escrow Account Errors
        case escrowShortage = "escrow_shortage"
        case escrowOverage = "escrow_overage"
        case escrowMiscalculation = "escrow_miscalculation"
        case escrowPaymentTiming = "escrow_payment_timing"

        // Fee-Related Errors
        case unauthorizedFees = "unauthorized_fees"
        case excessiveFees = "excessive_fees"
        case lateFeeErrors = "late_fee_errors"
        case feeCalculationErrors = "fee_calculation_errors"

        // Regulatory Compliance Errors
        case respaViolations = "respa_violations"
        case tilaViolations = "tila_violations"
        case disclosureErrors = "disclosure_errors"
        case noticeRequirements = "notice_requirements"

        // Data Integrity Errors
        case missingData = "missing_data"
        case inconsistentData = "inconsistent_data"
        case corruptedData = "corrupted_data"
        case formatErrors = "format_errors"

        public var displayName: String {
            switch self {
            case .paymentMisallocation: return "Payment Misallocation"
            case .paymentTiming: return "Payment Timing Issues"
            case .paymentCalculation: return "Payment Calculation Errors"
            case .paymentApplication: return "Payment Application Issues"
            case .interestMiscalculation: return "Interest Miscalculation"
            case .principalMisallocation: return "Principal Misallocation"
            case .amortizationErrors: return "Amortization Errors"
            case .rateApplicationErrors: return "Rate Application Errors"
            case .escrowShortage: return "Escrow Shortage"
            case .escrowOverage: return "Escrow Overage"
            case .escrowMiscalculation: return "Escrow Miscalculation"
            case .escrowPaymentTiming: return "Escrow Payment Timing"
            case .unauthorizedFees: return "Unauthorized Fees"
            case .excessiveFees: return "Excessive Fees"
            case .lateFeeErrors: return "Late Fee Errors"
            case .feeCalculationErrors: return "Fee Calculation Errors"
            case .respaViolations: return "RESPA Violations"
            case .tilaViolations: return "TILA Violations"
            case .disclosureErrors: return "Disclosure Errors"
            case .noticeRequirements: return "Notice Requirements"
            case .missingData: return "Missing Data"
            case .inconsistentData: return "Inconsistent Data"
            case .corruptedData: return "Corrupted Data"
            case .formatErrors: return "Format Errors"
            }
        }
    }

    public enum DetectionMethod: String, CaseIterable {
        case ruleBasedValidation = "rule_based_validation"
        case algorithmicCalculation = "algorithmic_calculation"
        case aiPatternRecognition = "ai_pattern_recognition"
        case crossReferenceVerification = "cross_reference_verification"
        case temporalAnalysis = "temporal_analysis"
        case statisticalAnalysis = "statistical_analysis"
        case regulatoryCompliance = "regulatory_compliance"
        case manualReview = "manual_review"
    }

    public enum ResolutionComplexity: String, CaseIterable {
        case simple = "simple"           // Can be resolved automatically
        case moderate = "moderate"       // Requires servicer action
        case complex = "complex"         // Requires regulatory intervention
        case legal = "legal"            // May require legal action

        public var description: String {
            switch self {
            case .simple:
                return "Simple - Can be resolved through standard servicer correction"
            case .moderate:
                return "Moderate - Requires formal servicer review and correction"
            case .complex:
                return "Complex - May require regulatory intervention or escalation"
            case .legal:
                return "Legal - May require legal action or formal complaint process"
            }
        }
    }

    public enum TimeToResolve: String, CaseIterable {
        case immediate = "immediate"     // 1-3 business days
        case short = "short"            // 1-2 weeks
        case medium = "medium"          // 1-2 months
        case long = "long"              // 3-6 months
        case extended = "extended"      // 6+ months

        public var estimatedDays: ClosedRange<Int> {
            switch self {
            case .immediate: return 1...3
            case .short: return 5...14
            case .medium: return 30...60
            case .long: return 90...180
            case .extended: return 180...365
            }
        }
    }
}

/// Comprehensive severity rating system
public struct ErrorSeverityRating {
    let level: SeverityLevel
    let score: Double // 0.0 to 10.0
    let factors: [SeverityFactor]
    let adjustments: [SeverityAdjustment]

    public enum SeverityLevel: String, CaseIterable {
        case informational = "informational"  // 0.0 - 2.0
        case low = "low"                      // 2.1 - 4.0
        case medium = "medium"                // 4.1 - 6.0
        case high = "high"                    // 6.1 - 8.0
        case critical = "critical"            // 8.1 - 10.0

        public var scoreRange: ClosedRange<Double> {
            switch self {
            case .informational: return 0.0...2.0
            case .low: return 2.1...4.0
            case .medium: return 4.1...6.0
            case .high: return 6.1...8.0
            case .critical: return 8.1...10.0
            }
        }

        public var color: String {
            switch self {
            case .informational: return "#17A2B8" // Info blue
            case .low: return "#28A745"           // Success green
            case .medium: return "#FFC107"        // Warning yellow
            case .high: return "#FD7E14"          // Warning orange
            case .critical: return "#DC3545"      // Danger red
            }
        }
    }

    public struct SeverityFactor {
        let name: String
        let weight: Double // 0.0 to 1.0
        let value: Double  // 0.0 to 10.0
        let description: String

        public static let financialImpact = SeverityFactor(
            name: "Financial Impact",
            weight: 0.35,
            value: 0.0,
            description: "Direct monetary impact on borrower"
        )

        public static let regulatoryCompliance = SeverityFactor(
            name: "Regulatory Compliance",
            weight: 0.25,
            value: 0.0,
            description: "Level of regulatory violation"
        )

        public static let frequency = SeverityFactor(
            name: "Frequency",
            weight: 0.20,
            value: 0.0,
            description: "How often this error occurs"
        )

        public static let borrowerImpact = SeverityFactor(
            name: "Borrower Impact",
            weight: 0.15,
            value: 0.0,
            description: "Impact on borrower's credit and financial status"
        )

        public static let systemicRisk = SeverityFactor(
            name: "Systemic Risk",
            weight: 0.05,
            value: 0.0,
            description: "Risk of widespread or systematic issues"
        )
    }

    public struct SeverityAdjustment {
        let reason: String
        let adjustment: Double // -2.0 to +2.0
        let description: String

        public static func createAdjustment(
            reason: String,
            adjustment: Double,
            description: String
        ) -> SeverityAdjustment {
            let clampedAdjustment = max(-2.0, min(2.0, adjustment))
            return SeverityAdjustment(
                reason: reason,
                adjustment: clampedAdjustment,
                description: description
            )
        }
    }

    /// Calculate final severity score
    public var finalScore: Double {
        let baseScore = factors.reduce(0.0) { result, factor in
            result + (factor.value * factor.weight)
        }

        let adjustmentTotal = adjustments.reduce(0.0) { result, adjustment in
            result + adjustment.adjustment
        }

        return max(0.0, min(10.0, baseScore + adjustmentTotal))
    }

    /// Determine severity level from score
    public static func levelFromScore(_ score: Double) -> SeverityLevel {
        switch score {
        case 0.0...2.0: return .informational
        case 2.1...4.0: return .low
        case 4.1...6.0: return .medium
        case 6.1...8.0: return .high
        case 8.1...10.0: return .critical
        default: return .medium
        }
    }
}

/// Financial impact assessment
public struct FinancialImpactRange {
    let minimum: Double
    let maximum: Double
    let typical: Double
    let currency: String
    let impactType: ImpactType
    let compoundingEffect: CompoundingEffect

    public enum ImpactType: String, CaseIterable {
        case oneTime = "one_time"
        case recurring = "recurring"
        case cumulative = "cumulative"
        case compound = "compound"

        public var description: String {
            switch self {
            case .oneTime: return "One-time financial impact"
            case .recurring: return "Recurring financial impact over time"
            case .cumulative: return "Cumulative impact that builds over time"
            case .compound: return "Compound impact with exponential growth"
            }
        }
    }

    public enum CompoundingEffect: String, CaseIterable {
        case none = "none"
        case linear = "linear"
        case exponential = "exponential"

        public var multiplier: Double {
            switch self {
            case .none: return 1.0
            case .linear: return 1.5
            case .exponential: return 2.0
            }
        }
    }

    public func estimatedAnnualImpact(occurrencesPerYear: Int = 1) -> Double {
        let baseImpact = typical * Double(occurrencesPerYear)
        return baseImpact * compoundingEffect.multiplier
    }
}

/// Regulatory implications and references
public struct RegulatoryImplication {
    let regulation: RegulationType
    let section: String
    let description: String
    let penaltyRange: FinancialImpactRange?
    let enforcementAgency: EnforcementAgency
    let complianceRequired: Bool

    public enum RegulationType: String, CaseIterable {
        case respa = "RESPA"
        case tila = "TILA"
        case fcra = "FCRA"
        case fdcpa = "FDCPA"
        case cfpb = "CFPB"
        case state = "State"
        case contractual = "Contractual"

        public var fullName: String {
            switch self {
            case .respa: return "Real Estate Settlement Procedures Act"
            case .tila: return "Truth in Lending Act"
            case .fcra: return "Fair Credit Reporting Act"
            case .fdcpa: return "Fair Debt Collection Practices Act"
            case .cfpb: return "Consumer Financial Protection Bureau Rules"
            case .state: return "State Regulations"
            case .contractual: return "Contractual Obligations"
            }
        }
    }

    public enum EnforcementAgency: String, CaseIterable {
        case cfpb = "CFPB"
        case hud = "HUD"
        case stateRegulator = "State Regulator"
        case ftc = "FTC"
        case occ = "OCC"
        case courts = "Courts"

        public var fullName: String {
            switch self {
            case .cfpb: return "Consumer Financial Protection Bureau"
            case .hud: return "U.S. Department of Housing and Urban Development"
            case .stateRegulator: return "State Regulatory Agency"
            case .ftc: return "Federal Trade Commission"
            case .occ: return "Office of the Comptroller of the Currency"
            case .courts: return "Court System"
            }
        }
    }
}

/// Error pattern recognition for predictive analysis
public struct ErrorPattern {
    let id: UUID
    let name: String
    let description: String
    let categories: [MortgageErrorCategory.Category]
    let indicators: [PatternIndicator]
    let confidence: Double
    let prevalence: Prevalence
    let seasonality: Seasonality?

    public struct PatternIndicator {
        let name: String
        let weight: Double
        let threshold: Double
        let comparison: ComparisonType

        public enum ComparisonType: String, CaseIterable {
            case greaterThan = "greater_than"
            case lessThan = "less_than"
            case equals = "equals"
            case contains = "contains"
            case pattern = "pattern"
        }
    }

    public struct Prevalence {
        let percentage: Double // 0.0 to 100.0
        let sampleSize: Int
        let confidenceInterval: ClosedRange<Double>
        let lastUpdated: Date
    }

    public struct Seasonality {
        let pattern: SeasonalPattern
        let peakMonths: [Int] // 1-12
        let multiplier: Double

        public enum SeasonalPattern: String, CaseIterable {
            case none = "none"
            case quarterly = "quarterly"
            case semiAnnual = "semi_annual"
            case annual = "annual"
            case custom = "custom"
        }
    }
}

/// Error resolution tracking
public struct ErrorResolution {
    let errorId: UUID
    let resolutionStatus: ResolutionStatus
    let resolutionMethod: ResolutionMethod
    let timeToResolve: TimeInterval
    let cost: Double
    let borrowerSatisfaction: BorrowerSatisfactionRating?
    let preventativeMeasures: [PreventativeMeasure]
    let followUpRequired: Bool

    public enum ResolutionStatus: String, CaseIterable {
        case pending = "pending"
        case inProgress = "in_progress"
        case resolved = "resolved"
        case disputed = "disputed"
        case escalated = "escalated"
        case unresolved = "unresolved"

        public var displayName: String {
            switch self {
            case .pending: return "Pending Review"
            case .inProgress: return "In Progress"
            case .resolved: return "Resolved"
            case .disputed: return "Under Dispute"
            case .escalated: return "Escalated"
            case .unresolved: return "Unresolved"
            }
        }
    }

    public enum ResolutionMethod: String, CaseIterable {
        case automatic = "automatic"
        case servicerCorrection = "servicer_correction"
        case regulatoryIntervention = "regulatory_intervention"
        case legal = "legal"
        case mediation = "mediation"
        case courtOrder = "court_order"

        public var description: String {
            switch self {
            case .automatic: return "Automatically corrected by system"
            case .servicerCorrection: return "Corrected by mortgage servicer"
            case .regulatoryIntervention: return "Resolved through regulatory intervention"
            case .legal: return "Resolved through legal action"
            case .mediation: return "Resolved through mediation"
            case .courtOrder: return "Resolved by court order"
            }
        }
    }

    public struct BorrowerSatisfactionRating {
        let rating: Int // 1-5 stars
        let feedback: String?
        let wouldRecommend: Bool
        let responseTime: TimeInterval
    }

    public struct PreventativeMeasure {
        let description: String
        let implementationDate: Date
        let effectiveness: Double // 0.0 to 1.0
        let cost: Double
    }
}

// MARK: - Error Categorization Engine

/// Engine for automatically categorizing and scoring mortgage errors
public class ErrorCategorizationEngine {

    private let predefinedCategories: [MortgageErrorCategory.Category: MortgageErrorCategory]
    private let patternDatabase: [ErrorPattern]

    public init() {
        self.predefinedCategories = Self.createPredefinedCategories()
        self.patternDatabase = Self.createPatternDatabase()
    }

    /// Categorize and score an error
    public func categorizeError(
        title: String,
        description: String,
        financialImpact: Double?,
        affectedFields: [String],
        evidence: [String]
    ) -> (category: MortgageErrorCategory.Category, severity: ErrorSeverityRating) {

        // Analyze text for category determination
        let category = determineCategoryFromText(title: title, description: description, fields: affectedFields)

        // Calculate severity score
        let severity = calculateSeverityScore(
            category: category,
            financialImpact: financialImpact,
            description: description,
            evidence: evidence
        )

        return (category, severity)
    }

    /// Detect error patterns
    public func detectPatterns(in errors: [DetectedError]) -> [ErrorPattern] {
        var detectedPatterns: [ErrorPattern] = []

        for pattern in patternDatabase {
            let matchingErrors = errors.filter { error in
                pattern.categories.contains { category in
                    error.category.rawValue == category.rawValue
                }
            }

            if Double(matchingErrors.count) / Double(errors.count) >= pattern.prevalence.percentage / 100.0 {
                detectedPatterns.append(pattern)
            }
        }

        return detectedPatterns
    }

    // MARK: - Private Methods

    private func determineCategoryFromText(title: String, description: String, fields: [String]) -> MortgageErrorCategory.Category {
        let combinedText = "\(title) \(description) \(fields.joined(separator: " "))".lowercased()

        // Payment-related keywords
        if combinedText.contains("payment") && (combinedText.contains("allocation") || combinedText.contains("applied")) {
            return .paymentMisallocation
        } else if combinedText.contains("payment") && combinedText.contains("calculation") {
            return .paymentCalculation
        } else if combinedText.contains("late") && combinedText.contains("fee") {
            return .lateFeeErrors
        } else if combinedText.contains("interest") && combinedText.contains("calculation") {
            return .interestMiscalculation
        } else if combinedText.contains("principal") {
            return .principalMisallocation
        } else if combinedText.contains("escrow") {
            if combinedText.contains("shortage") {
                return .escrowShortage
            } else if combinedText.contains("overage") {
                return .escrowOverage
            } else {
                return .escrowMiscalculation
            }
        } else if combinedText.contains("fee") && combinedText.contains("unauthorized") {
            return .unauthorizedFees
        } else if combinedText.contains("respa") {
            return .respaViolations
        } else if combinedText.contains("tila") {
            return .tilaViolations
        } else if combinedText.contains("missing") {
            return .missingData
        } else if combinedText.contains("inconsistent") {
            return .inconsistentData
        }

        // Default to data integrity if unclear
        return .inconsistentData
    }

    private func calculateSeverityScore(
        category: MortgageErrorCategory.Category,
        financialImpact: Double?,
        description: String,
        evidence: [String]
    ) -> ErrorSeverityRating {

        var factors: [ErrorSeverityRating.SeverityFactor] = []

        // Financial Impact Factor
        let financialScore = calculateFinancialImpactScore(financialImpact)
        factors.append(ErrorSeverityRating.SeverityFactor(
            name: "Financial Impact",
            weight: 0.35,
            value: financialScore,
            description: "Direct monetary impact: $\(financialImpact ?? 0)"
        ))

        // Regulatory Compliance Factor
        let regulatoryScore = calculateRegulatoryScore(category: category)
        factors.append(ErrorSeverityRating.SeverityFactor(
            name: "Regulatory Compliance",
            weight: 0.25,
            value: regulatoryScore,
            description: "Regulatory violation severity"
        ))

        // Frequency Factor (estimated based on category)
        let frequencyScore = calculateFrequencyScore(category: category)
        factors.append(ErrorSeverityRating.SeverityFactor(
            name: "Frequency",
            weight: 0.20,
            value: frequencyScore,
            description: "Estimated frequency of occurrence"
        ))

        // Borrower Impact Factor
        let borrowerScore = calculateBorrowerImpactScore(description: description, evidence: evidence)
        factors.append(ErrorSeverityRating.SeverityFactor(
            name: "Borrower Impact",
            weight: 0.15,
            value: borrowerScore,
            description: "Impact on borrower's situation"
        ))

        // Systemic Risk Factor
        let systemicScore = calculateSystemicRiskScore(category: category)
        factors.append(ErrorSeverityRating.SeverityFactor(
            name: "Systemic Risk",
            weight: 0.05,
            value: systemicScore,
            description: "Risk of systematic issues"
        ))

        let rating = ErrorSeverityRating(
            level: .medium, // Will be determined by finalScore
            score: 0.0,     // Will be calculated
            factors: factors,
            adjustments: []
        )

        let finalScore = rating.finalScore
        let level = ErrorSeverityRating.levelFromScore(finalScore)

        return ErrorSeverityRating(
            level: level,
            score: finalScore,
            factors: factors,
            adjustments: []
        )
    }

    private func calculateFinancialImpactScore(_ impact: Double?) -> Double {
        guard let impact = impact else { return 2.0 }

        // Scale financial impact to 0-10 score
        switch abs(impact) {
        case 0..<10: return 1.0
        case 10..<50: return 2.0
        case 50..<100: return 3.0
        case 100..<500: return 5.0
        case 500..<1000: return 7.0
        case 1000..<5000: return 8.5
        default: return 10.0
        }
    }

    private func calculateRegulatoryScore(category: MortgageErrorCategory.Category) -> Double {
        switch category {
        case .respaViolations, .tilaViolations: return 9.0
        case .unauthorizedFees, .excessiveFees: return 7.0
        case .disclosureErrors, .noticeRequirements: return 6.0
        case .paymentMisallocation, .interestMiscalculation: return 5.0
        default: return 3.0
        }
    }

    private func calculateFrequencyScore(category: MortgageErrorCategory.Category) -> Double {
        // Based on industry data - more common errors get higher scores
        switch category {
        case .lateFeeErrors, .paymentMisallocation: return 8.0
        case .escrowMiscalculation, .interestMiscalculation: return 6.0
        case .unauthorizedFees, .paymentCalculation: return 5.0
        default: return 3.0
        }
    }

    private func calculateBorrowerImpactScore(description: String, evidence: [String]) -> Double {
        let combinedText = "\(description) \(evidence.joined(separator: " "))".lowercased()

        var score: Double = 3.0

        if combinedText.contains("credit") || combinedText.contains("foreclosure") {
            score += 3.0
        }
        if combinedText.contains("late") || combinedText.contains("delinquent") {
            score += 2.0
        }
        if combinedText.contains("fee") || combinedText.contains("charge") {
            score += 1.0
        }

        return min(score, 10.0)
    }

    private func calculateSystemicRiskScore(category: MortgageErrorCategory.Category) -> Double {
        switch category {
        case .corruptedData, .formatErrors: return 8.0
        case .respaViolations, .tilaViolations: return 7.0
        case .paymentMisallocation, .interestMiscalculation: return 5.0
        default: return 2.0
        }
    }

    // MARK: - Static Factory Methods

    private static func createPredefinedCategories() -> [MortgageErrorCategory.Category: MortgageErrorCategory] {
        // Implementation would create comprehensive category definitions
        // This is a simplified example
        return [:]
    }

    private static func createPatternDatabase() -> [ErrorPattern] {
        // Implementation would create pattern recognition database
        // This is a simplified example
        return []
    }
}

// MARK: - Placeholder Types for Compatibility

/// Detected error structure for categorization
public struct DetectedError {
    let id: UUID
    let category: MortgageErrorCategory.Category
    let title: String
    let description: String
    let financialImpact: Double?
    let severity: ErrorSeverityRating
    let timestamp: Date
}