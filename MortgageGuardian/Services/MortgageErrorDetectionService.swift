import Foundation
import Combine
import os.log

/// Tiered Error Detection Service that prioritizes cost-efficient rule-based detection
/// before escalating to Claude AI analysis for complex pattern detection
@MainActor
public final class MortgageErrorDetectionService: ObservableObject {

    // MARK: - Types

    /// Error detection configuration
    public struct DetectionConfiguration {
        let enableRuleBasedDetection: Bool
        let enableAIAnalysis: Bool
        let enableZeroToleranceMode: Bool // NEW: Zero-tolerance mode for critical documents
        let aiAnalysisThreshold: Double // Cost threshold to trigger AI analysis
        let maxConcurrentAnalyses: Int
        let ruleBasedTimeout: TimeInterval
        let aiAnalysisTimeout: TimeInterval
        let zeroToleranceTimeout: TimeInterval // NEW: Timeout for zero-tolerance analysis
        let costBudgetPerDocument: Double // Maximum cost per document analysis

        public static let `default` = DetectionConfiguration(
            enableRuleBasedDetection: true,
            enableAIAnalysis: true,
            enableZeroToleranceMode: false, // Disabled by default due to cost
            aiAnalysisThreshold: 0.3, // Only trigger AI if rule-based confidence < 30%
            maxConcurrentAnalyses: 3,
            ruleBasedTimeout: 10.0,
            aiAnalysisTimeout: 30.0,
            zeroToleranceTimeout: 120.0, // 2 minutes for comprehensive analysis
            costBudgetPerDocument: 0.50 // $0.50 max per document
        )

        public static let zeroTolerance = DetectionConfiguration(
            enableRuleBasedDetection: true,
            enableAIAnalysis: true,
            enableZeroToleranceMode: true,
            aiAnalysisThreshold: 0.0, // Always use AI in zero-tolerance mode
            maxConcurrentAnalyses: 1, // Single threaded for accuracy
            ruleBasedTimeout: 30.0,
            aiAnalysisTimeout: 60.0,
            zeroToleranceTimeout: 300.0, // 5 minutes for comprehensive analysis
            costBudgetPerDocument: 5.00 // Higher budget for zero-tolerance
        )
    }

    /// Analysis tier that detected the error
    public enum DetectionTier: String, Codable, CaseIterable {
        case ruleBased = "rule_based"
        case aiAnalysis = "ai_analysis"
        case hybrid = "hybrid" // Combination of both
        case zeroTolerance = "zero_tolerance" // NEW: Zero-tolerance triple redundancy
    }

    /// Error severity levels
    public enum ErrorSeverity: String, Codable, CaseIterable {
        case critical = "critical"     // Financial impact > $1000 or legal compliance
        case high = "high"             // Financial impact $100-$1000
        case medium = "medium"         // Financial impact $10-$100
        case low = "low"               // Financial impact < $10 or cosmetic
        case informational = "info"   // No financial impact, just notices

        var numericValue: Int {
            switch self {
            case .critical: return 5
            case .high: return 4
            case .medium: return 3
            case .low: return 2
            case .informational: return 1
            }
        }
    }

    /// Comprehensive error categorization
    public enum ErrorCategory: String, Codable, CaseIterable {
        // Payment-related errors
        case paymentAllocation = "payment_allocation"
        case paymentCalculation = "payment_calculation"
        case lateFeeMiscalculation = "late_fee_miscalculation"
        case paymentTiming = "payment_timing"

        // Interest and principal errors
        case interestCalculation = "interest_calculation"
        case principalCalculation = "principal_calculation"
        case amortizationError = "amortization_error"
        case interestRateApplication = "interest_rate_application"

        // Escrow-related errors
        case escrowCalculation = "escrow_calculation"
        case escrowShortage = "escrow_shortage"
        case escrowOverage = "escrow_overage"
        case escrowTiming = "escrow_timing"
        case taxPaymentError = "tax_payment_error"
        case insurancePaymentError = "insurance_payment_error"

        // Fee-related errors
        case unauthorizedFees = "unauthorized_fees"
        case incorrectFeeAmount = "incorrect_fee_amount"
        case duplicateFees = "duplicate_fees"
        case feeWaiveError = "fee_waive_error"

        // Data integrity errors
        case missingData = "missing_data"
        case inconsistentData = "inconsistent_data"
        case formatError = "format_error"
        case calculationMismatch = "calculation_mismatch"

        // Compliance errors
        case respaViolation = "respa_violation"
        case tilaViolation = "tila_violation"
        case disclosureError = "disclosure_error"
        case timelineViolation = "timeline_violation"

        // System errors
        case dataCorruption = "data_corruption"
        case systemCalculationError = "system_calculation_error"
        case auditTrailMissing = "audit_trail_missing"
    }

    /// Detected error with comprehensive metadata
    public struct DetectedError: Identifiable, Codable {
        public let id = UUID()
        let category: ErrorCategory
        let severity: ErrorSeverity
        let detectionTier: DetectionTier
        let title: String
        let description: String
        let affectedFields: [String]
        let financialImpact: Double? // Estimated dollar impact
        let confidence: Double // 0.0 to 1.0
        let evidence: [Evidence]
        let suggestedAction: String
        let regulatoryReference: String?
        let detectionTimestamp: Date
        let detectionCost: Double // Cost of detecting this error

        public struct Evidence: Codable, Identifiable {
            public let id = UUID()
            let type: EvidenceType
            let description: String
            let value: String
            let expectedValue: String?
            let calculation: String?

            public enum EvidenceType: String, Codable {
                case calculation = "calculation"
                case comparison = "comparison"
                case pattern = "pattern"
                case regulation = "regulation"
                case crossReference = "cross_reference"
            }
        }
    }

    /// Analysis results with cost metrics
    public struct AnalysisResult {
        let detectedErrors: [DetectedError]
        let analysisMetrics: AnalysisMetrics
        let costBreakdown: CostBreakdown
        let recommendedActions: [RecommendedAction]

        public struct AnalysisMetrics {
            let totalAnalysisTime: TimeInterval
            let ruleBasedAnalysisTime: TimeInterval
            let aiAnalysisTime: TimeInterval?
            let errorsDetectedByRules: Int
            let errorsDetectedByAI: Int
            let overallConfidence: Double
            let coveragePercentage: Double // Percentage of document analyzed
        }

        public struct CostBreakdown {
            let ruleBasedCost: Double
            let aiAnalysisCost: Double
            let totalCost: Double
            let costPerError: Double?
            let budgetUtilization: Double // Percentage of budget used
        }

        public struct RecommendedAction: Identifiable {
            public let id = UUID()
            let priority: ActionPriority
            let action: String
            let estimatedTimeToComplete: TimeInterval
            let potentialSavings: Double?

            public enum ActionPriority: String, Codable {
                case immediate = "immediate"
                case urgent = "urgent"
                case normal = "normal"
                case low = "low"
            }
        }
    }

    // MARK: - Properties

    @Published public var isAnalyzing = false
    @Published public var analysisProgress: Double = 0.0
    @Published public var currentAnalysisStep: String = ""
    @Published public var lastAnalysisResult: AnalysisResult?

    private let auditEngine: AuditEngine
    private let aiAnalysisService: AIAnalysisService
    private let zeroToleranceEngine: ZeroToleranceAuditEngine? // NEW: Zero-tolerance engine
    private let logger = Logger(subsystem: "MortgageGuardian", category: "ErrorDetection")
    private var cancellables = Set<AnyCancellable>()
    private let configuration: DetectionConfiguration

    // Cost tracking
    private var sessionCosts: [String: Double] = [:]
    private let costTracker = CostTracker()

    // MARK: - Initialization

    public init(
        auditEngine: AuditEngine = AuditEngine(),
        aiAnalysisService: AIAnalysisService = AIAnalysisService.shared,
        zeroToleranceEngine: ZeroToleranceAuditEngine? = nil, // NEW: Optional zero-tolerance engine
        configuration: DetectionConfiguration = .default
    ) {
        self.auditEngine = auditEngine
        self.aiAnalysisService = aiAnalysisService
        self.zeroToleranceEngine = zeroToleranceEngine
        self.configuration = configuration

        setupSubscriptions()
    }

    /// Convenience initializer for zero-tolerance mode
    public static func zeroToleranceMode() -> MortgageErrorDetectionService {
        let zeroToleranceEngine = ZeroToleranceAuditEngine(
            configuration: .strict,
            ruleBasedEngine: ComprehensiveRuleEngine(configuration: .zeroTolerance),
            multiModelConsensus: MultiModelConsensusService(configuration: .strict),
            qualityAssurance: QualityAssuranceWorkflowEngine(configuration: .strict),
            legalCompliance: LegalComplianceVerificationSystem(configuration: .maximum)
        )

        return MortgageErrorDetectionService(
            zeroToleranceEngine: zeroToleranceEngine,
            configuration: .zeroTolerance
        )
    }

    // MARK: - Public Methods

    /// Perform tiered error detection analysis on mortgage document
    public func analyzeDocument(
        extractedData: ExtractedData,
        bankTransactions: [Transaction] = [],
        loanDetails: LoanDetails? = nil,
        documentId: String
    ) async throws -> AnalysisResult {

        guard !isAnalyzing else {
            throw ErrorDetectionError.analysisInProgress
        }

        await updateProgress(0.0, step: "Initializing tiered error detection")
        isAnalyzing = true

        let startTime = Date()
        let sessionId = UUID().uuidString

        defer {
            Task { @MainActor in
                isAnalyzing = false
                analysisProgress = 0.0
                currentAnalysisStep = ""
            }
        }

        do {
            // Check if zero-tolerance mode is enabled
            if configuration.enableZeroToleranceMode, let zeroToleranceEngine = zeroToleranceEngine {
                return try await performZeroToleranceAnalysis(
                    extractedData: extractedData,
                    bankTransactions: bankTransactions,
                    loanDetails: loanDetails,
                    documentId: documentId,
                    sessionId: sessionId,
                    startTime: startTime
                )
            }

            // TIER 1: Rule-Based Error Detection (Low Cost)
            await updateProgress(0.1, step: "Performing rule-based error detection")
            let ruleBasedStartTime = Date()

            let ruleBasedResults = try await performRuleBasedDetection(
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                sessionId: sessionId
            )

            let ruleBasedTime = Date().timeIntervalSince(ruleBasedStartTime)
            let ruleBasedCost = costTracker.calculateRuleBasedCost(
                analysisTime: ruleBasedTime,
                dataComplexity: extractedData.complexityScore
            )

            await updateProgress(0.6, step: "Rule-based detection complete")

            // Determine if AI analysis is needed
            let needsAIAnalysis = shouldTriggerAIAnalysis(
                ruleBasedResults: ruleBasedResults,
                extractedData: extractedData
            )

            var aiResults: [DetectedError] = []
            var aiAnalysisTime: TimeInterval = 0
            var aiCost: Double = 0

            // TIER 2: AI Analysis (Higher Cost) - Only if needed
            if needsAIAnalysis && configuration.enableAIAnalysis {
                await updateProgress(0.7, step: "Performing AI-powered complex pattern analysis")
                let aiStartTime = Date()

                aiResults = try await performAIAnalysis(
                    extractedData: extractedData,
                    bankTransactions: bankTransactions,
                    loanDetails: loanDetails,
                    ruleBasedResults: ruleBasedResults,
                    sessionId: sessionId
                )

                aiAnalysisTime = Date().timeIntervalSince(aiStartTime)
                aiCost = costTracker.calculateAICost(
                    analysisTime: aiAnalysisTime,
                    inputTokens: extractedData.estimatedTokenCount,
                    outputTokens: aiResults.count * 100 // Estimated
                )
            }

            await updateProgress(0.9, step: "Consolidating results and generating recommendations")

            // Combine and analyze results
            let allErrors = combineResults(
                ruleBasedResults: ruleBasedResults,
                aiResults: aiResults
            )

            let totalTime = Date().timeIntervalSince(startTime)
            let totalCost = ruleBasedCost + aiCost

            // Track costs
            sessionCosts[sessionId] = totalCost

            let result = createAnalysisResult(
                errors: allErrors,
                ruleBasedTime: ruleBasedTime,
                aiAnalysisTime: aiAnalysisTime > 0 ? aiAnalysisTime : nil,
                ruleBasedCost: ruleBasedCost,
                aiCost: aiCost,
                totalTime: totalTime,
                ruleBasedErrorCount: ruleBasedResults.count,
                aiErrorCount: aiResults.count
            )

            await updateProgress(1.0, step: "Analysis complete")
            lastAnalysisResult = result

            logger.info("Error detection complete: \(allErrors.count) errors found in \(String(format: "%.1f", totalTime))s for $\(String(format: "%.4f", totalCost))")

            return result

        } catch {
            logger.error("Error detection failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get analysis cost for specific session
    public func getSessionCost(_ sessionId: String) -> Double? {
        return sessionCosts[sessionId]
    }

    /// Get total costs for current session
    public func getTotalSessionCosts() -> Double {
        return sessionCosts.values.reduce(0, +)
    }

    /// Clear cost tracking data
    public func clearCostTracking() {
        sessionCosts.removeAll()
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // Monitor AI service progress if available
        aiAnalysisService.$analysisProgress
            .sink { [weak self] progress in
                if self?.isAnalyzing == true {
                    Task { @MainActor in
                        // Map AI progress to our overall progress (70-90% range)
                        let mappedProgress = 0.7 + (progress.percentComplete / 100.0 * 0.2)
                        self?.analysisProgress = mappedProgress
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func performRuleBasedDetection(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        sessionId: String
    ) async throws -> [DetectedError] {

        // Use enhanced AuditEngine for comprehensive rule-based detection
        let auditResults = await auditEngine.performCompleteAudit(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails
        )

        // Convert audit results to DetectedError format
        return auditResults.compactMap { auditResult in
            convertAuditResultToDetectedError(
                auditResult: auditResult,
                detectionTier: .ruleBased,
                sessionId: sessionId
            )
        }
    }

    private func performAIAnalysis(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        ruleBasedResults: [DetectedError],
        sessionId: String
    ) async throws -> [DetectedError] {

        // Prepare context for AI analysis focusing on complex patterns
        let analysisContext = createAIAnalysisContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            ruleBasedFindings: ruleBasedResults
        )

        // Use AI service for complex pattern detection
        let aiAnalysisResult = try await aiAnalysisService.analyzeComplexPatterns(
            context: analysisContext,
            focusAreas: determineFocusAreas(from: ruleBasedResults)
        )

        // Convert AI results to DetectedError format
        return aiAnalysisResult.compactMap { result in
            convertAIResultToDetectedError(
                aiResult: result,
                sessionId: sessionId
            )
        }
    }

    private func shouldTriggerAIAnalysis(
        ruleBasedResults: [DetectedError],
        extractedData: ExtractedData
    ) -> Bool {

        // Don't trigger AI if rule-based detection found high-confidence critical errors
        let highConfidenceCriticalErrors = ruleBasedResults.filter {
            $0.severity == .critical && $0.confidence > 0.8
        }

        if !highConfidenceCriticalErrors.isEmpty {
            logger.info("Skipping AI analysis - high confidence critical errors found by rules")
            return false
        }

        // Trigger AI if:
        // 1. Low overall confidence from rule-based detection
        let averageConfidence = ruleBasedResults.isEmpty ? 0 :
            ruleBasedResults.reduce(0) { $0 + $1.confidence } / Double(ruleBasedResults.count)

        // 2. Complex document patterns detected
        let hasComplexPatterns = extractedData.hasComplexPatterns

        // 3. Regulatory compliance concerns
        let hasComplianceConcerns = ruleBasedResults.contains {
            $0.category == .respaViolation || $0.category == .tilaViolation
        }

        // 4. Cost budget allows for AI analysis
        let estimatedAICost = costTracker.estimateAICost(for: extractedData)
        let budgetRemaining = configuration.costBudgetPerDocument -
            costTracker.calculateRuleBasedCost(analysisTime: 5.0, dataComplexity: extractedData.complexityScore)

        let shouldTrigger = (averageConfidence < configuration.aiAnalysisThreshold ||
                           hasComplexPatterns ||
                           hasComplianceConcerns) &&
                          estimatedAICost <= budgetRemaining

        logger.info("AI analysis trigger decision: \(shouldTrigger) (confidence: \(String(format: "%.2f", averageConfidence)), cost: $\(String(format: "%.4f", estimatedAICost)))")

        return shouldTrigger
    }

    private func combineResults(
        ruleBasedResults: [DetectedError],
        aiResults: [DetectedError]
    ) -> [DetectedError] {

        var combinedResults: [DetectedError] = []

        // Add all rule-based results
        combinedResults.append(contentsOf: ruleBasedResults)

        // Add AI results that don't duplicate rule-based findings
        for aiError in aiResults {
            let isDuplicate = ruleBasedResults.contains { ruleError in
                areSimilarErrors(aiError, ruleError)
            }

            if !isDuplicate {
                combinedResults.append(aiError)
            } else {
                // Enhance rule-based result with AI insights
                if let index = combinedResults.firstIndex(where: { areSimilarErrors($0, aiError) }) {
                    combinedResults[index] = enhanceErrorWithAIInsights(
                        ruleBasedError: combinedResults[index],
                        aiError: aiError
                    )
                }
            }
        }

        // Sort by severity and confidence
        return combinedResults.sorted { first, second in
            if first.severity.numericValue != second.severity.numericValue {
                return first.severity.numericValue > second.severity.numericValue
            }
            return first.confidence > second.confidence
        }
    }

    private func createAnalysisResult(
        errors: [DetectedError],
        ruleBasedTime: TimeInterval,
        aiAnalysisTime: TimeInterval?,
        ruleBasedCost: Double,
        aiCost: Double,
        totalTime: TimeInterval,
        ruleBasedErrorCount: Int,
        aiErrorCount: Int
    ) -> AnalysisResult {

        let totalCost = ruleBasedCost + aiCost
        let budgetUtilization = totalCost / configuration.costBudgetPerDocument

        let metrics = AnalysisResult.AnalysisMetrics(
            totalAnalysisTime: totalTime,
            ruleBasedAnalysisTime: ruleBasedTime,
            aiAnalysisTime: aiAnalysisTime,
            errorsDetectedByRules: ruleBasedErrorCount,
            errorsDetectedByAI: aiErrorCount,
            overallConfidence: calculateOverallConfidence(errors),
            coveragePercentage: calculateCoveragePercentage(errors)
        )

        let costBreakdown = AnalysisResult.CostBreakdown(
            ruleBasedCost: ruleBasedCost,
            aiAnalysisCost: aiCost,
            totalCost: totalCost,
            costPerError: errors.isEmpty ? nil : totalCost / Double(errors.count),
            budgetUtilization: budgetUtilization
        )

        let recommendedActions = generateRecommendedActions(from: errors)

        return AnalysisResult(
            detectedErrors: errors,
            analysisMetrics: metrics,
            costBreakdown: costBreakdown,
            recommendedActions: recommendedActions
        )
    }

    /// Perform zero-tolerance analysis using comprehensive validation
    private func performZeroToleranceAnalysis(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        documentId: String,
        sessionId: String,
        startTime: Date
    ) async throws -> AnalysisResult {

        guard let zeroToleranceEngine = zeroToleranceEngine else {
            throw ErrorDetectionError.zeroToleranceEngineNotAvailable
        }

        await updateProgress(0.1, step: "Initializing zero-tolerance validation")

        // Convert ExtractedData to ExtractedMortgageData format expected by zero-tolerance engine
        let extractedMortgageData = convertToMortgageData(extractedData)

        await updateProgress(0.2, step: "Performing triple redundancy validation")
        let zeroToleranceStartTime = Date()

        // Perform comprehensive zero-tolerance audit
        let zeroToleranceResult = try await zeroToleranceEngine.performZeroToleranceAudit(
            extractedData: extractedMortgageData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            documentId: documentId
        )

        let zeroToleranceTime = Date().timeIntervalSince(zeroToleranceStartTime)
        await updateProgress(0.8, step: "Zero-tolerance validation complete")

        // Convert zero-tolerance results to our format
        await updateProgress(0.9, step: "Converting results and generating recommendations")

        let detectedErrors = convertZeroToleranceResults(
            result: zeroToleranceResult,
            sessionId: sessionId
        )

        let totalTime = Date().timeIntervalSince(startTime)

        // Calculate cost for zero-tolerance analysis (higher due to comprehensive nature)
        let zeroToleranceCost = costTracker.calculateZeroToleranceCost(
            analysisTime: zeroToleranceTime,
            dataComplexity: extractedData.complexityScore,
            consensusModelsUsed: zeroToleranceResult.consensusResult?.modelsUsed.count ?? 1,
            humanReviewsTriggered: zeroToleranceResult.humanReviewsRequired.count
        )

        // Track costs
        sessionCosts[sessionId] = zeroToleranceCost

        let result = createZeroToleranceAnalysisResult(
            errors: detectedErrors,
            zeroToleranceTime: zeroToleranceTime,
            zeroToleranceCost: zeroToleranceCost,
            totalTime: totalTime,
            zeroToleranceResult: zeroToleranceResult
        )

        await updateProgress(1.0, step: "Zero-tolerance analysis complete")
        lastAnalysisResult = result

        logger.info("Zero-tolerance analysis complete: \(detectedErrors.count) errors found in \(String(format: "%.1f", totalTime))s for $\(String(format: "%.4f", zeroToleranceCost))")

        return result
    }

    /// Convert ExtractedData to ExtractedMortgageData format
    private func convertToMortgageData(_ extractedData: ExtractedData) -> ExtractedMortgageData {
        // Convert the generic ExtractedData to the specific mortgage format expected by zero-tolerance engine
        // This implementation would depend on the actual structure of ExtractedData
        // For now, we'll create a basic conversion

        return ExtractedMortgageData(
            accountNumber: extractedData.accountIdentifier ?? "UNKNOWN",
            balanceInformation: BalanceInformation(
                principalBalance: extractedData.balances?["principal"] ?? 0.0,
                interestBalance: extractedData.balances?["interest"] ?? 0.0,
                escrowBalance: extractedData.balances?["escrow"] ?? 0.0,
                feesBalance: extractedData.balances?["fees"] ?? 0.0,
                totalBalance: extractedData.balances?["total"] ?? 0.0
            ),
            paymentHistory: extractedData.payments?.map { payment in
                PaymentRecord(
                    date: payment.date,
                    amount: payment.amount,
                    principalPortion: payment.principalPortion ?? 0.0,
                    interestPortion: payment.interestPortion ?? 0.0,
                    escrowPortion: payment.escrowPortion ?? 0.0,
                    feesPortion: payment.feesPortion ?? 0.0,
                    transactionType: payment.type
                )
            } ?? [],
            transactionHistory: extractedData.transactions?.map { transaction in
                TransactionRecord(
                    date: transaction.date,
                    description: transaction.description,
                    amount: transaction.amount,
                    transactionType: transaction.type,
                    runningBalance: transaction.runningBalance ?? 0.0
                )
            } ?? [],
            loanTerms: LoanTerms(
                originalAmount: extractedData.loanInfo?["originalAmount"] as? Double ?? 0.0,
                interestRate: extractedData.loanInfo?["interestRate"] as? Double ?? 0.0,
                termInMonths: extractedData.loanInfo?["termInMonths"] as? Int ?? 360,
                paymentAmount: extractedData.loanInfo?["paymentAmount"] as? Double ?? 0.0
            ),
            escrowAnalysis: nil, // Would be populated if available in extractedData
            contactInformation: ContactInformation(
                servicerName: extractedData.servicerInfo?["name"] as? String ?? "Unknown Servicer",
                servicerAddress: extractedData.servicerInfo?["address"] as? String ?? "Unknown Address",
                customerServicePhone: extractedData.servicerInfo?["phone"] as? String ?? "Unknown Phone"
            ),
            statementDate: extractedData.documentDate ?? Date(),
            documentMetadata: DocumentMetadata(
                documentType: extractedData.documentType ?? "Mortgage Statement",
                pageCount: extractedData.pageCount ?? 1,
                confidence: extractedData.ocrConfidence ?? 0.85
            )
        )
    }

    /// Convert zero-tolerance results to our DetectedError format
    private func convertZeroToleranceResults(
        result: ZeroToleranceAuditEngine.TripleValidationResult,
        sessionId: String
    ) -> [DetectedError] {

        var detectedErrors: [DetectedError] = []

        // Convert all detected errors from the zero-tolerance result
        for error in result.allDetectedErrors {
            let convertedError = DetectedError(
                category: mapZeroToleranceCategory(error.category),
                severity: mapZeroToleranceSeverity(error.severity),
                detectionTier: .zeroTolerance,
                title: error.title,
                description: error.description,
                affectedFields: error.affectedFields,
                financialImpact: error.financialImpact,
                confidence: error.confidence,
                evidence: error.evidence.map { evidence in
                    DetectedError.Evidence(
                        type: mapEvidenceType(evidence.type),
                        description: evidence.description,
                        value: evidence.actualValue,
                        expectedValue: evidence.expectedValue,
                        calculation: evidence.calculationDetails
                    )
                },
                suggestedAction: error.recommendedAction,
                regulatoryReference: error.regulatoryReference,
                detectionTimestamp: Date(),
                detectionCost: 0.0 // Will be calculated at aggregate level
            )
            detectedErrors.append(convertedError)
        }

        return detectedErrors
    }

    /// Create analysis result for zero-tolerance analysis
    private func createZeroToleranceAnalysisResult(
        errors: [DetectedError],
        zeroToleranceTime: TimeInterval,
        zeroToleranceCost: Double,
        totalTime: TimeInterval,
        zeroToleranceResult: ZeroToleranceAuditEngine.TripleValidationResult
    ) -> AnalysisResult {

        let metrics = AnalysisResult.AnalysisMetrics(
            totalAnalysisTime: totalTime,
            ruleBasedAnalysisTime: zeroToleranceResult.ruleBasedResult?.processingTime ?? 0.0,
            aiAnalysisTime: zeroToleranceResult.consensusResult?.processingTime,
            errorsDetectedByRules: zeroToleranceResult.ruleBasedResult?.detectedErrors.count ?? 0,
            errorsDetectedByAI: zeroToleranceResult.consensusResult?.consensusFindings.count ?? 0,
            overallConfidence: zeroToleranceResult.overallConfidence,
            coveragePercentage: 100.0 // Zero-tolerance provides 100% coverage
        )

        let costBreakdown = AnalysisResult.CostBreakdown(
            ruleBasedCost: zeroToleranceCost * 0.1, // Estimated breakdown
            aiAnalysisCost: zeroToleranceCost * 0.9,
            totalCost: zeroToleranceCost,
            costPerError: errors.isEmpty ? nil : zeroToleranceCost / Double(errors.count),
            budgetUtilization: zeroToleranceCost / configuration.costBudgetPerDocument
        )

        let recommendedActions = generateZeroToleranceRecommendations(
            errors: errors,
            humanReviewsRequired: zeroToleranceResult.humanReviewsRequired
        )

        return AnalysisResult(
            detectedErrors: errors,
            analysisMetrics: metrics,
            costBreakdown: costBreakdown,
            recommendedActions: recommendedActions
        )
    }

    /// Map zero-tolerance error categories to our categories
    private func mapZeroToleranceCategory(_ category: MortgageViolationCategory) -> ErrorCategory {
        switch category {
        case .paymentMisallocation: return .paymentAllocation
        case .interestRateApplicationError: return .interestRateApplication
        case .escrowAccountDiscrepancy: return .escrowCalculation
        case .unauthorizedCharges: return .unauthorizedFees
        case .lateFeeMiscalculation: return .lateFeeMiscalculation
        case .principalMisapplication: return .principalCalculation
        case .respaSection6Violation, .respaSection8Violation, .respaSection10Violation: return .respaViolation
        case .tilaDisclosureViolation: return .tilaViolation
        case .duplicatePaymentProcessing: return .duplicateFees
        case .dataIntegrityViolation: return .inconsistentData
        case .auditTrailTampering: return .auditTrailMissing
        case .systemCalculationError: return .systemCalculationError
        // Add more mappings as needed
        default: return .calculationMismatch // Fallback
        }
    }

    /// Map zero-tolerance error severity to our severity
    private func mapZeroToleranceSeverity(_ severity: ZeroToleranceAuditEngine.ValidationResult.ErrorSeverity) -> ErrorSeverity {
        switch severity {
        case .critical: return .critical
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .informational: return .informational
        }
    }

    /// Map evidence types
    private func mapEvidenceType(_ type: ZeroToleranceAuditEngine.ValidationResult.EvidenceType) -> DetectedError.Evidence.EvidenceType {
        switch type {
        case .calculation: return .calculation
        case .crossReference: return .crossReference
        case .regulatoryViolation: return .regulation
        case .dataInconsistency: return .comparison
        case .patternAnalysis: return .pattern
        }
    }

    /// Generate recommendations for zero-tolerance results
    private func generateZeroToleranceRecommendations(
        errors: [DetectedError],
        humanReviewsRequired: [ZeroToleranceAuditEngine.HumanReviewRequest]
    ) -> [AnalysisResult.RecommendedAction] {

        var recommendations: [AnalysisResult.RecommendedAction] = []

        // Critical errors require immediate action
        let criticalErrors = errors.filter { $0.severity == .critical }
        if !criticalErrors.isEmpty {
            recommendations.append(AnalysisResult.RecommendedAction(
                priority: .immediate,
                action: "Address \(criticalErrors.count) critical mortgage servicing violations immediately to avoid regulatory penalties",
                estimatedTimeToComplete: 24 * 60 * 60, // 24 hours
                potentialSavings: criticalErrors.compactMap { $0.financialImpact }.reduce(0, +)
            ))
        }

        // Human reviews require urgent attention
        if !humanReviewsRequired.isEmpty {
            recommendations.append(AnalysisResult.RecommendedAction(
                priority: .urgent,
                action: "Complete \(humanReviewsRequired.count) required human reviews to verify complex violations",
                estimatedTimeToComplete: Double(humanReviewsRequired.count) * 30 * 60, // 30 minutes per review
                potentialSavings: nil
            ))
        }

        // High-value errors
        let highValueErrors = errors.filter { ($0.financialImpact ?? 0) > 1000 }
        if !highValueErrors.isEmpty {
            recommendations.append(AnalysisResult.RecommendedAction(
                priority: .urgent,
                action: "Investigate \(highValueErrors.count) high-value financial discrepancies totaling $\(String(format: "%.2f", highValueErrors.compactMap { $0.financialImpact }.reduce(0, +)))",
                estimatedTimeToComplete: Double(highValueErrors.count) * 45 * 60, // 45 minutes per high-value error
                potentialSavings: highValueErrors.compactMap { $0.financialImpact }.reduce(0, +)
            ))
        }

        return recommendations
    }

    // MARK: - Helper Methods

    @MainActor
    private func updateProgress(_ progress: Double, step: String) {
        analysisProgress = progress
        currentAnalysisStep = step
    }

    private func convertAuditResultToDetectedError(
        auditResult: AuditResult,
        detectionTier: DetectionTier,
        sessionId: String
    ) -> DetectedError? {
        // Implementation depends on AuditResult structure
        // This would be implemented based on the actual AuditResult model
        return nil // Placeholder
    }

    private func convertAIResultToDetectedError(
        aiResult: AIAnalysisResult,
        sessionId: String
    ) -> DetectedError? {
        // Implementation depends on AIAnalysisResult structure
        // This would be implemented based on the actual AI result model
        return nil // Placeholder
    }

    private func createAIAnalysisContext(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        ruleBasedFindings: [DetectedError]
    ) -> AIAnalysisContext {
        // Create context for AI analysis
        return AIAnalysisContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            existingFindings: ruleBasedFindings
        )
    }

    private func determineFocusAreas(from ruleBasedResults: [DetectedError]) -> [AIFocusArea] {
        // Determine what areas need AI attention based on rule-based findings
        return [.complexPatterns, .regulatoryCompliance] // Placeholder
    }

    private func areSimilarErrors(_ error1: DetectedError, _ error2: DetectedError) -> Bool {
        return error1.category == error2.category &&
               error1.affectedFields.contains { field in
                   error2.affectedFields.contains(field)
               }
    }

    private func enhanceErrorWithAIInsights(
        ruleBasedError: DetectedError,
        aiError: DetectedError
    ) -> DetectedError {
        // Combine insights from both detection methods
        return DetectedError(
            category: ruleBasedError.category,
            severity: max(ruleBasedError.severity, aiError.severity),
            detectionTier: .hybrid,
            title: ruleBasedError.title,
            description: "\(ruleBasedError.description)\n\nAI Analysis: \(aiError.description)",
            affectedFields: Array(Set(ruleBasedError.affectedFields + aiError.affectedFields)),
            financialImpact: max(ruleBasedError.financialImpact ?? 0, aiError.financialImpact ?? 0),
            confidence: (ruleBasedError.confidence + aiError.confidence) / 2,
            evidence: ruleBasedError.evidence + aiError.evidence,
            suggestedAction: ruleBasedError.suggestedAction,
            regulatoryReference: ruleBasedError.regulatoryReference ?? aiError.regulatoryReference,
            detectionTimestamp: ruleBasedError.detectionTimestamp,
            detectionCost: ruleBasedError.detectionCost + aiError.detectionCost
        )
    }

    private func calculateOverallConfidence(_ errors: [DetectedError]) -> Double {
        guard !errors.isEmpty else { return 0.0 }
        return errors.reduce(0) { $0 + $1.confidence } / Double(errors.count)
    }

    private func calculateCoveragePercentage(_ errors: [DetectedError]) -> Double {
        // Calculate based on how much of the document was analyzed
        // This would depend on the specific document structure
        return 0.85 // Placeholder - typically 85% coverage
    }

    private func generateRecommendedActions(from errors: [DetectedError]) -> [AnalysisResult.RecommendedAction] {
        var actions: [AnalysisResult.RecommendedAction] = []

        let criticalErrors = errors.filter { $0.severity == .critical }
        let highSeverityErrors = errors.filter { $0.severity == .high }

        if !criticalErrors.isEmpty {
            actions.append(AnalysisResult.RecommendedAction(
                priority: .immediate,
                action: "Address \(criticalErrors.count) critical error(s) immediately",
                estimatedTimeToComplete: 3600, // 1 hour
                potentialSavings: criticalErrors.compactMap { $0.financialImpact }.reduce(0, +)
            ))
        }

        if !highSeverityErrors.isEmpty {
            actions.append(AnalysisResult.RecommendedAction(
                priority: .urgent,
                action: "Review \(highSeverityErrors.count) high-severity error(s) within 24 hours",
                estimatedTimeToComplete: 1800, // 30 minutes
                potentialSavings: highSeverityErrors.compactMap { $0.financialImpact }.reduce(0, +)
            ))
        }

        return actions
    }
}

// MARK: - Supporting Types

/// Error detection specific errors
public enum ErrorDetectionError: LocalizedError {
    case analysisInProgress
    case configurationInvalid
    case budgetExceeded
    case timeoutExceeded
    case zeroToleranceEngineNotAvailable // NEW: Zero-tolerance engine not configured

    public var errorDescription: String? {
        switch self {
        case .analysisInProgress:
            return "Another analysis is currently in progress"
        case .configurationInvalid:
            return "Error detection configuration is invalid"
        case .budgetExceeded:
            return "Analysis cost would exceed budget limit"
        case .timeoutExceeded:
            return "Analysis timed out"
        case .zeroToleranceEngineNotAvailable:
            return "Zero-tolerance mode requested but engine not available"
        }
    }
}

/// Cost tracking for error detection operations
private class CostTracker {

    // Pricing model (example rates)
    private let ruleBasedCostPerSecond: Double = 0.001  // $0.001 per second
    private let aiCostPerInputToken: Double = 0.00003   // $0.03 per 1K tokens
    private let aiCostPerOutputToken: Double = 0.00015  // $0.15 per 1K tokens

    func calculateRuleBasedCost(analysisTime: TimeInterval, dataComplexity: Double) -> Double {
        let baseCost = analysisTime * ruleBasedCostPerSecond
        let complexityMultiplier = 1.0 + (dataComplexity * 0.5) // Up to 50% increase for complexity
        return baseCost * complexityMultiplier
    }

    func calculateAICost(analysisTime: TimeInterval, inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = Double(inputTokens) * aiCostPerInputToken
        let outputCost = Double(outputTokens) * aiCostPerOutputToken
        return inputCost + outputCost
    }

    func estimateAICost(for extractedData: ExtractedData) -> Double {
        let estimatedInputTokens = extractedData.estimatedTokenCount
        let estimatedOutputTokens = 200 // Conservative estimate
        return calculateAICost(
            analysisTime: 0, // Not time-based for AI
            inputTokens: estimatedInputTokens,
            outputTokens: estimatedOutputTokens
        )
    }

    func calculateZeroToleranceCost(
        analysisTime: TimeInterval,
        dataComplexity: Double,
        consensusModelsUsed: Int,
        humanReviewsTriggered: Int
    ) -> Double {
        // Base cost for rule-based analysis (faster but still comprehensive)
        let ruleBasedCost = analysisTime * ruleBasedCostPerSecond * 2.0 // 2x cost for comprehensive rules

        // AI consensus cost - multiple models increase cost significantly
        let consensusCostMultiplier = max(1.0, Double(consensusModelsUsed))
        let aiConsensusCost = (aiCostPerInputToken * 5000 + aiCostPerOutputToken * 1000) * consensusCostMultiplier

        // Human review cost - $0.50 per review triggered
        let humanReviewCost = Double(humanReviewsTriggered) * 0.50

        // OCR redundancy cost - multiple OCR passes
        let ocrRedundancyCost = 0.25 // Fixed cost for enhanced OCR

        // Legal compliance verification cost
        let legalComplianceCost = 0.15 // Fixed cost for compliance checks

        // Data complexity multiplier (1.0 to 2.0)
        let complexityMultiplier = 1.0 + dataComplexity

        let totalCost = (ruleBasedCost + aiConsensusCost + humanReviewCost + ocrRedundancyCost + legalComplianceCost) * complexityMultiplier

        return totalCost
    }
}

// MARK: - Extensions

extension ExtractedData {
    /// Calculate complexity score based on data richness and potential analysis needs
    var complexityScore: Double {
        var score: Double = 0.0

        // Base complexity from payment history
        score += Double(paymentHistory.count) * 0.01

        // Escrow complexity
        score += Double(escrowActivity.count) * 0.02

        // Fee complexity
        score += Double(fees.count) * 0.03

        // Missing data increases complexity
        if loanNumber == nil { score += 0.1 }
        if principalBalance == nil { score += 0.1 }
        if interestRate == nil { score += 0.1 }

        return min(score, 1.0) // Cap at 1.0
    }

    /// Detect if document has complex patterns that may need AI analysis
    var hasComplexPatterns: Bool {
        // Check for patterns that are difficult for rule-based detection
        let hasIrregularPayments = paymentHistory.contains { payment in
            // Detect irregular payment patterns
            guard let principal = payment.principalApplied,
                  let interest = payment.interestApplied else { return false }
            return abs(principal + interest - payment.amount) > 10.0 // Unusual allocation
        }

        let hasComplexEscrow = escrowActivity.count > 10 ||
                              escrowActivity.contains { $0.category == .other }

        let hasMultipleFeeTypes = Set(fees.map { $0.category }).count > 2

        return hasIrregularPayments || hasComplexEscrow || hasMultipleFeeTypes
    }

    /// Estimate token count for AI analysis cost calculation
    var estimatedTokenCount: Int {
        var tokenCount = 0

        // Base document metadata
        tokenCount += 100

        // Payment history (estimated 20 tokens per payment)
        tokenCount += paymentHistory.count * 20

        // Escrow activity (estimated 15 tokens per transaction)
        tokenCount += escrowActivity.count * 15

        // Fees (estimated 10 tokens per fee)
        tokenCount += fees.count * 10

        // Additional context
        tokenCount += 200

        return tokenCount
    }
}

extension MortgageErrorDetectionService.ErrorSeverity: Comparable {
    public static func < (lhs: MortgageErrorDetectionService.ErrorSeverity, rhs: MortgageErrorDetectionService.ErrorSeverity) -> Bool {
        return lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Placeholder Types (to be implemented based on actual AI service)

struct AIAnalysisContext {
    let extractedData: ExtractedData
    let bankTransactions: [Transaction]
    let loanDetails: LoanDetails?
    let existingFindings: [MortgageErrorDetectionService.DetectedError]
}

struct AIAnalysisResult {
    let findings: [String] // Placeholder
}

enum AIFocusArea {
    case complexPatterns
    case regulatoryCompliance
}

extension AIAnalysisService {
    func analyzeComplexPatterns(context: AIAnalysisContext, focusAreas: [AIFocusArea]) async throws -> [AIAnalysisResult] {
        // Placeholder implementation
        return []
    }
}