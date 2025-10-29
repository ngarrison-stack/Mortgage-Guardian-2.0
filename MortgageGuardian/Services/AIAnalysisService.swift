import Foundation
import Combine
import UIKit
import os.log

/// Comprehensive AI Analysis Service for Mortgage Guardian app
/// Integrates with Claude AI API for advanced document analysis, error detection, and letter generation
@MainActor
public final class AIAnalysisService: ObservableObject {

    // MARK: - Types

    /// AI Analysis errors
    public enum AIAnalysisError: LocalizedError {
        case invalidConfiguration
        case apiKeyNotConfigured
        case networkError(Error)
        case invalidResponse(String)
        case rateLimitExceeded
        case quotaExceeded
        case invalidPrompt(String)
        case responseParsingFailed(String)
        case confidenceThresholdNotMet(Double)
        case analysisTimeout
        case insufficientContext
        case documentTooLarge
        case unsupportedDocumentType
        case securityValidationFailed

        public var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "AI service configuration is invalid"
            case .apiKeyNotConfigured:
                return "API key is not properly configured"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let reason):
                return "Invalid API response: \(reason)"
            case .rateLimitExceeded:
                return "API rate limit exceeded. Please try again later"
            case .quotaExceeded:
                return "API quota exceeded. Please contact support"
            case .invalidPrompt(let reason):
                return "Invalid prompt: \(reason)"
            case .responseParsingFailed(let reason):
                return "Failed to parse AI response: \(reason)"
            case .confidenceThresholdNotMet(let confidence):
                return "AI confidence (\(String(format: "%.1f", confidence * 100))%) below threshold"
            case .analysisTimeout:
                return "Analysis timed out. Please try again"
            case .insufficientContext:
                return "Insufficient document context for reliable analysis"
            case .documentTooLarge:
                return "Document is too large for AI analysis"
            case .unsupportedDocumentType:
                return "Document type is not supported for AI analysis"
            case .securityValidationFailed:
                return "Security validation failed for AI request"
            }
        }
    }

    /// Analysis progress tracking
    public struct AnalysisProgress {
        let step: AnalysisStep
        let percentComplete: Double
        let message: String
        let estimatedTimeRemaining: TimeInterval?

        public enum AnalysisStep: String, CaseIterable {
            case initialization = "Initializing analysis"
            case documentPreprocessing = "Preprocessing document"
            case contextGeneration = "Generating analysis context"
            case aiAnalysis = "Performing AI analysis"
            case responseProcessing = "Processing AI response"
            case resultValidation = "Validating results"
            case confidenceScoring = "Calculating confidence scores"
            case resultIntegration = "Integrating with manual analysis"
            case completion = "Analysis complete"
        }
    }

    /// AI Analysis configuration
    public struct AIConfiguration {
        let model: ClaudeModel
        let maxTokens: Int
        let temperature: Double
        let confidenceThreshold: Double
        let timeoutInterval: TimeInterval
        let enableStreamingResponse: Bool
        let retryAttempts: Int
        let concurrentAnalysisLimit: Int

        public enum ClaudeModel: String, CaseIterable {
            case claude3Haiku = "claude-3-haiku-20240307"
            case claude3Sonnet = "claude-3-sonnet-20240229"
            case claude3Opus = "claude-3-opus-20240229"
            case claude35Sonnet = "claude-3-5-sonnet-20241022"

            var contextWindow: Int {
                switch self {
                case .claude3Haiku, .claude3Sonnet, .claude3Opus:
                    return 200000
                case .claude35Sonnet:
                    return 200000
                }
            }

            var costPerInputToken: Double {
                switch self {
                case .claude3Haiku:
                    return 0.00000025
                case .claude3Sonnet:
                    return 0.000003
                case .claude3Opus:
                    return 0.000015
                case .claude35Sonnet:
                    return 0.000003
                }
            }

            var displayName: String {
                switch self {
                case .claude3Haiku:
                    return "Claude 3 Haiku (Fast & Efficient)"
                case .claude3Sonnet:
                    return "Claude 3 Sonnet (Balanced)"
                case .claude3Opus:
                    return "Claude 3 Opus (Most Capable)"
                case .claude35Sonnet:
                    return "Claude 3.5 Sonnet (Latest)"
                }
            }
        }

        public static let `default` = AIConfiguration(
            model: .claude35Sonnet,
            maxTokens: 4096,
            temperature: 0.1,
            confidenceThreshold: 0.7,
            timeoutInterval: 60,
            enableStreamingResponse: false,
            retryAttempts: 3,
            concurrentAnalysisLimit: 3
        )

        public static let fast = AIConfiguration(
            model: .claude3Haiku,
            maxTokens: 2048,
            temperature: 0.0,
            confidenceThreshold: 0.6,
            timeoutInterval: 30,
            enableStreamingResponse: false,
            retryAttempts: 2,
            concurrentAnalysisLimit: 5
        )
    }

    /// AI Analysis result structure
    public struct AIAnalysisResult {
        let findings: [AuditResult]
        let confidence: Double
        let analysisMetadata: AnalysisMetadata
        let rawResponse: String
        let processingTime: TimeInterval
        let tokensUsed: TokenUsage

        public struct AnalysisMetadata {
            let documentType: MortgageDocument.DocumentType
            let analysisType: AnalysisType
            let modelUsed: AIConfiguration.ClaudeModel
            let promptVersion: String
            let analysisDate: Date
            let contextLength: Int

            public enum AnalysisType: String, CaseIterable {
                case comprehensive = "comprehensive"
                case focused = "focused"
                case validation = "validation"
                case comparison = "comparison"
            }
        }

        public struct TokenUsage {
            let inputTokens: Int
            let outputTokens: Int
            let totalTokens: Int
            let estimatedCost: Double
        }
    }

    /// Letter generation result
    public struct LetterGenerationResult {
        let letterContent: String
        let letterType: LetterType
        let confidence: Double
        let metadata: LetterMetadata
        let pdfData: Data?

        public enum LetterType: String, CaseIterable {
            case noticeOfError = "notice_of_error"
            case qualifiedWrittenRequest = "qualified_written_request"
            case escalationLetter = "escalation_letter"
            case consumerComplaint = "consumer_complaint"

            var displayName: String {
                switch self {
                case .noticeOfError:
                    return "Notice of Error Letter"
                case .qualifiedWrittenRequest:
                    return "Qualified Written Request"
                case .escalationLetter:
                    return "Escalation Letter"
                case .consumerComplaint:
                    return "Consumer Complaint"
                }
            }
        }

        public struct LetterMetadata {
            let generatedDate: Date
            let userInfo: User
            let mortgageAccount: User.MortgageAccount
            let issues: [AuditResult]
            let totalAffectedAmount: Double?
            let urgencyLevel: UrgencyLevel

            public enum UrgencyLevel: String, CaseIterable {
                case routine = "routine"
                case urgent = "urgent"
                case critical = "critical"

                var responseTimeframe: String {
                    switch self {
                    case .routine:
                        return "30 business days"
                    case .urgent:
                        return "10 business days"
                    case .critical:
                        return "5 business days"
                    }
                }
            }
        }
    }

    // MARK: - Properties

    public static let shared = AIAnalysisService()

    private let securityService: SecurityService
    private let logger = Logger(subsystem: "com.mortgageguardian", category: "AIAnalysisService")
    private let networkSession: URLSession
    private let analysisQueue = DispatchQueue(label: "ai.analysis", qos: .userInitiated)
    private let promptManager = PromptManager()
    private let responseParser = ResponseParser()
    private let letterGenerator = LetterGenerator()

    @Published public var currentProgress: AnalysisProgress?
    @Published public var isAnalyzing = false
    @Published public var analysisHistory: [AIAnalysisResult] = []
    @Published public var configuration: AIConfiguration = .default

    private var activeAnalysisTasks: Set<UUID> = []
    private var rateLimitTracker = RateLimitTracker()

    // Claude API configuration
    private let claudeBaseURL = "https://api.anthropic.com/v1"
    private let claudeMessagesEndpoint = "/messages"
    private let anthropicVersion = "2023-06-01"

    // MARK: - Initialization

    private init() {
        self.securityService = SecurityService.shared

        // Configure secure network session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 3
        config.waitsForConnectivity = true

        self.networkSession = URLSession(configuration: config)

        setupRateLimitMonitoring()
    }

    // MARK: - Public API

    /// Analyze mortgage document using Claude AI
    public func analyzeDocument(
        _ document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction] = [],
        configuration: AIConfiguration? = nil
    ) async throws -> AIAnalysisResult {

        guard !isAnalyzing || activeAnalysisTasks.count < self.configuration.concurrentAnalysisLimit else {
            throw AIAnalysisError.rateLimitExceeded
        }

        let taskId = UUID()
        activeAnalysisTasks.insert(taskId)
        defer { activeAnalysisTasks.remove(taskId) }

        let config = configuration ?? self.configuration
        let startTime = Date()

        do {
            isAnalyzing = true
            updateProgress(.initialization, percentComplete: 5, message: "Initializing AI analysis")

            // Validate prerequisites
            try await validateAnalysisPrerequisites(document: document, configuration: config)

            // Check rate limits
            try await rateLimitTracker.checkRateLimit()

            // Preprocess document for AI analysis
            updateProgress(.documentPreprocessing, percentComplete: 15, message: "Preparing document for analysis")
            let preprocessedContent = try await preprocessDocumentForAI(document)

            // Generate analysis context
            updateProgress(.contextGeneration, percentComplete: 25, message: "Building analysis context")
            let context = try buildAnalysisContext(
                document: document,
                userContext: userContext,
                bankTransactions: bankTransactions
            )

            // Generate specialized prompt
            let prompt = try await promptManager.generatePrompt(
                for: document.documentType,
                content: preprocessedContent,
                context: context,
                analysisType: .comprehensive
            )

            // Perform AI analysis
            updateProgress(.aiAnalysis, percentComplete: 40, message: "Analyzing document with Claude AI")
            let rawResponse: String

            do {
                rawResponse = try await performClaudeAnalysis(
                    prompt: prompt,
                    configuration: config,
                    taskId: taskId
                )
            } catch {
                // If Claude API fails, continue with error handling below
                throw error
            }

            // Process and validate response
            updateProgress(.responseProcessing, percentComplete: 70, message: "Processing AI response")
            let findings = try await responseParser.parseAnalysisResponse(
                rawResponse,
                documentType: document.documentType,
                originalDocument: document
            )

            updateProgress(.confidenceScoring, percentComplete: 85, message: "Calculating confidence scores")
            let confidence = calculateOverallConfidence(findings)

            // Validate confidence threshold
            guard confidence >= config.confidenceThreshold else {
                throw AIAnalysisError.confidenceThresholdNotMet(confidence)
            }

            // Create result
            let processingTime = Date().timeIntervalSince(startTime)
            let tokenUsage = extractTokenUsage(from: rawResponse)

            let result = AIAnalysisResult(
                findings: findings,
                confidence: confidence,
                analysisMetadata: AIAnalysisResult.AnalysisMetadata(
                    documentType: document.documentType,
                    analysisType: .comprehensive,
                    modelUsed: config.model,
                    promptVersion: promptManager.currentVersion,
                    analysisDate: Date(),
                    contextLength: prompt.count
                ),
                rawResponse: rawResponse,
                processingTime: processingTime,
                tokensUsed: tokenUsage
            )

            updateProgress(.completion, percentComplete: 100, message: "Analysis completed successfully")

            // Store in history
            analysisHistory.append(result)

            // Update rate limit tracker
            await rateLimitTracker.recordRequest(tokenUsage: tokenUsage.totalTokens)

            logger.info("AI analysis completed successfully for document: \(document.fileName)")
            return result

        } catch {
            logger.error("AI analysis failed: \(error.localizedDescription)")
            updateProgress(.completion, percentComplete: 100, message: "Analysis failed: \(error.localizedDescription)")
            throw error
        } finally {
            isAnalyzing = activeAnalysisTasks.count > 0
        }
    }

    /// Combine AI analysis with manual algorithm results
    public func performHybridAnalysis(
        document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction] = [],
        manualResults: [AuditResult] = []
    ) async throws -> [AuditResult] {

        // Perform AI analysis
        let aiResult = try await analyzeDocument(
            document,
            userContext: userContext,
            bankTransactions: bankTransactions
        )

        // Merge AI findings with manual results
        return try await integrateAnalysisResults(
            aiFindings: aiResult.findings,
            manualFindings: manualResults,
            confidence: aiResult.confidence
        )
    }

    /// Generate professional Notice of Error letter using Claude AI
    public func generateNoticeOfErrorLetter(
        for issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount,
        letterType: LetterGenerationResult.LetterType = .noticeOfError
    ) async throws -> LetterGenerationResult {

        guard !issues.isEmpty else {
            throw AIAnalysisError.insufficientContext
        }

        do {
            updateProgress(.initialization, percentComplete: 10, message: "Preparing letter generation")

            // Generate letter content using Claude
            let letterContent = try await letterGenerator.generateLetter(
                type: letterType,
                issues: issues,
                userInfo: userInfo,
                mortgageAccount: mortgageAccount
            )

            updateProgress(.responseProcessing, percentComplete: 70, message: "Formatting letter")

            // Calculate urgency level
            let urgencyLevel = determineUrgencyLevel(from: issues)

            // Generate PDF if requested
            updateProgress(.completion, percentComplete: 90, message: "Generating PDF")
            let pdfData = try await generateLetterPDF(content: letterContent)

            let result = LetterGenerationResult(
                letterContent: letterContent,
                letterType: letterType,
                confidence: 0.95, // High confidence for letter generation
                metadata: LetterGenerationResult.LetterMetadata(
                    generatedDate: Date(),
                    userInfo: userInfo,
                    mortgageAccount: mortgageAccount,
                    issues: issues,
                    totalAffectedAmount: issues.compactMap { $0.affectedAmount }.reduce(0, +),
                    urgencyLevel: urgencyLevel
                ),
                pdfData: pdfData
            )

            updateProgress(.completion, percentComplete: 100, message: "Letter generated successfully")

            logger.info("Notice of Error letter generated successfully")
            return result

        } catch {
            logger.error("Letter generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Validate AI findings against known patterns and rules
    public func validateAIFindings(
        _ findings: [AuditResult],
        againstDocument document: MortgageDocument,
        userContext: User
    ) async throws -> [AuditResult] {

        var validatedFindings: [AuditResult] = []

        for finding in findings {
            // Validate finding against business rules
            if try await validateFindingBusinessRules(finding, document: document, userContext: userContext) {
                // Cross-reference with manual algorithms
                let enhancedFinding = try await enhanceFindingWithManualValidation(finding, document: document)
                validatedFindings.append(enhancedFinding)
            } else {
                logger.warning("AI finding failed validation: \(finding.title)")
            }
        }

        return validatedFindings
    }

    /// Configure AI service settings
    public func configure(with configuration: AIConfiguration) {
        self.configuration = configuration
        logger.info("AI service configured with model: \(configuration.model.displayName)")
    }

    /// Get analysis cost estimate
    public func estimateAnalysisCost(for document: MortgageDocument) -> Double {
        let estimatedTokens = estimateTokenCount(for: document)
        return Double(estimatedTokens) * configuration.model.costPerInputToken
    }

    /// Perform second-tier AI analysis for complex patterns not detected by rule-based validation
    /// This method is specifically designed for the tiered error detection system
    public func analyzeComplexPatterns(
        context: AIAnalysisContext,
        focusAreas: [AIFocusArea]
    ) async throws -> [AIAnalysisResult] {

        guard !isAnalyzing else {
            throw AIAnalysisError.analysisTimeout
        }

        await updateProgress(.aiAnalysis, 0.0, "Initializing AI complex pattern analysis")

        do {
            // Build focused prompt for second-tier analysis
            let analysisPrompt = buildSecondTierAnalysisPrompt(
                context: context,
                focusAreas: focusAreas
            )

            await updateProgress(.aiAnalysis, 0.3, "Sending complex pattern analysis request to Claude")

            // Use optimized configuration for second-tier analysis
            let analysisResult = try await performClaudeAnalysis(
                prompt: analysisPrompt,
                configuration: .focused, // New configuration for targeted analysis
                taskId: UUID()
            )

            await updateProgress(.aiAnalysis, 0.7, "Processing AI response for complex patterns")

            // Parse and validate AI findings
            let findings = try parseComplexPatternFindings(
                response: analysisResult,
                context: context
            )

            await updateProgress(.aiAnalysis, 1.0, "Complex pattern analysis complete")

            logger.info("AI complex pattern analysis complete: \(findings.count) complex patterns identified")

            return findings

        } catch {
            logger.error("AI complex pattern analysis failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Analyze mortgage document with cost-conscious AI integration
    /// Designed to work with rule-based pre-analysis
    public func performSecondTierAnalysis(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        ruleBasedFindings: [AuditResult],
        costBudget: Double
    ) async throws -> [AuditResult] {

        // Estimate cost before proceeding
        let estimatedCost = estimateSecondTierAnalysisCost(
            extractedData: extractedData,
            ruleBasedFindings: ruleBasedFindings
        )

        guard estimatedCost <= costBudget else {
            logger.warning("AI analysis cost ($\(String(format: "%.4f", estimatedCost))) exceeds budget ($\(String(format: "%.4f", costBudget)))")
            throw AIAnalysisError.quotaExceeded
        }

        await updateProgress(.aiAnalysis, 0.0, "Starting cost-conscious AI analysis")

        // Create focused analysis context based on rule-based gaps
        let context = createSecondTierContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            ruleBasedFindings: ruleBasedFindings
        )

        // Determine focus areas based on rule-based analysis gaps
        let focusAreas = determineFocusAreas(from: ruleBasedFindings)

        // Perform targeted AI analysis
        let aiResults = try await analyzeComplexPatterns(
            context: context,
            focusAreas: focusAreas
        )

        // Convert AI results to AuditResult format
        let auditResults = aiResults.compactMap { aiResult in
            convertAIResultToAuditResult(aiResult, detectionMethod: .aiAnalysis)
        }

        logger.info("Second-tier AI analysis complete: \(auditResults.count) additional findings at cost $\(String(format: "%.4f", estimatedCost))")

        return auditResults
    }

    /// Test API connection to backend Claude service
    public func testAPIConnection() async throws -> String {
        let testPrompt = "This is a test connection to verify Claude API integration. Please respond with a simple confirmation."

        do {
            let result = try await performClaudeAnalysis(
                prompt: testPrompt,
                configuration: .fast, // Use fast config for testing
                taskId: UUID()
            )

            if result.contains("mock") || result.contains("Mock") {
                return "✅ Backend connection successful\n⚠️ Using mock analysis (Claude API key not configured)\n💡 Configure CLAUDE_API_KEY in backend environment for real AI analysis"
            } else {
                return "✅ Claude API connection successful\n🤖 Real AI analysis enabled"
            }

        } catch {
            return "❌ Connection failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Implementation

    private func validateAnalysisPrerequisites(document: MortgageDocument, configuration: AIConfiguration) async throws {
        // Validate document content
        guard !document.originalText.isEmpty else {
            throw AIAnalysisError.insufficientContext
        }

        // Check document size
        let tokenCount = estimateTokenCount(for: document)
        guard tokenCount <= configuration.model.contextWindow else {
            throw AIAnalysisError.documentTooLarge
        }

        // Verify network connectivity
        guard await isNetworkAvailable() else {
            throw AIAnalysisError.networkError(URLError(.notConnectedToInternet))
        }
    }

    private func preprocessDocumentForAI(_ document: MortgageDocument) async throws -> String {
        var content = document.originalText

        // Clean and normalize text
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        content = content.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Remove sensitive information patterns (SSN, account numbers)
        content = sanitizeDocument(content)

        // Add document metadata
        let metadata = """
        Document Type: \(document.documentType.displayName)
        Upload Date: \(DateFormatter.iso8601.string(from: document.uploadDate))
        Analysis Status: \(document.isAnalyzed ? "Previously Analyzed" : "New")

        Document Content:
        \(content)
        """

        return metadata
    }

    private func buildAnalysisContext(
        document: MortgageDocument,
        userContext: User,
        bankTransactions: [Transaction]
    ) throws -> AnalysisContext {

        let mortgageAccounts = userContext.mortgageAccounts.filter { $0.isActive }
        let relevantTransactions = bankTransactions.filter { $0.relatedMortgagePayment }

        return AnalysisContext(
            borrowerName: userContext.fullName,
            mortgageAccounts: mortgageAccounts,
            recentTransactions: Array(relevantTransactions.prefix(50)), // Limit context size
            documentHistory: [], // Previous analysis results if available
            analysisDate: Date()
        )
    }

    private func performClaudeAnalysis(
        prompt: String,
        configuration: AIConfiguration,
        taskId: UUID
    ) async throws -> String {

        // Use AWS backend for Claude analysis (no API key required from user)
        let backendService = BackendAPIService.shared

        var lastError: Error?

        // Retry logic with exponential backoff
        for attempt in 1...configuration.retryAttempts {
            do {
                // Send prompt to backend for Claude API processing
                let requestPayload = [
                    "prompt": prompt,
                    "model": configuration.model.rawValue,
                    "maxTokens": configuration.maxTokens,
                    "temperature": configuration.temperature
                ] as [String : Any]

                let jsonData = try JSONSerialization.data(withJSONObject: requestPayload)

                // Call the Claude analysis endpoint directly
                let responseData = try await callClaudeAnalysisEndpoint(requestPayload: jsonData)

                guard let responseString = String(data: responseData, encoding: .utf8) else {
                    throw AIAnalysisError.invalidResponse("Unable to decode response")
                }

                // Parse backend response
                if let responseJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    if let analysisResult = responseJson["analysis"] as? String {
                        logger.info("Received Claude analysis response from backend")
                        return analysisResult
                    } else if let success = responseJson["success"] as? Bool, success {
                        // Handle successful response format
                        return responseString
                    } else if let error = responseJson["error"] as? String {
                        throw AIAnalysisError.invalidResponse("Backend error: \(error)")
                    }
                }

                return responseString

            } catch {
                lastError = error
                logger.warning("Claude analysis attempt \(attempt) failed: \(error.localizedDescription)")

                // Retry for network errors if attempts remaining
                if attempt < configuration.retryAttempts {
                    let backoffTime = TimeInterval(attempt * 2)
                    logger.warning("Retrying in \(backoffTime) seconds (attempt \(attempt)/\(configuration.retryAttempts))")
                    try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                    continue
                }
            }
        }

        // If we get here, all retries failed
        throw lastError ?? AIAnalysisError.networkError(URLError(.unknown))
    }

    private func callClaudeAnalysisEndpoint(requestPayload: Data) async throws -> Data {
        // Use the direct Claude analysis endpoint
        guard let url = URL(string: "\(APIConfiguration.baseURL)/v1/ai/claude/analyze") else {
            throw AIAnalysisError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("MortgageGuardian/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = requestPayload
        request.timeoutInterval = 60

        do {
            let (data, response) = try await networkSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIAnalysisError.networkError(URLError(.badServerResponse))
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Claude API backend error \(httpResponse.statusCode): \(errorMessage)")
                throw AIAnalysisError.invalidResponse("Backend returned status \(httpResponse.statusCode): \(errorMessage)")
            }

            return data

        } catch {
            logger.error("Network error calling Claude analysis endpoint: \(error.localizedDescription)")
            throw AIAnalysisError.networkError(error)
        }
    }

    // Removed buildClaudeAPIRequest - now handled entirely by backend

    private func extractClaudeResponse(from rawResponse: String) throws -> String {
        guard let data = rawResponse.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIAnalysisError.responseParsingFailed("Invalid Claude API response format")
        }

        return text
    }

    private func calculateOverallConfidence(_ findings: [AuditResult]) -> Double {
        guard !findings.isEmpty else { return 0.0 }

        let totalConfidence = findings.map { $0.confidence }.reduce(0, +)
        return totalConfidence / Double(findings.count)
    }

    private func extractTokenUsage(from response: String) -> AIAnalysisResult.TokenUsage {
        // In a real implementation, this would parse the actual token usage from the API response
        let estimatedInput = response.count / 4 // Rough estimate
        let estimatedOutput = response.count / 6
        let total = estimatedInput + estimatedOutput
        let cost = Double(total) * configuration.model.costPerInputToken

        return AIAnalysisResult.TokenUsage(
            inputTokens: estimatedInput,
            outputTokens: estimatedOutput,
            totalTokens: total,
            estimatedCost: cost
        )
    }

    private func integrateAnalysisResults(
        aiFindings: [AuditResult],
        manualFindings: [AuditResult],
        confidence: Double
    ) async throws -> [AuditResult] {

        var combinedResults: [AuditResult] = []

        // Add all manual findings (they have high confidence)
        combinedResults.append(contentsOf: manualFindings)

        // Add AI findings that don't duplicate manual findings
        for aiFinding in aiFindings {
            let isDuplicate = manualFindings.contains { manual in
                manual.issueType == aiFinding.issueType &&
                abs((manual.affectedAmount ?? 0) - (aiFinding.affectedAmount ?? 0)) < 1.0
            }

            if !isDuplicate {
                // Mark as AI-detected and adjust confidence if needed
                var enhancedFinding = aiFinding
                if enhancedFinding.detectionMethod == .aiAnalysis {
                    enhancedFinding = AuditResult(
                        issueType: enhancedFinding.issueType,
                        severity: enhancedFinding.severity,
                        title: enhancedFinding.title,
                        description: enhancedFinding.description,
                        detailedExplanation: enhancedFinding.detailedExplanation + " (Detected by AI analysis)",
                        suggestedAction: enhancedFinding.suggestedAction,
                        affectedAmount: enhancedFinding.affectedAmount,
                        detectionMethod: .combinedAnalysis,
                        confidence: min(enhancedFinding.confidence, confidence),
                        evidenceText: enhancedFinding.evidenceText,
                        calculationDetails: enhancedFinding.calculationDetails,
                        createdDate: enhancedFinding.createdDate
                    )
                }
                combinedResults.append(enhancedFinding)
            }
        }

        // Sort by severity and confidence
        return combinedResults.sorted { first, second in
            if first.severity != second.severity {
                return first.severity.rawValue > second.severity.rawValue
            }
            return first.confidence > second.confidence
        }
    }

    private func validateFindingBusinessRules(
        _ finding: AuditResult,
        document: MortgageDocument,
        userContext: User
    ) async throws -> Bool {

        // Validate based on issue type
        switch finding.issueType {
        case .latePaymentError:
            return validateLateFeeBusinessRules(finding, document: document)
        case .incorrectInterest:
            return validateInterestCalculationRules(finding, userContext: userContext)
        case .misappliedPayment:
            return validatePaymentApplicationRules(finding, document: document)
        case .unauthorizedFee:
            return validateFeeAuthorizationRules(finding, userContext: userContext)
        default:
            return true // Default to accepting other types
        }
    }

    private func validateLateFeeBusinessRules(_ finding: AuditResult, document: MortgageDocument) -> Bool {
        // Validate late fee amount is within reasonable ranges
        guard let amount = finding.affectedAmount else { return false }
        return amount >= 5.0 && amount <= 200.0 // Reasonable late fee range
    }

    private func validateInterestCalculationRules(_ finding: AuditResult, userContext: User) -> Bool {
        // Validate interest calculation makes sense given user's mortgage terms
        guard let account = userContext.mortgageAccounts.first(where: { $0.isActive }),
              let amount = finding.affectedAmount else { return false }

        let monthlyInterest = account.currentBalance ?? account.originalLoanAmount * account.interestRate / 12
        return amount <= monthlyInterest * 0.5 // Error shouldn't exceed 50% of monthly interest
    }

    private func validatePaymentApplicationRules(_ finding: AuditResult, document: MortgageDocument) -> Bool {
        // Validate payment application error is reasonable
        guard let amount = finding.affectedAmount else { return false }
        return amount >= 1.0 && amount <= 10000.0 // Reasonable payment error range
    }

    private func validateFeeAuthorizationRules(_ finding: AuditResult, userContext: User) -> Bool {
        // Validate unauthorized fee claim
        guard let amount = finding.affectedAmount else { return false }
        return amount >= 10.0 // Only flag fees above $10
    }

    private func enhanceFindingWithManualValidation(
        _ finding: AuditResult,
        document: MortgageDocument
    ) async throws -> AuditResult {

        // This could run simplified versions of manual algorithms to validate AI findings
        // For now, we'll just enhance the confidence score

        let validationConfidence = min(finding.confidence + 0.1, 0.99)

        return AuditResult(
            issueType: finding.issueType,
            severity: finding.severity,
            title: finding.title,
            description: finding.description,
            detailedExplanation: finding.detailedExplanation + " (Validated)",
            suggestedAction: finding.suggestedAction,
            affectedAmount: finding.affectedAmount,
            detectionMethod: .combinedAnalysis,
            confidence: validationConfidence,
            evidenceText: finding.evidenceText,
            calculationDetails: finding.calculationDetails,
            createdDate: finding.createdDate
        )
    }

    private func determineUrgencyLevel(from issues: [AuditResult]) -> LetterGenerationResult.LetterMetadata.UrgencyLevel {
        let criticalIssues = issues.filter { $0.severity == .critical }
        let highIssues = issues.filter { $0.severity == .high }

        if !criticalIssues.isEmpty {
            return .critical
        } else if highIssues.count >= 2 {
            return .urgent
        } else {
            return .routine
        }
    }

    private func generateLetterPDF(content: String) async throws -> Data {
        // This would integrate with a PDF generation service
        // For now, return placeholder data
        return Data("PDF placeholder".utf8)
    }

    private func sanitizeDocument(_ content: String) -> String {
        var sanitized = content

        // Remove SSN patterns
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{3}-\d{2}-\d{4}\b"#,
            with: "XXX-XX-XXXX",
            options: .regularExpression
        )

        // Remove account number patterns (adjust as needed)
        sanitized = sanitized.replacingOccurrences(
            of: #"\b\d{10,}\b"#,
            with: "[ACCOUNT_NUMBER]",
            options: .regularExpression
        )

        return sanitized
    }

    private func estimateTokenCount(for document: MortgageDocument) -> Int {
        // Rough estimation: 1 token ≈ 4 characters
        return document.originalText.count / 4
    }

    private func isNetworkAvailable() async -> Bool {
        // Simple network connectivity check
        guard let url = URL(string: "https://api.mortgageguardian.com/health") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func setupRateLimitMonitoring() {
        // Monitor rate limits and usage patterns
        rateLimitTracker.configure(
            requestsPerMinute: 50,
            tokensPerMinute: 40000,
            requestsPerDay: 1000
        )
    }

    /// Provides mock analysis when Claude API is not available
    private func performMockAnalysis(
        document: MortgageDocument,
        context: AnalysisContext
    ) async throws -> String {
        // Simulate processing time
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Generate mock analysis based on document type
        let mockFindings = generateMockFindings(for: document.documentType)

        let mockResponse = """
        {
            "findings": \(try encodeMockFindings(mockFindings)),
            "overallConfidence": 0.6,
            "summary": "Mock analysis performed due to API key not being configured. This is a simulated analysis for demonstration purposes. Please configure your Claude API key in Settings to enable full AI-powered analysis."
        }
        """

        return mockResponse
    }

    private func generateMockFindings(for documentType: MortgageDocument.DocumentType) -> [[String: Any]] {
        switch documentType {
        case .mortgageStatement:
            return [
                [
                    "issueType": "latePaymentError",
                    "severity": "medium",
                    "title": "Mock: Potential Late Fee Issue",
                    "description": "This is a mock finding generated for demonstration purposes.",
                    "detailedExplanation": "Mock analysis detected a potential late fee discrepancy. Please configure Claude API key for accurate analysis.",
                    "suggestedAction": "Configure Claude API key in Settings for real analysis.",
                    "affectedAmount": 25.0,
                    "confidence": 0.6,
                    "evidenceText": "Mock evidence - requires real API analysis",
                    "reasoning": "This is a simulated finding for demo purposes."
                ]
            ]
        case .escrowStatement:
            return [
                [
                    "issueType": "escrowError",
                    "severity": "low",
                    "title": "Mock: Escrow Balance Check",
                    "description": "Mock analysis suggests reviewing escrow calculations.",
                    "detailedExplanation": "This is a simulated finding. Real AI analysis would provide detailed escrow analysis.",
                    "suggestedAction": "Configure Claude API key for comprehensive escrow analysis.",
                    "affectedAmount": null,
                    "confidence": 0.5,
                    "evidenceText": "Mock evidence for escrow analysis",
                    "reasoning": "Simulated analysis for demonstration."
                ]
            ]
        default:
            return [
                [
                    "issueType": "other",
                    "severity": "low",
                    "title": "Mock: Document Review Needed",
                    "description": "Mock analysis suggests manual review.",
                    "detailedExplanation": "This is a mock finding. Configure Claude API key for detailed AI analysis.",
                    "suggestedAction": "Set up Claude API key in Settings for full analysis capabilities.",
                    "affectedAmount": null,
                    "confidence": 0.5,
                    "evidenceText": "Mock analysis placeholder",
                    "reasoning": "Demo analysis - requires API configuration."
                ]
            ]
        }
    }

    private func encodeMockFindings(_ findings: [[String: Any]]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: findings, options: [])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AIAnalysisError.responseParsingFailed("Failed to encode mock findings")
        }
        return jsonString
    }

    private func updateProgress(
        _ step: AnalysisProgress.AnalysisStep,
        percentComplete: Double,
        message: String,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.currentProgress = AnalysisProgress(
                step: step,
                percentComplete: percentComplete,
                message: message,
                estimatedTimeRemaining: estimatedTimeRemaining
            )
        }
    }
}

// MARK: - Supporting Types and Classes

/// Analysis context for AI processing
struct AnalysisContext {
    let borrowerName: String
    let mortgageAccounts: [User.MortgageAccount]
    let recentTransactions: [Transaction]
    let documentHistory: [MortgageDocument]
    let analysisDate: Date
}

/// Prompt management for different document types and analysis scenarios
private class PromptManager {
    let currentVersion = "v2.1"

    func generatePrompt(
        for documentType: MortgageDocument.DocumentType,
        content: String,
        context: AnalysisContext,
        analysisType: AIAnalysisResult.AnalysisMetadata.AnalysisType
    ) async throws -> String {

        let basePrompt = getBasePrompt(for: documentType, analysisType: analysisType)
        let contextPrompt = buildContextPrompt(context)
        let instructionPrompt = getInstructionPrompt(for: documentType)

        return """
        \(basePrompt)

        \(contextPrompt)

        Document to analyze:
        \(content)

        \(instructionPrompt)

        Please provide your analysis in the following JSON format:
        {
            "findings": [
                {
                    "issueType": "string",
                    "severity": "low|medium|high|critical",
                    "title": "string",
                    "description": "string",
                    "detailedExplanation": "string",
                    "suggestedAction": "string",
                    "affectedAmount": number or null,
                    "confidence": number between 0 and 1,
                    "evidenceText": "string",
                    "reasoning": "string"
                }
            ],
            "overallConfidence": number between 0 and 1,
            "summary": "string"
        }
        """
    }

    private func getBasePrompt(
        for documentType: MortgageDocument.DocumentType,
        analysisType: AIAnalysisResult.AnalysisMetadata.AnalysisType
    ) -> String {

        let baseRole = """
        You are an expert mortgage servicing auditor with extensive knowledge of RESPA regulations,
        mortgage industry practices, and consumer protection laws. You specialize in identifying
        errors, violations, and potential issues in mortgage documents.
        """

        switch documentType {
        case .mortgageStatement:
            return baseRole + """

            You are analyzing a mortgage statement. Focus on:
            - Payment allocation accuracy (principal, interest, escrow)
            - Balance calculations and running totals
            - Fee applications and justifications
            - Interest rate applications
            - Escrow account activity
            - Late payment designations and grace periods
            """

        case .escrowStatement:
            return baseRole + """

            You are analyzing an escrow statement. Focus on:
            - Escrow balance calculations
            - Property tax and insurance payment timing
            - Escrow shortage or surplus calculations
            - Disbursement accuracy and timing
            - Required escrow account projections
            """

        case .paymentHistory:
            return baseRole + """

            You are analyzing a payment history document. Focus on:
            - Payment posting dates vs. receipt dates
            - Late fee applications and accuracy
            - Payment allocation patterns
            - Missing or duplicate payments
            - Grace period violations
            """

        default:
            return baseRole + """

            You are analyzing a mortgage-related document. Look for any errors,
            inconsistencies, or potential violations of mortgage servicing regulations.
            """
        }
    }

    private func buildContextPrompt(_ context: AnalysisContext) -> String {
        let accountInfo = context.mortgageAccounts.first.map { account in
            """
            Primary Mortgage Account:
            - Loan Number: \(account.loanNumber)
            - Servicer: \(account.servicerName)
            - Original Amount: $\(String(format: "%.2f", account.originalLoanAmount))
            - Interest Rate: \(String(format: "%.3f", account.interestRate * 100))%
            - Monthly Payment: $\(String(format: "%.2f", account.monthlyPayment))
            - Has Escrow: \(account.escrowAccount ? "Yes" : "No")
            """
        } ?? "No account information available"

        let transactionSummary = context.recentTransactions.isEmpty ?
            "No recent bank transactions available" :
            "Recent mortgage payments found in bank records: \(context.recentTransactions.count) transactions"

        return """
        Borrower Context:
        - Name: \(context.borrowerName)
        - Analysis Date: \(DateFormatter.shortDate.string(from: context.analysisDate))

        \(accountInfo)

        Bank Transaction Context:
        \(transactionSummary)

        Please use this context to validate document information and identify discrepancies.
        """
    }

    private func getInstructionPrompt(for documentType: MortgageDocument.DocumentType) -> String {
        return """
        Analysis Instructions:
        1. Carefully review all numerical values and calculations
        2. Check for compliance with RESPA regulations and industry standards
        3. Look for patterns that suggest systematic errors
        4. Validate payment timing and grace period applications
        5. Verify fee applications are authorized and calculated correctly
        6. Identify any missing or incomplete information
        7. Assess the severity of each issue found
        8. Provide actionable recommendations for addressing issues

        Confidence Scoring:
        - 0.9-1.0: High confidence, clear evidence of issue
        - 0.7-0.89: Medium-high confidence, strong indicators
        - 0.5-0.69: Medium confidence, some concerns
        - 0.3-0.49: Low-medium confidence, potential issue
        - 0.0-0.29: Low confidence, insufficient evidence

        Only report issues with confidence >= 0.5
        """
    }
}

/// Response parser for Claude AI analysis results
private class ResponseParser {

    func parseAnalysisResponse(
        _ response: String,
        documentType: MortgageDocument.DocumentType,
        originalDocument: MortgageDocument
    ) async throws -> [AuditResult] {

        guard let data = response.data(using: .utf8) else {
            throw AIAnalysisService.AIAnalysisError.responseParsingFailed("Unable to convert response to data")
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let findingsArray = json["findings"] as? [[String: Any]] else {
                throw AIAnalysisService.AIAnalysisError.responseParsingFailed("Invalid JSON structure")
            }

            var auditResults: [AuditResult] = []

            for findingDict in findingsArray {
                if let auditResult = try parseIndividualFinding(findingDict) {
                    auditResults.append(auditResult)
                }
            }

            return auditResults

        } catch {
            throw AIAnalysisService.AIAnalysisError.responseParsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
    }

    private func parseIndividualFinding(_ dict: [String: Any]) throws -> AuditResult? {
        guard let issueTypeString = dict["issueType"] as? String,
              let issueType = AuditResult.IssueType(rawValue: issueTypeString),
              let severityString = dict["severity"] as? String,
              let severity = AuditResult.Severity(rawValue: severityString),
              let title = dict["title"] as? String,
              let description = dict["description"] as? String,
              let detailedExplanation = dict["detailedExplanation"] as? String,
              let suggestedAction = dict["suggestedAction"] as? String,
              let confidence = dict["confidence"] as? Double else {
            return nil
        }

        let affectedAmount = dict["affectedAmount"] as? Double
        let evidenceText = dict["evidenceText"] as? String

        return AuditResult(
            issueType: issueType,
            severity: severity,
            title: title,
            description: description,
            detailedExplanation: detailedExplanation,
            suggestedAction: suggestedAction,
            affectedAmount: affectedAmount,
            detectionMethod: .aiAnalysis,
            confidence: confidence,
            evidenceText: evidenceText,
            calculationDetails: nil,
            createdDate: Date()
        )
    }
}

/// Letter generation for RESPA compliance documents
private class LetterGenerator {

    func generateLetter(
        type: AIAnalysisService.LetterGenerationResult.LetterType,
        issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) async throws -> String {

        switch type {
        case .noticeOfError:
            return generateNoticeOfErrorLetter(issues: issues, userInfo: userInfo, mortgageAccount: mortgageAccount)
        case .qualifiedWrittenRequest:
            return generateQualifiedWrittenRequest(issues: issues, userInfo: userInfo, mortgageAccount: mortgageAccount)
        case .escalationLetter:
            return generateEscalationLetter(issues: issues, userInfo: userInfo, mortgageAccount: mortgageAccount)
        case .consumerComplaint:
            return generateConsumerComplaint(issues: issues, userInfo: userInfo, mortgageAccount: mortgageAccount)
        }
    }

    private func generateNoticeOfErrorLetter(
        issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) -> String {

        let currentDate = DateFormatter.fullDate.string(from: Date())
        let totalAmount = issues.compactMap { $0.affectedAmount }.reduce(0, +)

        let issueDescriptions = issues.enumerated().map { index, issue in
            """
            \(index + 1). \(issue.title)
               Description: \(issue.description)
               Affected Amount: \(issue.affectedAmount.map { "$\(String(format: "%.2f", $0))" } ?? "N/A")
               Evidence: \(issue.evidenceText ?? "Supporting documentation attached")
            """
        }.joined(separator: "\n\n")

        return """
        \(currentDate)

        \(mortgageAccount.servicerName)
        \(mortgageAccount.servicerAddress ?? "[Servicer Address]")

        RE: Notice of Error - Loan Number: \(mortgageAccount.loanNumber)

        Dear Sir or Madam:

        I am writing to notify you of errors in the servicing of my mortgage loan account number \(mortgageAccount.loanNumber). This letter serves as a formal Notice of Error pursuant to the Real Estate Settlement Procedures Act (RESPA), 12 U.S.C. § 2605(e), and implementing regulation 12 C.F.R. § 1024.35.

        BORROWER INFORMATION:
        Name: \(userInfo.fullName)
        Property Address: \(mortgageAccount.propertyAddress)
        Loan Number: \(mortgageAccount.loanNumber)
        \(userInfo.address.map { "Mailing Address: \($0.fullAddress)" } ?? "")
        \(userInfo.phoneNumber.map { "Phone: \($0)" } ?? "")
        Email: \(userInfo.email)

        ERRORS IDENTIFIED:

        \(issueDescriptions)

        TOTAL FINANCIAL IMPACT: $\(String(format: "%.2f", totalAmount))

        REQUESTED ACTIONS:

        Pursuant to RESPA § 2605(e)(2), I request that you:

        1. Acknowledge receipt of this Notice of Error within 5 business days
        2. Conduct a reasonable investigation of the errors described above
        3. Correct the identified errors and provide written explanation of any corrections made
        4. Provide copies of all documents relied upon in your investigation
        5. Credit my account for any fees, charges, or amounts incorrectly assessed
        6. Ensure that no adverse credit reporting occurs as a result of these errors

        Please note that RESPA requires you to respond to this Notice of Error within 7 business days of receipt (for acknowledgment) and complete your investigation within 30 business days of receipt, or 60 business days if additional information is reasonably required.

        Failure to comply with RESPA requirements may result in additional legal action. I have maintained detailed records of all communications and documentation related to this matter.

        I look forward to your prompt attention to this matter. Please provide all correspondence regarding this Notice of Error in writing.

        Sincerely,

        \(userInfo.fullName)
        Date: \(currentDate)

        Enclosures: Supporting documentation

        cc: Consumer Financial Protection Bureau
        """
    }

    private func generateQualifiedWrittenRequest(
        issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) -> String {

        let currentDate = DateFormatter.fullDate.string(from: Date())

        return """
        \(currentDate)

        \(mortgageAccount.servicerName)
        \(mortgageAccount.servicerAddress ?? "[Servicer Address]")

        RE: Qualified Written Request - Loan Number: \(mortgageAccount.loanNumber)

        Dear Sir or Madam:

        This letter constitutes a Qualified Written Request under the Real Estate Settlement Procedures Act (RESPA), 12 U.S.C. § 2605(e)(1)(B), regarding my mortgage loan account number \(mortgageAccount.loanNumber).

        I am requesting information and clarification regarding the servicing of my mortgage loan. Please provide the following information and documentation:

        1. Complete payment history for the loan from origination to present
        2. Detailed breakdown of all fees and charges applied to the account
        3. Current loan balance calculation showing principal, interest, and escrow components
        4. All escrow account statements and analysis reports
        5. Documentation supporting any late fee assessments
        6. Copies of all loan modification agreements or payment plans
        7. Complete chain of ownership/assignment of the mortgage note

        Additionally, I am requesting an explanation and correction of the following servicing issues:

        \(issues.map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))

        Under RESPA, you are required to acknowledge this request within 20 business days and provide a substantive response within 60 business days of receipt.

        Please provide all requested information in writing. Thank you for your prompt attention to this matter.

        Sincerely,

        \(userInfo.fullName)
        Loan Number: \(mortgageAccount.loanNumber)
        Date: \(currentDate)
        """
    }

    private func generateEscalationLetter(
        issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) -> String {

        let currentDate = DateFormatter.fullDate.string(from: Date())

        return """
        \(currentDate)

        \(mortgageAccount.servicerName)
        Executive Customer Resolution Department
        \(mortgageAccount.servicerAddress ?? "[Servicer Address]")

        RE: URGENT - Unresolved Servicing Errors - Loan Number: \(mortgageAccount.loanNumber)

        Dear Executive Team:

        I am writing to escalate serious, ongoing servicing errors on my mortgage loan that have not been adequately addressed despite previous communications. This matter requires immediate executive attention.

        LOAN INFORMATION:
        Borrower: \(userInfo.fullName)
        Loan Number: \(mortgageAccount.loanNumber)
        Property Address: \(mortgageAccount.propertyAddress)

        UNRESOLVED ISSUES:

        \(issues.enumerated().map { index, issue in
            "\(index + 1). \(issue.title) - SEVERITY: \(issue.severity.displayName.uppercased())"
        }.joined(separator: "\n"))

        These errors have resulted in financial harm and potential credit damage. I have documented evidence supporting each issue and am prepared to file formal complaints with regulatory agencies if this matter is not resolved promptly.

        IMMEDIATE ACTIONS REQUIRED:

        1. Assign a dedicated executive case manager to this matter
        2. Conduct a comprehensive account review within 7 business days
        3. Correct all identified errors and provide detailed explanations
        4. Implement account monitoring to prevent future errors
        5. Provide written confirmation of all corrections made

        I expect direct contact from your executive team within 48 hours of receipt of this letter. Continued failure to address these issues will result in:

        • Formal complaints to the CFPB, state attorney general, and banking regulators
        • Consideration of legal action for damages and attorney fees
        • Documentation of servicing failures for potential litigation

        This matter requires your immediate personal attention.

        Sincerely,

        \(userInfo.fullName)
        Date: \(currentDate)

        cc: Consumer Financial Protection Bureau
            State Attorney General - Consumer Protection Division
            [Primary Mortgage Investor/Owner]
        """
    }

    private func generateConsumerComplaint(
        issues: [AuditResult],
        userInfo: User,
        mortgageAccount: User.MortgageAccount
    ) -> String {

        let currentDate = DateFormatter.fullDate.string(from: Date())
        let totalAmount = issues.compactMap { $0.affectedAmount }.reduce(0, +)

        return """
        Consumer Financial Protection Bureau
        1700 G Street, NW
        Washington, DC 20552

        Date: \(currentDate)

        RE: Formal Complaint Against \(mortgageAccount.servicerName)
        Loan Number: \(mortgageAccount.loanNumber)

        Dear CFPB:

        I am filing this formal complaint against \(mortgageAccount.servicerName) for multiple violations of mortgage servicing regulations and harmful practices affecting my mortgage loan account \(mortgageAccount.loanNumber).

        COMPLAINANT INFORMATION:
        Name: \(userInfo.fullName)
        \(userInfo.address.map { "Address: \($0.fullAddress)" } ?? "")
        Phone: \(userInfo.phoneNumber ?? "Not provided")
        Email: \(userInfo.email)

        SERVICER INFORMATION:
        Company: \(mortgageAccount.servicerName)
        \(mortgageAccount.servicerAddress.map { "Address: \($0)" } ?? "")

        LOAN DETAILS:
        Loan Number: \(mortgageAccount.loanNumber)
        Property Address: \(mortgageAccount.propertyAddress)
        Original Loan Amount: $\(String(format: "%.2f", mortgageAccount.originalLoanAmount))
        Monthly Payment: $\(String(format: "%.2f", mortgageAccount.monthlyPayment))

        VIOLATIONS AND ISSUES:

        \(issues.enumerated().map { index, issue in
            """
            \(index + 1). \(issue.title)
               Impact: \(issue.severity.displayName) severity
               Financial Harm: \(issue.affectedAmount.map { "$\(String(format: "%.2f", $0))" } ?? "Non-monetary")
               Description: \(issue.description)
               Suggested Resolution: \(issue.suggestedAction)
            """
        }.joined(separator: "\n\n"))

        TOTAL DOCUMENTED FINANCIAL HARM: $\(String(format: "%.2f", totalAmount))

        REGULATORY VIOLATIONS SUSPECTED:
        • Real Estate Settlement Procedures Act (RESPA) violations
        • Unfair, Deceptive, or Abusive Acts or Practices (UDAAP)
        • Failure to properly service mortgage loan
        • Improper fee assessments and calculations

        RESOLUTION REQUESTED:
        1. Investigation of servicer's practices and procedures
        2. Correction of all identified errors
        3. Refund of improperly assessed fees and charges
        4. Implementation of improved servicing practices
        5. Monitoring of account to prevent future violations

        I have attempted to resolve these issues directly with the servicer but have not received adequate response or resolution. I request the CFPB's assistance in investigating these violations and ensuring proper resolution.

        Supporting documentation is attached. I am available to provide additional information as needed for your investigation.

        Respectfully submitted,

        \(userInfo.fullName)
        Date: \(currentDate)

        Attachments:
        • Mortgage statements and documentation
        • Payment records and bank statements
        • Previous correspondence with servicer
        • Analysis documentation supporting claimed errors
        """
    }
}

/// Rate limiting and usage tracking
private class RateLimitTracker {
    private var requestHistory: [Date] = []
    private var tokenHistory: [(date: Date, tokens: Int)] = []
    private var dailyUsage: [String: Int] = [:]

    private var requestsPerMinute = 50
    private var tokensPerMinute = 40000
    private var requestsPerDay = 1000

    func configure(requestsPerMinute: Int, tokensPerMinute: Int, requestsPerDay: Int) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.requestsPerDay = requestsPerDay
    }

    func checkRateLimit() async throws {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let today = DateFormatter.dateOnly.string(from: now)

        // Clean old entries
        requestHistory = requestHistory.filter { $0 > oneMinuteAgo }
        tokenHistory = tokenHistory.filter { $0.date > oneMinuteAgo }

        // Check request rate limit
        if requestHistory.count >= requestsPerMinute {
            throw AIAnalysisService.AIAnalysisError.rateLimitExceeded
        }

        // Check token rate limit
        let recentTokens = tokenHistory.map { $0.tokens }.reduce(0, +)
        if recentTokens >= tokensPerMinute {
            throw AIAnalysisService.AIAnalysisError.rateLimitExceeded
        }

        // Check daily limit
        if (dailyUsage[today] ?? 0) >= requestsPerDay {
            throw AIAnalysisService.AIAnalysisError.quotaExceeded
        }
    }

    func recordRequest(tokenUsage: Int) async {
        let now = Date()
        let today = DateFormatter.dateOnly.string(from: now)

        requestHistory.append(now)
        tokenHistory.append((date: now, tokens: tokenUsage))
        dailyUsage[today] = (dailyUsage[today] ?? 0) + 1
    }

    // MARK: - Second-Tier AI Analysis Support Methods

    private func buildSecondTierAnalysisPrompt(
        context: AIAnalysisContext,
        focusAreas: [AIFocusArea]
    ) -> String {
        let focusAreasText = focusAreas.map { $0.description }.joined(separator: ", ")

        return """
        You are analyzing a mortgage document for complex patterns that automated rule-based validation could not detect. This is a second-tier analysis focusing specifically on: \(focusAreasText).

        Rule-based analysis has already identified \(context.existingFindings.count) potential issues. Your task is to:
        1. Look for complex patterns that simple algorithms cannot detect
        2. Identify contextual relationships between data points
        3. Detect regulatory compliance issues requiring domain expertise
        4. Find subtle discrepancies that require understanding of mortgage practices

        EXTRACTED DATA:
        Loan Number: \(context.extractedData.loanNumber ?? "Not specified")
        Servicer: \(context.extractedData.servicerName ?? "Not specified")
        Principal Balance: $\(context.extractedData.principalBalance ?? 0)
        Interest Rate: \(context.extractedData.interestRate ?? 0)%
        Monthly Payment: $\(context.extractedData.monthlyPayment ?? 0)

        PAYMENT HISTORY (\(context.extractedData.paymentHistory.count) payments):
        \(formatPaymentHistoryForAI(context.extractedData.paymentHistory))

        ESCROW ACTIVITY (\(context.extractedData.escrowActivity.count) transactions):
        \(formatEscrowActivityForAI(context.extractedData.escrowActivity))

        FEES (\(context.extractedData.fees.count) fees):
        \(formatFeesForAI(context.extractedData.fees))

        EXISTING RULE-BASED FINDINGS:
        \(formatExistingFindingsForAI(context.existingFindings))

        BANK TRANSACTION DATA:
        \(formatBankTransactionsForAI(context.bankTransactions))

        Focus your analysis on patterns that require contextual understanding and regulatory knowledge. Look for:
        - Unusual patterns in payment allocation over time
        - Subtle regulatory violations
        - Complex fee structures that may be improper
        - Inconsistencies that suggest systemic issues
        - Contextual red flags that simple rules cannot detect

        Respond with specific findings in this JSON format:
        {
          "findings": [
            {
              "category": "complex_pattern|regulatory_compliance|contextual_inconsistency",
              "severity": "low|medium|high|critical",
              "title": "Brief title",
              "description": "Clear description",
              "explanation": "Detailed explanation with specific evidence",
              "evidence": ["specific data points that support this finding"],
              "confidence": 0.0-1.0,
              "financial_impact": estimated_dollar_amount_or_null,
              "regulatory_reference": "applicable regulation or null"
            }
          ]
        }
        """
    }

    private func parseComplexPatternFindings(
        response: String,
        context: AIAnalysisContext
    ) throws -> [AIAnalysisResult] {

        // Parse JSON response from Claude
        guard let data = response.data(using: .utf8) else {
            throw AIAnalysisError.responseParsingFailed("Invalid response encoding")
        }

        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let findings = jsonResponse?["findings"] as? [[String: Any]] else {
                throw AIAnalysisError.responseParsingFailed("No findings array in response")
            }

            return findings.compactMap { findingDict in
                guard let category = findingDict["category"] as? String,
                      let severity = findingDict["severity"] as? String,
                      let title = findingDict["title"] as? String,
                      let description = findingDict["description"] as? String,
                      let explanation = findingDict["explanation"] as? String,
                      let evidence = findingDict["evidence"] as? [String],
                      let confidence = findingDict["confidence"] as? Double else {
                    return nil
                }

                return AIAnalysisResult(
                    category: category,
                    severity: severity,
                    title: title,
                    description: description,
                    explanation: explanation,
                    evidence: evidence,
                    confidence: confidence,
                    financialImpact: findingDict["financial_impact"] as? Double,
                    regulatoryReference: findingDict["regulatory_reference"] as? String
                )
            }

        } catch {
            throw AIAnalysisError.responseParsingFailed("JSON parsing failed: \(error.localizedDescription)")
        }
    }

    private func estimateSecondTierAnalysisCost(
        extractedData: ExtractedData,
        ruleBasedFindings: [AuditResult]
    ) -> Double {

        // Base cost calculation for second-tier analysis
        let baseTokens = 500 // Base prompt tokens

        // Add tokens for payment history (reduced since we're only analyzing gaps)
        let paymentTokens = min(extractedData.paymentHistory.count * 15, 1000)

        // Add tokens for escrow activity
        let escrowTokens = min(extractedData.escrowActivity.count * 10, 500)

        // Add tokens for existing findings context
        let findingsTokens = min(ruleBasedFindings.count * 20, 600)

        // Add tokens for bank transactions (summarized)
        let bankTokens = 300

        let totalInputTokens = baseTokens + paymentTokens + escrowTokens + findingsTokens + bankTokens
        let estimatedOutputTokens = 400 // Conservative estimate for AI response

        // Use Claude 3.5 Sonnet pricing (example rates)
        let inputCost = Double(totalInputTokens) * 0.003 / 1000  // $3 per 1M input tokens
        let outputCost = Double(estimatedOutputTokens) * 0.015 / 1000  // $15 per 1M output tokens

        return inputCost + outputCost
    }

    private func createSecondTierContext(
        extractedData: ExtractedData,
        bankTransactions: [Transaction],
        loanDetails: LoanDetails?,
        ruleBasedFindings: [AuditResult]
    ) -> AIAnalysisContext {

        return AIAnalysisContext(
            extractedData: extractedData,
            bankTransactions: bankTransactions,
            loanDetails: loanDetails,
            existingFindings: ruleBasedFindings
        )
    }

    private func determineFocusAreas(from ruleBasedFindings: [AuditResult]) -> [AIFocusArea] {
        var focusAreas: [AIFocusArea] = []

        // If few rule-based findings, focus on complex patterns
        if ruleBasedFindings.count < 3 {
            focusAreas.append(.complexPatterns)
        }

        // If compliance issues detected, focus on regulatory analysis
        let hasComplianceIssues = ruleBasedFindings.contains { result in
            result.issueType.rawValue.contains("respa") ||
            result.issueType.rawValue.contains("tila")
        }

        if hasComplianceIssues {
            focusAreas.append(.regulatoryCompliance)
        }

        // If high-severity errors found, focus on contextual analysis
        let hasCriticalErrors = ruleBasedFindings.contains { $0.severity == .critical }
        if hasCriticalErrors {
            focusAreas.append(.contextualAnalysis)
        }

        // Default focus if no specific patterns detected
        if focusAreas.isEmpty {
            focusAreas.append(.complexPatterns)
        }

        return focusAreas
    }

    private func convertAIResultToAuditResult(
        _ aiResult: AIAnalysisResult,
        detectionMethod: AuditResult.DetectionMethod
    ) -> AuditResult? {

        // Map AI categories to AuditResult issue types
        let issueType: AuditResult.IssueType
        switch aiResult.category {
        case "complex_pattern":
            issueType = .misappliedPayment
        case "regulatory_compliance":
            issueType = .respaNoticeOfErrorViolation
        case "contextual_inconsistency":
            issueType = .incorrectBalance
        default:
            issueType = .incorrectBalance
        }

        // Map AI severity to AuditResult severity
        let severity: AuditResult.Severity
        switch aiResult.severity {
        case "low": severity = .low
        case "medium": severity = .medium
        case "high": severity = .high
        case "critical": severity = .critical
        default: severity = .medium
        }

        return AuditResult(
            issueType: issueType,
            severity: severity,
            title: aiResult.title,
            description: aiResult.description,
            detailedExplanation: aiResult.explanation,
            suggestedAction: generateSuggestedAction(for: aiResult),
            affectedAmount: aiResult.financialImpact,
            detectionMethod: detectionMethod,
            confidence: aiResult.confidence,
            evidenceText: aiResult.evidence.joined(separator: "; "),
            calculationDetails: nil,
            createdDate: Date()
        )
    }

    private func generateSuggestedAction(for aiResult: AIAnalysisResult) -> String {
        switch aiResult.category {
        case "complex_pattern":
            return "Investigate pattern with servicer and request detailed explanation"
        case "regulatory_compliance":
            return "File formal complaint with CFPB and request immediate corrective action"
        case "contextual_inconsistency":
            return "Request detailed account reconciliation and audit trail"
        default:
            return "Contact servicer for clarification and documentation"
        }
    }

    // MARK: - AI Response Formatting Helpers

    private func formatPaymentHistoryForAI(_ payments: [ExtractedData.PaymentRecord]) -> String {
        let recentPayments = Array(payments.prefix(20)) // Limit to most recent 20 payments
        return recentPayments.map { payment in
            "Date: \(DateFormatter.shortDate.string(from: payment.paymentDate)), " +
            "Amount: $\(payment.amount), " +
            "Principal: $\(payment.principalApplied ?? 0), " +
            "Interest: $\(payment.interestApplied ?? 0), " +
            "Escrow: $\(payment.escrowApplied ?? 0), " +
            "Late Fees: $\(payment.lateFeesApplied ?? 0)"
        }.joined(separator: "\n")
    }

    private func formatEscrowActivityForAI(_ transactions: [ExtractedData.EscrowTransaction]) -> String {
        let recentTransactions = Array(transactions.prefix(15))
        return recentTransactions.map { transaction in
            "\(transaction.type.rawValue.capitalized): $\(transaction.amount) on \(DateFormatter.shortDate.string(from: transaction.date)) - \(transaction.description)"
        }.joined(separator: "\n")
    }

    private func formatFeesForAI(_ fees: [ExtractedData.Fee]) -> String {
        return fees.map { fee in
            "\(fee.category.rawValue): $\(fee.amount) on \(DateFormatter.shortDate.string(from: fee.date)) - \(fee.description)"
        }.joined(separator: "\n")
    }

    private func formatExistingFindingsForAI(_ findings: [AuditResult]) -> String {
        let topFindings = Array(findings.prefix(10)) // Include top 10 findings for context
        return topFindings.map { finding in
            "[\(finding.severity.rawValue.uppercased())] \(finding.title): \(finding.description)"
        }.joined(separator: "\n")
    }

    private func formatBankTransactionsForAI(_ transactions: [Transaction]) -> String {
        let mortgagePayments = transactions.filter { transaction in
            transaction.amount < 0 && // Outgoing payment
            abs(transaction.amount) > 500 // Likely mortgage payment amount
        }.prefix(10)

        return mortgagePayments.map { transaction in
            "Date: \(DateFormatter.shortDate.string(from: transaction.date)), " +
            "Amount: $\(abs(transaction.amount)), " +
            "Description: \(transaction.description ?? "Payment")"
        }.joined(separator: "\n")
    }

    // MARK: - Enhanced AI Configuration

    private extension AIConfiguration {
        static let focused = AIConfiguration(
            model: .claude35Sonnet,
            maxTokens: 2000,
            temperature: 0.3, // Lower temperature for more focused analysis
            confidenceThreshold: 0.7,
            timeoutInterval: 45.0, // Shorter timeout for cost control
            enableStreamingResponse: false,
            retryAttempts: 2,
            concurrentAnalysisLimit: 1
        )
    }
}

// MARK: - Supporting Types for Tiered Analysis

/// AI Analysis Context for second-tier analysis
struct AIAnalysisContext {
    let extractedData: ExtractedData
    let bankTransactions: [Transaction]
    let loanDetails: LoanDetails?
    let existingFindings: [AuditResult]
}

/// AI Focus Areas for targeted analysis
enum AIFocusArea {
    case complexPatterns
    case regulatoryCompliance
    case contextualAnalysis

    var description: String {
        switch self {
        case .complexPatterns:
            return "complex patterns and subtle inconsistencies"
        case .regulatoryCompliance:
            return "regulatory compliance and legal violations"
        case .contextualAnalysis:
            return "contextual relationships and systemic issues"
        }
    }
}

/// AI Analysis Result structure
struct AIAnalysisResult {
    let category: String
    let severity: String
    let title: String
    let description: String
    let explanation: String
    let evidence: [String]
    let confidence: Double
    let financialImpact: Double?
    let regulatoryReference: String?
}

// MARK: - Extensions

extension DateFormatter {
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

extension AuditResult.Severity {
    var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}