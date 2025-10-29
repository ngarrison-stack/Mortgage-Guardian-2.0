import Foundation
import RegexBuilder
@testable import MortgageGuardian

/// Live Compliance Validation Engine for testing against real regulations
///
/// This engine provides:
/// - Validation against actual RESPA, TILA, and CFPB regulations
/// - Real regulatory text processing and interpretation
/// - Accurate citation generation and cross-referencing
/// - Live calculation validation using official formulas
/// - Production-equivalent compliance scoring
///
/// Uses actual regulatory documents and legal frameworks
/// to ensure zero-tolerance compliance validation accuracy
class LiveComplianceValidationEngine {

    // MARK: - Configuration

    private struct ComplianceConfiguration {
        static let regulatoryDataPath = ProcessInfo.processInfo.environment["REGULATORY_DATA_PATH"] ?? "/tmp/regulatory_data"
        static let enableLiveCFPBAPI = ProcessInfo.processInfo.environment["ENABLE_LIVE_CFPB"] == "true"
        static let complianceConfidenceThreshold = 0.95
        static let calculationTolerancePercent = 0.001 // 0.1% tolerance for calculations
        static let regulatoryUpdateInterval: TimeInterval = 86400 // 24 hours
    }

    // MARK: - Properties

    private let regulatoryDatabase: RegulatoryDatabase
    private let respaValidator: RESPAComplianceValidator
    private let tilaValidator: TILAComplianceValidator
    private let cfpbValidator: CFPBComplianceValidator
    private let calculationEngine: ComplianceCalculationEngine
    private let citationGenerator: RegulatoryCitationGenerator

    private var regulatoryCache: [String: RegulatoryDocument] = [:]
    private var lastUpdateTime: Date = Date.distantPast

    // MARK: - Initialization

    init() throws {
        let regulatoryPath = URL(fileURLWithPath: ComplianceConfiguration.regulatoryDataPath)

        // Verify regulatory data directory exists
        guard FileManager.default.fileExists(atPath: regulatoryPath.path) else {
            throw ComplianceValidationError.regulatoryDataNotFound(ComplianceConfiguration.regulatoryDataPath)
        }

        self.regulatoryDatabase = try RegulatoryDatabase(dataPath: regulatoryPath)
        self.respaValidator = RESPAComplianceValidator(database: regulatoryDatabase)
        self.tilaValidator = TILAComplianceValidator(database: regulatoryDatabase)
        self.cfpbValidator = CFPBComplianceValidator(database: regulatoryDatabase)
        self.calculationEngine = ComplianceCalculationEngine()
        self.citationGenerator = RegulatoryCitationGenerator(database: regulatoryDatabase)

        // Load regulatory data
        try loadRegulatoryData()

        print("⚖️ Live Compliance Validation Engine initialized")
        print("📚 Loaded \(regulatoryCache.count) regulatory documents")
    }

    // MARK: - RESPA Compliance Validation

    /// Validate compliance against actual RESPA regulations
    func validateRESPACompliance(
        extractedData: ExtractedData,
        section: String,
        regulatoryText: String
    ) async throws -> ComplianceValidationResult {

        print("📋 Validating RESPA Section \(section) compliance...")

        // Load specific RESPA section requirements
        let sectionRequirements = try await regulatoryDatabase.getRESPASection(section)

        // Perform section-specific validation
        let validationResult = try await respaValidator.validateSection(
            section,
            extractedData: extractedData,
            requirements: sectionRequirements
        )

        // Generate regulatory citations
        let citations = try await citationGenerator.generateRESPACitations(
            section: section,
            violations: validationResult.violations
        )

        // Calculate compliance confidence
        let confidence = calculateComplianceConfidence(
            validationResult: validationResult,
            sectionComplexity: sectionRequirements.complexity
        )

        return ComplianceValidationResult(
            regulationType: .respa,
            section: section,
            hasViolation: !validationResult.violations.isEmpty,
            violations: validationResult.violations,
            confidence: confidence,
            regulatoryCitations: citations,
            validationDetails: validationResult.details,
            expectedViolation: validationResult.expectedViolation
        )
    }

    /// Load RESPA test cases for validation
    func loadRESPATestCases() async throws -> [ComplianceTestCase] {
        print("📚 Loading RESPA compliance test cases...")

        let testCases = try await regulatoryDatabase.getRESPATestCases()

        // Validate test cases have required regulatory backing
        var validatedTestCases: [ComplianceTestCase] = []

        for testCase in testCases {
            do {
                let sectionRequirements = try await regulatoryDatabase.getRESPASection(testCase.section)

                // Ensure test case has actual regulatory text
                guard !sectionRequirements.regulatoryText.isEmpty else {
                    print("⚠️ Skipping test case \(testCase.id): No regulatory text found")
                    continue
                }

                let validatedTestCase = ComplianceTestCase(
                    id: testCase.id,
                    section: testCase.section,
                    description: testCase.description,
                    documentType: testCase.documentType,
                    expectsViolation: testCase.expectsViolation,
                    actualRegulationText: sectionRequirements.regulatoryText,
                    minimumComplexity: sectionRequirements.complexity,
                    expectedAPR: nil,
                    expectedFinanceCharge: nil,
                    tilaRequirements: nil
                )

                validatedTestCases.append(validatedTestCase)

            } catch {
                print("⚠️ Failed to validate test case \(testCase.id): \(error)")
                continue
            }
        }

        print("✅ Loaded \(validatedTestCases.count) validated RESPA test cases")
        return validatedTestCases
    }

    /// Validate escrow compliance against RESPA Section 10
    func validateEscrowCompliance(
        extractedData: ExtractedData,
        regulatoryContext: RegulatoryContext
    ) async throws -> ComplianceValidationResult {

        print("🏠 Validating escrow compliance against RESPA Section 10...")

        let escrowRequirements = try await regulatoryDatabase.getRESPASection("10")

        // Validate escrow account calculations
        let calculationValidation = try await calculationEngine.validateEscrowCalculations(
            extractedData: extractedData,
            requirements: escrowRequirements
        )

        // Check for specific escrow violations
        var violations: [ComplianceViolation] = []

        // Validate escrow analysis timing
        if let analysisDate = extractedData.escrowAnalysisDate {
            let timingViolation = try await validateEscrowAnalysisTiming(
                analysisDate: analysisDate,
                requirements: escrowRequirements
            )
            if let violation = timingViolation {
                violations.append(violation)
            }
        }

        // Validate escrow shortage calculations
        if let shortage = extractedData.escrowShortage {
            let shortageViolation = try await validateEscrowShortageCalculation(
                shortage: shortage,
                extractedData: extractedData,
                requirements: escrowRequirements
            )
            if let violation = shortageViolation {
                violations.append(violation)
            }
        }

        // Validate force-placed insurance compliance
        if let insurance = extractedData.forcePlacedInsurance {
            let insuranceViolation = try await validateForcePlacedInsuranceCompliance(
                insurance: insurance,
                requirements: escrowRequirements
            )
            if let violation = insuranceViolation {
                violations.append(violation)
            }
        }

        // Add calculation violations
        violations.append(contentsOf: calculationValidation.violations)

        // Generate citations
        let citations = try await citationGenerator.generateRESPACitations(
            section: "10",
            violations: violations
        )

        let confidence = calculateComplianceConfidence(
            validationResult: ValidationResult(
                violations: violations,
                details: calculationValidation.details,
                expectedViolation: false
            ),
            sectionComplexity: escrowRequirements.complexity
        )

        return ComplianceValidationResult(
            regulationType: .respa,
            section: "10",
            hasViolation: !violations.isEmpty,
            violations: violations,
            confidence: confidence,
            regulatoryCitations: citations,
            validationDetails: calculationValidation.details,
            expectedViolation: false
        )
    }

    // MARK: - TILA Compliance Validation

    /// Load TILA test cases for validation
    func loadTILATestCases() async throws -> [ComplianceTestCase] {
        print("📊 Loading TILA compliance test cases...")

        let testCases = try await regulatoryDatabase.getTILATestCases()

        var validatedTestCases: [ComplianceTestCase] = []

        for testCase in testCases {
            do {
                let tilaRequirements = try await regulatoryDatabase.getTILARequirements(testCase.section)

                let validatedTestCase = ComplianceTestCase(
                    id: testCase.id,
                    section: testCase.section,
                    description: testCase.description,
                    documentType: testCase.documentType,
                    expectsViolation: testCase.expectsViolation,
                    actualRegulationText: tilaRequirements.regulatoryText,
                    minimumComplexity: tilaRequirements.complexity,
                    expectedAPR: testCase.expectedAPR,
                    expectedFinanceCharge: testCase.expectedFinanceCharge,
                    tilaRequirements: tilaRequirements
                )

                validatedTestCases.append(validatedTestCase)

            } catch {
                print("⚠️ Failed to validate TILA test case \(testCase.id): \(error)")
                continue
            }
        }

        print("✅ Loaded \(validatedTestCases.count) validated TILA test cases")
        return validatedTestCases
    }

    /// Validate TILA calculations using official formulas
    func validateTILACalculations(
        extractedData: ExtractedData,
        regulatoryRequirements: TILARequirements
    ) async throws -> TILACalculationResult {

        print("📊 Validating TILA calculations using official formulas...")

        // Calculate APR using official TILA formula
        let calculatedAPR = try await calculationEngine.calculateTILAAP(
            principalAmount: extractedData.loanAmount ?? 0,
            financeCharge: extractedData.financeCharge ?? 0,
            loanTerm: extractedData.loanTermMonths ?? 0,
            paymentSchedule: extractedData.paymentSchedule ?? []
        )

        // Calculate finance charge
        let calculatedFinanceCharge = try await calculationEngine.calculateTILAFinanceCharge(
            totalPayments: extractedData.totalPayments ?? 0,
            principalAmount: extractedData.loanAmount ?? 0,
            prepaidFinanceCharges: extractedData.prepaidFinanceCharges ?? 0
        )

        // Validate disclosure requirements
        let disclosureValidation = try await tilaValidator.validateDisclosureRequirements(
            extractedData: extractedData,
            requirements: regulatoryRequirements
        )

        // Check for calculation accuracy within tolerance
        var calculationErrors: [TILACalculationError] = []

        if let extractedAPR = extractedData.apr {
            let aprDifference = abs(calculatedAPR - extractedAPR)
            let aprTolerance = calculatedAPR * ComplianceConfiguration.calculationTolerancePercent

            if aprDifference > aprTolerance {
                calculationErrors.append(
                    TILACalculationError(
                        type: .aprMiscalculation,
                        expectedValue: calculatedAPR,
                        actualValue: extractedAPR,
                        difference: aprDifference,
                        tolerance: aprTolerance
                    )
                )
            }
        }

        if let extractedFinanceCharge = extractedData.financeCharge {
            let fcDifference = abs(calculatedFinanceCharge - extractedFinanceCharge)
            let fcTolerance = calculatedFinanceCharge * ComplianceConfiguration.calculationTolerancePercent

            if fcDifference > fcTolerance {
                calculationErrors.append(
                    TILACalculationError(
                        type: .financeChargeMiscalculation,
                        expectedValue: calculatedFinanceCharge,
                        actualValue: extractedFinanceCharge,
                        difference: fcDifference,
                        tolerance: fcTolerance
                    )
                )
            }
        }

        return TILACalculationResult(
            calculatedAPR: calculatedAPR,
            calculatedFinanceCharge: calculatedFinanceCharge,
            disclosureValidation: disclosureValidation,
            calculationErrors: calculationErrors,
            isValid: calculationErrors.isEmpty && disclosureValidation.isValid
        )
    }

    // MARK: - Full Compliance Validation

    /// Validate full compliance across all regulations
    func validateFullCompliance(
        extractedData: ExtractedData,
        bankVerification: PaymentVerificationResult,
        aiAnalysis: AIAnalysisResult
    ) async throws -> ComplianceValidationResult {

        print("🔍 Performing full compliance validation...")

        var allViolations: [ComplianceViolation] = []
        var allCitations: [RegulatoryCitation] = []
        var validationDetails: [String: Any] = [:]

        // RESPA validation
        let respaResult = try await validateComprehensiveRESPA(
            extractedData: extractedData,
            bankVerification: bankVerification
        )
        allViolations.append(contentsOf: respaResult.violations)
        allCitations.append(contentsOf: respaResult.regulatoryCitations)
        validationDetails["respa"] = respaResult.validationDetails

        // TILA validation
        let tilaResult = try await validateComprehensiveTILA(
            extractedData: extractedData,
            aiAnalysis: aiAnalysis
        )
        allViolations.append(contentsOf: tilaResult.violations)
        allCitations.append(contentsOf: tilaResult.regulatoryCitations)
        validationDetails["tila"] = tilaResult.validationDetails

        // CFPB validation
        let cfpbResult = try await validateCFPBCompliance(
            extractedData: extractedData,
            bankVerification: bankVerification
        )
        allViolations.append(contentsOf: cfpbResult.violations)
        allCitations.append(contentsOf: cfpbResult.regulatoryCitations)
        validationDetails["cfpb"] = cfpbResult.validationDetails

        // Calculate overall compliance confidence
        let overallConfidence = calculateOverallComplianceConfidence([
            respaResult, tilaResult, cfpbResult
        ])

        return ComplianceValidationResult(
            regulationType: .comprehensive,
            section: "ALL",
            hasViolation: !allViolations.isEmpty,
            violations: allViolations,
            confidence: overallConfidence,
            regulatoryCitations: allCitations,
            validationDetails: validationDetails,
            expectedViolation: false
        )
    }

    // MARK: - Private Helper Methods

    private func loadRegulatoryData() throws {
        // Load RESPA regulations
        let respaDocuments = try regulatoryDatabase.loadRESPADocuments()
        for document in respaDocuments {
            regulatoryCache[document.id] = document
        }

        // Load TILA regulations
        let tilaDocuments = try regulatoryDatabase.loadTILADocuments()
        for document in tilaDocuments {
            regulatoryCache[document.id] = document
        }

        // Load CFPB guidance
        let cfpbDocuments = try regulatoryDatabase.loadCFPBDocuments()
        for document in cfpbDocuments {
            regulatoryCache[document.id] = document
        }

        lastUpdateTime = Date()
    }

    private func validateEscrowAnalysisTiming(
        analysisDate: Date,
        requirements: RESPASection
    ) async throws -> ComplianceViolation? {

        // RESPA requires annual escrow analysis
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!

        if analysisDate < oneYearAgo {
            return ComplianceViolation(
                type: .timingViolation,
                description: "Escrow analysis not performed within required 12-month period",
                severity: .major,
                regulatorySection: "RESPA Section 10",
                confidence: 0.99
            )
        }

        return nil
    }

    private func validateEscrowShortageCalculation(
        shortage: Double,
        extractedData: ExtractedData,
        requirements: RESPASection
    ) async throws -> ComplianceViolation? {

        // Calculate expected shortage using official RESPA formula
        let expectedShortage = try await calculationEngine.calculateEscrowShortage(
            currentBalance: extractedData.escrowBalance ?? 0,
            projectedDisbursements: extractedData.projectedEscrowDisbursements ?? 0,
            projectedDeposits: extractedData.projectedEscrowDeposits ?? 0,
            cushion: extractedData.escrowCushion ?? 0
        )

        let difference = abs(shortage - expectedShortage)
        let tolerance = expectedShortage * ComplianceConfiguration.calculationTolerancePercent

        if difference > tolerance {
            return ComplianceViolation(
                type: .calculationError,
                description: "Escrow shortage calculation error: Expected \(expectedShortage), found \(shortage)",
                severity: .major,
                regulatorySection: "RESPA Section 10",
                confidence: 0.97
            )
        }

        return nil
    }

    private func validateForcePlacedInsuranceCompliance(
        insurance: ForcePlacedInsurance,
        requirements: RESPASection
    ) async throws -> ComplianceViolation? {

        // Validate notice requirements
        guard let noticeDate = insurance.noticeDate else {
            return ComplianceViolation(
                type: .noticeViolation,
                description: "No notice date found for force-placed insurance",
                severity: .critical,
                regulatorySection: "RESPA Section 10",
                confidence: 0.99
            )
        }

        // Check 45-day notice requirement
        let requiredNoticeDate = Calendar.current.date(byAdding: .day, value: -45, to: insurance.effectiveDate)!

        if noticeDate > requiredNoticeDate {
            return ComplianceViolation(
                type: .noticeViolation,
                description: "Insufficient notice period for force-placed insurance",
                severity: .major,
                regulatorySection: "RESPA Section 10",
                confidence: 0.96
            )
        }

        return nil
    }

    private func validateComprehensiveRESPA(
        extractedData: ExtractedData,
        bankVerification: PaymentVerificationResult
    ) async throws -> ComplianceValidationResult {

        // Validate all RESPA sections
        var violations: [ComplianceViolation] = []

        // Section 6 - Servicing transfers
        let section6Violations = try await respaValidator.validateSection6(
            extractedData: extractedData
        )
        violations.append(contentsOf: section6Violations)

        // Section 8 - Kickbacks
        let section8Violations = try await respaValidator.validateSection8(
            extractedData: extractedData
        )
        violations.append(contentsOf: section8Violations)

        // Section 10 - Escrow accounts
        let section10Violations = try await respaValidator.validateSection10(
            extractedData: extractedData
        )
        violations.append(contentsOf: section10Violations)

        let citations = try await citationGenerator.generateRESPACitations(
            section: "ALL",
            violations: violations
        )

        return ComplianceValidationResult(
            regulationType: .respa,
            section: "ALL",
            hasViolation: !violations.isEmpty,
            violations: violations,
            confidence: violations.isEmpty ? 1.0 : 0.95,
            regulatoryCitations: citations,
            validationDetails: ["comprehensive_respa": true],
            expectedViolation: false
        )
    }

    private func validateComprehensiveTILA(
        extractedData: ExtractedData,
        aiAnalysis: AIAnalysisResult
    ) async throws -> ComplianceValidationResult {

        let tilaRequirements = try await regulatoryDatabase.getTILARequirements("ALL")

        let calculationResult = try await validateTILACalculations(
            extractedData: extractedData,
            regulatoryRequirements: tilaRequirements
        )

        let violations = calculationResult.calculationErrors.map { error in
            ComplianceViolation(
                type: .calculationError,
                description: "TILA calculation error: \(error.type.rawValue)",
                severity: .major,
                regulatorySection: "TILA",
                confidence: 0.98
            )
        }

        let citations = try await citationGenerator.generateTILACitations(
            violations: violations
        )

        return ComplianceValidationResult(
            regulationType: .tila,
            section: "ALL",
            hasViolation: !violations.isEmpty,
            violations: violations,
            confidence: violations.isEmpty ? 1.0 : 0.94,
            regulatoryCitations: citations,
            validationDetails: ["calculation_result": calculationResult],
            expectedViolation: false
        )
    }

    private func validateCFPBCompliance(
        extractedData: ExtractedData,
        bankVerification: PaymentVerificationResult
    ) async throws -> ComplianceValidationResult {

        // Validate CFPB mortgage servicing rules
        let violations = try await cfpbValidator.validateMortgageServicingRules(
            extractedData: extractedData,
            bankVerification: bankVerification
        )

        let citations = try await citationGenerator.generateCFPBCitations(
            violations: violations
        )

        return ComplianceValidationResult(
            regulationType: .cfpb,
            section: "1024",
            hasViolation: !violations.isEmpty,
            violations: violations,
            confidence: violations.isEmpty ? 1.0 : 0.93,
            regulatoryCitations: citations,
            validationDetails: ["cfpb_servicing": true],
            expectedViolation: false
        )
    }

    private func calculateComplianceConfidence(
        validationResult: ValidationResult,
        sectionComplexity: Double
    ) -> Double {

        let baseConfidence = 0.95

        // Reduce confidence based on number of violations
        let violationPenalty = Double(validationResult.violations.count) * 0.02

        // Adjust for section complexity
        let complexityAdjustment = (1.0 - sectionComplexity) * 0.05

        let finalConfidence = baseConfidence - violationPenalty + complexityAdjustment

        return max(0.0, min(1.0, finalConfidence))
    }

    private func calculateOverallComplianceConfidence(_ results: [ComplianceValidationResult]) -> Double {
        guard !results.isEmpty else { return 0.0 }

        let averageConfidence = results.map { $0.confidence }.reduce(0, +) / Double(results.count)
        let hasAnyViolations = results.contains { $0.hasViolation }

        return hasAnyViolations ? min(averageConfidence, 0.9) : averageConfidence
    }
}

// MARK: - Supporting Types

enum RegulatoryType {
    case respa
    case tila
    case cfpb
    case comprehensive
}

enum RegulatoryContext {
    case respaSection6
    case respaSection8
    case respaSection10
    case tilaDisclosure
    case cfpbServicing
}

struct ComplianceValidationResult {
    let regulationType: RegulatoryType
    let section: String
    let hasViolation: Bool
    let violations: [ComplianceViolation]
    let confidence: Double
    let regulatoryCitations: [RegulatoryCitation]
    let validationDetails: [String: Any]
    let expectedViolation: Bool
}

struct TILACalculationResult {
    let calculatedAPR: Double
    let calculatedFinanceCharge: Double
    let disclosureValidation: DisclosureValidation
    let calculationErrors: [TILACalculationError]
    let isValid: Bool
}

struct TILACalculationError {
    let type: TILACalculationType
    let expectedValue: Double
    let actualValue: Double
    let difference: Double
    let tolerance: Double
}

struct ComplianceViolation {
    let type: ViolationType
    let description: String
    let severity: ViolationSeverity
    let regulatorySection: String
    let confidence: Double
}

struct RegulatoryCitation {
    let regulation: String
    let section: String
    let subsection: String?
    let text: String
    let url: String?
}

struct ValidationResult {
    let violations: [ComplianceViolation]
    let details: [String: Any]
    let expectedViolation: Bool
}

struct DisclosureValidation {
    let isValid: Bool
    let missingDisclosures: [String]
    let incorrectDisclosures: [String]
}

struct ForcePlacedInsurance {
    let noticeDate: Date?
    let effectiveDate: Date
    let amount: Double
    let provider: String
}

enum TILACalculationType: String {
    case aprMiscalculation = "APR Miscalculation"
    case financeChargeMiscalculation = "Finance Charge Miscalculation"
    case paymentScheduleError = "Payment Schedule Error"
}

enum ViolationType {
    case timingViolation
    case calculationError
    case noticeViolation
    case disclosureViolation
    case procedureViolation
}

enum ViolationSeverity {
    case minor
    case major
    case critical
}

enum ComplianceValidationError: Error, LocalizedError {
    case regulatoryDataNotFound(String)
    case invalidSection(String)
    case calculationFailed(String)
    case missingRequiredData(String)

    var errorDescription: String? {
        switch self {
        case .regulatoryDataNotFound(let path):
            return "Regulatory data not found: \(path)"
        case .invalidSection(let section):
            return "Invalid regulatory section: \(section)"
        case .calculationFailed(let reason):
            return "Calculation failed: \(reason)"
        case .missingRequiredData(let data):
            return "Missing required data: \(data)"
        }
    }
}