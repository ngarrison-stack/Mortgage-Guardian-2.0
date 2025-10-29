import Foundation
import Combine
import os.log

/// Multi-Model Consensus Service for Zero-Tolerance AI Validation
/// Orchestrates multiple AI models to achieve consensus and eliminate false negatives
@MainActor
public final class MultiModelConsensusService: ObservableObject {

    // MARK: - Types

    /// AI model configuration for consensus analysis
    public struct AIModelConfig {
        let modelId: String
        let modelType: AIModelType
        let endpoint: String
        let confidence: Double
        let strengths: [AnalysisStrength]
        let maxTokens: Int
        let timeoutSeconds: TimeInterval
        let costPerToken: Double
        let isActive: Bool

        public enum AIModelType: String, CaseIterable {
            case claude = "claude"
            case bedrockAgent = "bedrock_agent"
            case gpt4 = "gpt4"
            case custom = "custom"
            case gemini = "gemini"

            var description: String {
                switch self {
                case .claude: return "Anthropic Claude (Primary)"
                case .bedrockAgent: return "AWS Bedrock Agent (Mortgage Expert)"
                case .gpt4: return "OpenAI GPT-4 (Cross-validation)"
                case .custom: return "Custom Trained Model"
                case .gemini: return "Google Gemini (Pattern Detection)"
                }
            }
        }

        public enum AnalysisStrength: String, CaseIterable {
            case mathematicalCalculation = "mathematical_calculation"
            case patternRecognition = "pattern_recognition"
            case regulatoryCompliance = "regulatory_compliance"
            case contextualAnalysis = "contextual_analysis"
            case anomalyDetection = "anomaly_detection"
            case crossReferenceValidation = "cross_reference_validation"
        }
    }

    /// Consensus analysis result
    public struct ConsensusAnalysisResult {
        let participatingModels: [String]
        let consensusErrors: [ZeroToleranceAuditEngine.ZeroToleranceError]
        let conflictingFindings: [ConflictingFinding]
        let overallConfidence: Double
        let consensusStrength: Double
        let recommendationsConsensus: [String]
        let modelPerformanceMetrics: [ModelPerformanceMetric]
        let analysisTimestamp: Date
        let totalProcessingTime: TimeInterval

        /// Errors that achieved consensus across models (high confidence)
        var highConfidenceErrors: [ZeroToleranceAuditEngine.ZeroToleranceError] {
            return consensusErrors.filter { $0.confidence >= 0.9 }
        }

        /// Errors that need additional review (low consensus)
        var lowConsensusErrors: [ZeroToleranceAuditEngine.ZeroToleranceError] {
            return consensusErrors.filter { $0.confidence < 0.7 }
        }
    }

    /// Conflicting findings between models
    public struct ConflictingFinding {
        let category: ZeroToleranceAuditEngine.MortgageViolationCategory
        let modelAgreement: [String: Bool] // modelId -> agrees
        let confidenceSpread: Double
        let requiresArbitration: Bool
        let resolutionStrategy: ResolutionStrategy

        public enum ResolutionStrategy: String {
            case useHighestConfidence = "highest_confidence"
            case requireHumanReview = "human_review"
            case runAdditionalModel = "additional_model"
            case acceptMajorityVote = "majority_vote"
        }
    }

    /// Model performance tracking
    public struct ModelPerformanceMetric {
        let modelId: String
        let responseTime: TimeInterval
        let tokensUsed: Int
        let cost: Double
        let errorCount: Int
        let confidence: Double
        let accuracy: Double? // If known ground truth
        let reliability: Double
    }

    /// Consensus configuration
    public struct ConsensusConfiguration {
        let minimumModelCount: Int
        let consensusThreshold: Double // Percentage of models that must agree
        let confidenceThreshold: Double
        let maxProcessingTime: TimeInterval
        let enableConflictResolution: Bool
        let fallbackToSingleModel: Bool
        let costBudgetPerDocument: Double

        public static let strict = ConsensusConfiguration(
            minimumModelCount: 3,
            consensusThreshold: 0.67, // 67% agreement required
            confidenceThreshold: 0.9,
            maxProcessingTime: 180.0, // 3 minutes
            enableConflictResolution: true,
            fallbackToSingleModel: false,
            costBudgetPerDocument: 2.0 // $2.00 budget
        )

        public static let balanced = ConsensusConfiguration(
            minimumModelCount: 2,
            consensusThreshold: 0.6, // 60% agreement required
            confidenceThreshold: 0.8,
            maxProcessingTime: 120.0, // 2 minutes
            enableConflictResolution: true,
            fallbackToSingleModel: true,
            costBudgetPerDocument: 1.0 // $1.00 budget
        )
    }

    // MARK: - Properties

    @Published public var isAnalyzing = false
    @Published public var analysisProgress: Double = 0.0
    @Published public var currentModel: String = ""
    @Published public var lastConsensusResult: ConsensusAnalysisResult?

    public static let shared = MultiModelConsensusService()

    private let configuration: ConsensusConfiguration
    private let aiModels: [AIModelConfig]
    private let logger = Logger(subsystem: "MortgageGuardian", category: "MultiModelConsensus")

    // Service dependencies
    private let claudeService: ClaudeAnalysisService
    private let bedrockService: BedrockAgentService
    private let customModelService: CustomModelService
    private let conflictResolver: ConflictResolutionEngine

    private var cancellables = Set<AnyCancellable>()
    private var modelPerformanceHistory: [String: [ModelPerformanceMetric]] = [:]

    // MARK: - Initialization

    public init(
        configuration: ConsensusConfiguration = .strict,
        claudeService: ClaudeAnalysisService = ClaudeAnalysisService.shared,
        bedrockService: BedrockAgentService = BedrockAgentService.shared,
        customModelService: CustomModelService = CustomModelService.shared
    ) {
        self.configuration = configuration
        self.claudeService = claudeService
        self.bedrockService = bedrockService
        self.customModelService = customModelService
        self.conflictResolver = ConflictResolutionEngine(configuration: configuration)

        // Configure AI models for consensus analysis
        self.aiModels = [
            // Primary Claude model for mortgage analysis
            AIModelConfig(
                modelId: "claude-3-sonnet",
                modelType: .claude,
                endpoint: "https://api.anthropic.com/v1/messages",
                confidence: 0.95,
                strengths: [.mathematicalCalculation, .regulatoryCompliance, .contextualAnalysis],
                maxTokens: 8192,
                timeoutSeconds: 60.0,
                costPerToken: 0.00003,
                isActive: true
            ),

            // Bedrock Agent with mortgage expertise
            AIModelConfig(
                modelId: "bedrock-mortgage-agent",
                modelType: .bedrockAgent,
                endpoint: "arn:aws:bedrock:us-east-1:123456789012:agent/ABCD1234",
                confidence: 0.92,
                strengths: [.regulatoryCompliance, .patternRecognition, .crossReferenceValidation],
                maxTokens: 4096,
                timeoutSeconds: 45.0,
                costPerToken: 0.00002,
                isActive: true
            ),

            // GPT-4 for cross-validation
            AIModelConfig(
                modelId: "gpt-4-turbo",
                modelType: .gpt4,
                endpoint: "https://api.openai.com/v1/chat/completions",
                confidence: 0.88,
                strengths: [.patternRecognition, .anomalyDetection, .contextualAnalysis],
                maxTokens: 8192,
                timeoutSeconds: 50.0,
                costPerToken: 0.00001,
                isActive: false // Disabled by default to control costs
            ),

            // Custom trained model for specific mortgage patterns
            AIModelConfig(
                modelId: "custom-mortgage-detector",
                modelType: .custom,
                endpoint: "https://custom-model.company.com/v1/analyze",
                confidence: 0.85,
                strengths: [.anomalyDetection, .mathematicalCalculation],
                maxTokens: 2048,
                timeoutSeconds: 30.0,
                costPerToken: 0.000005,
                isActive: true
            )
        ]

        setupModelPerformanceTracking()
    }

    // MARK: - Public Methods

    /// Perform consensus analysis across multiple AI models
    public func performConsensusAnalysis(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError] = []
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        guard !isAnalyzing else {
            throw ConsensusError.analysisInProgress
        }

        await updateProgress(0.0, model: "")
        isAnalyzing = true

        let startTime = Date()
        var modelResults: [String: [ZeroToleranceAuditEngine.ZeroToleranceError]] = [:]
        var performanceMetrics: [ModelPerformanceMetric] = []

        defer {
            Task { @MainActor in
                isAnalyzing = false
                analysisProgress = 0.0
                currentModel = ""
            }
        }

        do {
            let activeModels = aiModels.filter { $0.isActive }

            guard activeModels.count >= configuration.minimumModelCount else {
                throw ConsensusError.insufficientModels
            }

            logger.info("Starting consensus analysis with \(activeModels.count) AI models")

            // Analyze with each model in parallel
            let progressIncrement = 0.8 / Double(activeModels.count)
            var currentProgress = 0.1

            await withTaskGroup(of: Void.self) { group in
                for model in activeModels {
                    group.addTask {
                        do {
                            await self.updateProgress(currentProgress, model: model.modelId)

                            let modelStartTime = Date()
                            let errors = try await self.analyzeWithModel(
                                model: model,
                                extractedData: extractedData,
                                bankTransactions: bankTransactions,
                                loanDetails: loanDetails,
                                existingFindings: existingFindings
                            )

                            let processingTime = Date().timeIntervalSince(modelStartTime)

                            await MainActor.run {
                                modelResults[model.modelId] = errors
                                performanceMetrics.append(ModelPerformanceMetric(
                                    modelId: model.modelId,
                                    responseTime: processingTime,
                                    tokensUsed: self.estimateTokensUsed(extractedData: extractedData, errors: errors),
                                    cost: self.calculateModelCost(model: model, extractedData: extractedData, errors: errors),
                                    errorCount: errors.count,
                                    confidence: errors.isEmpty ? 0.0 : errors.reduce(0) { $0 + $1.confidence } / Double(errors.count),
                                    accuracy: nil,
                                    reliability: model.confidence
                                ))
                                currentProgress += progressIncrement
                            }

                        } catch {
                            self.logger.error("Model \(model.modelId) failed: \(error.localizedDescription)")
                        }
                    }
                }
            }

            await updateProgress(0.9, model: "consensus-analysis")

            // Analyze consensus and resolve conflicts
            let consensusResult = try analyzeConsensus(
                modelResults: modelResults,
                performanceMetrics: performanceMetrics,
                totalProcessingTime: Date().timeIntervalSince(startTime)
            )

            await updateProgress(1.0, model: "")
            lastConsensusResult = consensusResult

            // Update performance history
            updatePerformanceHistory(performanceMetrics)

            logger.info("Consensus analysis completed: \(consensusResult.consensusErrors.count) consensus errors found")

            return consensusResult.consensusErrors

        } catch {
            logger.error("Consensus analysis failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get the number of active AI models
    public func getActiveModelCount() -> Int {
        return aiModels.filter { $0.isActive }.count
    }

    /// Get model performance history for optimization
    public func getModelPerformanceHistory() -> [String: [ModelPerformanceMetric]] {
        return modelPerformanceHistory
    }

    /// Enable/disable specific AI models
    public func configureModel(_ modelId: String, isActive: Bool) {
        // This would update model configuration
        logger.info("Model \(modelId) \(isActive ? "enabled" : "disabled")")
    }

    // MARK: - Private Methods

    private func setupModelPerformanceTracking() {
        // Initialize performance tracking for each model
        for model in aiModels {
            modelPerformanceHistory[model.modelId] = []
        }
    }

    private func analyzeWithModel(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        switch model.modelType {
        case .claude:
            return try await analyzeWithClaude(
                model: model,
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                existingFindings: existingFindings
            )

        case .bedrockAgent:
            return try await analyzeWithBedrockAgent(
                model: model,
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                existingFindings: existingFindings
            )

        case .gpt4:
            return try await analyzeWithGPT4(
                model: model,
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                existingFindings: existingFindings
            )

        case .custom:
            return try await analyzeWithCustomModel(
                model: model,
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                existingFindings: existingFindings
            )

        case .gemini:
            return try await analyzeWithGemini(
                model: model,
                extractedData: extractedData,
                bankTransactions: bankTransactions,
                loanDetails: loanDetails,
                existingFindings: existingFindings
            )
        }
    }

    private func analyzeWithClaude(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        // Prepare context specifically for Claude analysis
        let analysisContext = createMortgageAnalysisContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            existingFindings: existingFindings,
            modelStrengths: model.strengths
        )

        // Use Claude service for analysis
        let claudeResults = try await claudeService.performZeroToleranceAnalysis(
            context: analysisContext,
            focusAreas: model.strengths
        )

        // Convert Claude results to ZeroToleranceError format
        return convertClaudeResults(claudeResults, modelId: model.modelId)
    }

    private func analyzeWithBedrockAgent(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        // Use specialized Bedrock Agent with mortgage expertise
        let bedrockResults = try await bedrockService.analyzeMortgageViolations(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            existingFindings: existingFindings
        )

        return convertBedrockResults(bedrockResults, modelId: model.modelId)
    }

    private func analyzeWithGPT4(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        // GPT-4 analysis for cross-validation
        // This would integrate with OpenAI API
        logger.info("GPT-4 analysis not implemented - placeholder")
        return []
    }

    private func analyzeWithCustomModel(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        // Custom model analysis for specific patterns
        let customResults = try await customModelService.analyzeForAnomalies(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            focusAreas: model.strengths
        )

        return convertCustomResults(customResults, modelId: model.modelId)
    }

    private func analyzeWithGemini(
        model: AIModelConfig,
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        // Google Gemini analysis for pattern detection
        // This would integrate with Google AI API
        logger.info("Gemini analysis not implemented - placeholder")
        return []
    }

    private func analyzeConsensus(
        modelResults: [String: [ZeroToleranceAuditEngine.ZeroToleranceError]],
        performanceMetrics: [ModelPerformanceMetric],
        totalProcessingTime: TimeInterval
    ) throws -> ConsensusAnalysisResult {

        // Group errors by category and compare across models
        var categoryConsensus: [ZeroToleranceAuditEngine.MortgageViolationCategory: [String: ZeroToleranceAuditEngine.ZeroToleranceError]] = [:]

        for (modelId, errors) in modelResults {
            for error in errors {
                if categoryConsensus[error.category] == nil {
                    categoryConsensus[error.category] = [:]
                }
                categoryConsensus[error.category]![modelId] = error
            }
        }

        var consensusErrors: [ZeroToleranceAuditEngine.ZeroToleranceError] = []
        var conflictingFindings: [ConflictingFinding] = []

        // Analyze consensus for each error category
        for (category, modelFindings) in categoryConsensus {
            let agreementCount = modelFindings.count
            let totalModels = modelResults.count
            let agreementRatio = Double(agreementCount) / Double(totalModels)

            if agreementRatio >= configuration.consensusThreshold {
                // Consensus achieved - create consolidated error
                let consolidatedError = consolidateErrors(
                    category: category,
                    modelFindings: Array(modelFindings.values)
                )
                consensusErrors.append(consolidatedError)

            } else if agreementCount > 1 {
                // Partial agreement - flag as conflicting finding
                let conflictingFinding = ConflictingFinding(
                    category: category,
                    modelAgreement: modelResults.mapValues { results in
                        results.contains { $0.category == category }
                    },
                    confidenceSpread: calculateConfidenceSpread(modelFindings: Array(modelFindings.values)),
                    requiresArbitration: agreementRatio < 0.5,
                    resolutionStrategy: determineResolutionStrategy(agreementRatio: agreementRatio)
                )
                conflictingFindings.append(conflictingFinding)

                // Include error with lower confidence due to conflict
                if let highestConfidenceError = modelFindings.values.max(by: { $0.confidence < $1.confidence }) {
                    var conflictError = highestConfidenceError
                    // Reduce confidence due to lack of consensus
                    let adjustedConfidence = highestConfidenceError.confidence * agreementRatio
                    // Would need to create new error with adjusted confidence
                    consensusErrors.append(conflictError)
                }
            }
        }

        // Calculate overall metrics
        let overallConfidence = calculateOverallConfidence(consensusErrors)
        let consensusStrength = calculateConsensusStrength(
            consensusErrors: consensusErrors.count,
            conflictingFindings: conflictingFindings.count,
            totalCategories: categoryConsensus.count
        )

        return ConsensusAnalysisResult(
            participatingModels: Array(modelResults.keys),
            consensusErrors: consensusErrors,
            conflictingFindings: conflictingFindings,
            overallConfidence: overallConfidence,
            consensusStrength: consensusStrength,
            recommendationsConsensus: generateConsensusRecommendations(consensusErrors),
            modelPerformanceMetrics: performanceMetrics,
            analysisTimestamp: Date(),
            totalProcessingTime: totalProcessingTime
        )
    }

    // MARK: - Utility Methods

    @MainActor
    private func updateProgress(_ progress: Double, model: String) {
        analysisProgress = progress
        currentModel = model
    }

    private func createMortgageAnalysisContext(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        modelStrengths: [AIModelConfig.AnalysisStrength]
    ) -> MortgageAnalysisContext {

        return MortgageAnalysisContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            existingFindings: existingFindings,
            focusAreas: modelStrengths,
            analysisDepth: .comprehensive,
            requireZeroTolerance: true
        )
    }

    private func convertClaudeResults(
        _ results: [ClaudeAnalysisResult],
        modelId: String
    ) -> [ZeroToleranceAuditEngine.ZeroToleranceError] {
        // Convert Claude-specific results to ZeroToleranceError format
        return results.compactMap { result in
            convertToZeroToleranceError(result, modelId: modelId)
        }
    }

    private func convertBedrockResults(
        _ results: [BedrockAnalysisResult],
        modelId: String
    ) -> [ZeroToleranceAuditEngine.ZeroToleranceError] {
        // Convert Bedrock-specific results to ZeroToleranceError format
        return results.compactMap { result in
            convertToZeroToleranceError(result, modelId: modelId)
        }
    }

    private func convertCustomResults(
        _ results: [CustomAnalysisResult],
        modelId: String
    ) -> [ZeroToleranceAuditEngine.ZeroToleranceError] {
        // Convert custom model results to ZeroToleranceError format
        return results.compactMap { result in
            convertToZeroToleranceError(result, modelId: modelId)
        }
    }

    private func convertToZeroToleranceError(
        _ result: Any,
        modelId: String
    ) -> ZeroToleranceAuditEngine.ZeroToleranceError? {
        // Generic conversion method - would be specialized for each result type
        // This is a placeholder implementation
        return nil
    }

    private func consolidateErrors(
        category: ZeroToleranceAuditEngine.MortgageViolationCategory,
        modelFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> ZeroToleranceAuditEngine.ZeroToleranceError {

        // Take the highest confidence error as base and enhance with consensus data
        let baseError = modelFindings.max { $0.confidence < $1.confidence } ?? modelFindings[0]

        // Combine evidence from all models
        let combinedEvidence = modelFindings.flatMap { $0.detailedEvidence }

        // Calculate consensus confidence
        let averageConfidence = modelFindings.reduce(0) { $0 + $1.confidence } / Double(modelFindings.count)
        let consensusBonus = Double(modelFindings.count) * 0.05 // 5% bonus per agreeing model
        let finalConfidence = min(averageConfidence + consensusBonus, 1.0)

        // Create new error with consensus data
        return ZeroToleranceAuditEngine.ZeroToleranceError(
            category: category,
            severity: modelFindings.map { $0.severity }.max() ?? baseError.severity,
            detectionLayers: [.aiConsensus],
            title: baseError.title,
            description: "\(baseError.description)\n\nConsensus from \(modelFindings.count) AI models",
            detailedEvidence: combinedEvidence,
            financialImpact: modelFindings.compactMap { $0.financialImpact }.max { $0.estimatedDamage < $1.estimatedDamage } ?? baseError.financialImpact,
            legalCompliance: baseError.legalCompliance,
            confidence: finalConfidence,
            recommendedActions: baseError.recommendedActions,
            auditTrail: baseError.auditTrail,
            detectionTimestamp: Date(),
            validationHash: createConsensusHash(modelFindings)
        )
    }

    private func calculateConfidenceSpread(_ modelFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]) -> Double {
        guard modelFindings.count > 1 else { return 0.0 }

        let confidences = modelFindings.map { $0.confidence }
        let maxConfidence = confidences.max() ?? 0.0
        let minConfidence = confidences.min() ?? 0.0

        return maxConfidence - minConfidence
    }

    private func determineResolutionStrategy(agreementRatio: Double) -> ConflictingFinding.ResolutionStrategy {
        if agreementRatio >= 0.5 {
            return .acceptMajorityVote
        } else if agreementRatio >= 0.33 {
            return .useHighestConfidence
        } else {
            return .requireHumanReview
        }
    }

    private func calculateOverallConfidence(_ errors: [ZeroToleranceAuditEngine.ZeroToleranceError]) -> Double {
        guard !errors.isEmpty else { return 1.0 }
        return errors.reduce(0) { $0 + $1.confidence } / Double(errors.count)
    }

    private func calculateConsensusStrength(
        consensusErrors: Int,
        conflictingFindings: Int,
        totalCategories: Int
    ) -> Double {
        guard totalCategories > 0 else { return 1.0 }
        return Double(consensusErrors) / Double(totalCategories)
    }

    private func generateConsensusRecommendations(_ errors: [ZeroToleranceAuditEngine.ZeroToleranceError]) -> [String] {
        var recommendations: [String] = []

        let criticalErrors = errors.filter { $0.severity == .critical }
        let highErrors = errors.filter { $0.severity == .high }

        if !criticalErrors.isEmpty {
            recommendations.append("IMMEDIATE ACTION REQUIRED: \(criticalErrors.count) critical violations detected")
        }

        if !highErrors.isEmpty {
            recommendations.append("Priority review needed for \(highErrors.count) high-severity issues")
        }

        return recommendations
    }

    private func createConsensusHash(_ errors: [ZeroToleranceAuditEngine.ZeroToleranceError]) -> String {
        let combinedIds = errors.map { $0.id.uuidString }.sorted().joined()
        return String(combinedIds.hashValue)
    }

    private func estimateTokensUsed(extractedData: ExtractedData, errors: [ZeroToleranceAuditEngine.ZeroToleranceError]) -> Int {
        // Estimate tokens used for cost calculation
        return extractedData.estimatedTokenCount + (errors.count * 50)
    }

    private func calculateModelCost(
        model: AIModelConfig,
        extractedData: ExtractedData,
        errors: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> Double {
        let tokensUsed = estimateTokensUsed(extractedData: extractedData, errors: errors)
        return Double(tokensUsed) * model.costPerToken
    }

    private func updatePerformanceHistory(_ metrics: [ModelPerformanceMetric]) {
        for metric in metrics {
            modelPerformanceHistory[metric.modelId]?.append(metric)

            // Keep only last 100 entries per model
            if let history = modelPerformanceHistory[metric.modelId], history.count > 100 {
                modelPerformanceHistory[metric.modelId] = Array(history.suffix(100))
            }
        }
    }
}

// MARK: - Supporting Types

/// Analysis context for AI models
public struct MortgageAnalysisContext {
    let extractedData: ExtractedData
    let bankTransactions: [Transaction]
    let loanDetails: LoanDetails?
    let existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    let focusAreas: [MultiModelConsensusService.AIModelConfig.AnalysisStrength]
    let analysisDepth: AnalysisDepth
    let requireZeroTolerance: Bool

    public enum AnalysisDepth: String {
        case surface = "surface"
        case standard = "standard"
        case comprehensive = "comprehensive"
        case exhaustive = "exhaustive"
    }
}

/// Conflict resolution engine for handling disagreements between models
private class ConflictResolutionEngine {
    private let configuration: MultiModelConsensusService.ConsensusConfiguration

    init(configuration: MultiModelConsensusService.ConsensusConfiguration) {
        self.configuration = configuration
    }

    func resolveConflict(_ finding: MultiModelConsensusService.ConflictingFinding) -> ZeroToleranceAuditEngine.ZeroToleranceError? {
        // Implement conflict resolution logic
        return nil
    }
}

// MARK: - Errors

public enum ConsensusError: LocalizedError {
    case analysisInProgress
    case insufficientModels
    case consensusNotAchieved
    case modelFailure(String)
    case budgetExceeded

    public var errorDescription: String? {
        switch self {
        case .analysisInProgress:
            return "Consensus analysis is already in progress"
        case .insufficientModels:
            return "Insufficient AI models available for consensus analysis"
        case .consensusNotAchieved:
            return "Unable to achieve consensus across AI models"
        case .modelFailure(let modelId):
            return "AI model \(modelId) failed during analysis"
        case .budgetExceeded:
            return "Analysis cost would exceed budget limit"
        }
    }
}

// MARK: - Placeholder Services (to be implemented)

class ClaudeAnalysisService {
    static let shared = ClaudeAnalysisService()

    func performZeroToleranceAnalysis(
        context: MortgageAnalysisContext,
        focusAreas: [MultiModelConsensusService.AIModelConfig.AnalysisStrength]
    ) async throws -> [ClaudeAnalysisResult] {
        // Implement Claude-specific analysis
        return []
    }
}

class BedrockAgentService {
    static let shared = BedrockAgentService()

    func analyzeMortgageViolations(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        existingFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [BedrockAnalysisResult] {
        // Implement Bedrock Agent analysis
        return []
    }
}

class CustomModelService {
    static let shared = CustomModelService()

    func analyzeForAnomalies(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        focusAreas: [MultiModelConsensusService.AIModelConfig.AnalysisStrength]
    ) async throws -> [CustomAnalysisResult] {
        // Implement custom model analysis
        return []
    }
}

// Placeholder result types
struct ClaudeAnalysisResult {}
struct BedrockAnalysisResult {}
struct CustomAnalysisResult {}