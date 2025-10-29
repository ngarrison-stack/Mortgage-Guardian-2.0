import Foundation
import Combine
import os.log

/// Quality Assurance Workflow Engine for Zero-Tolerance Mortgage Auditing
/// Orchestrates human review triggers and quality assurance processes
@MainActor
public final class QualityAssuranceWorkflowEngine: ObservableObject {

    // MARK: - Types

    /// Human review request with complete context
    public struct HumanReviewRequest {
        let id: UUID
        let priority: ReviewPriority
        let requestType: ReviewType
        let extractedData: ExtractedData
        let ruleBasedFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
        let aiFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
        let triggerReasons: [ReviewTrigger]
        let suggestedReviewTime: TimeInterval
        let deadline: Date
        let reviewContext: ReviewContext
        let escalationPath: [ReviewerRole]
        let auditTrail: [ReviewAuditEntry]

        public enum ReviewPriority: String, CaseIterable, Comparable {
            case critical = "critical"     // Legal liability, immediate action required
            case urgent = "urgent"         // High financial impact, 24hr response
            case high = "high"            // Significant issues, 48hr response
            case normal = "normal"        // Standard review, 72hr response
            case routine = "routine"      // Quality check, 1 week response

            var responseTimeLimit: TimeInterval {
                switch self {
                case .critical: return 3600    // 1 hour
                case .urgent: return 86400     // 24 hours
                case .high: return 172800      // 48 hours
                case .normal: return 259200    // 72 hours
                case .routine: return 604800   // 1 week
                }
            }

            public static func < (lhs: ReviewPriority, rhs: ReviewPriority) -> Bool {
                let order: [ReviewPriority] = [.routine, .normal, .high, .urgent, .critical]
                return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
            }
        }

        public enum ReviewType: String, CaseIterable {
            case confidenceValidation = "confidence_validation"
            case conflictResolution = "conflict_resolution"
            case criticalErrorReview = "critical_error_review"
            case complianceVerification = "compliance_verification"
            case qualityAssurance = "quality_assurance"
            case escalatedReview = "escalated_review"
            case legalReview = "legal_review"
        }

        public enum ReviewTrigger: String, CaseIterable {
            case lowConfidence = "low_confidence"
            case criticalError = "critical_error"
            case regulatoryViolation = "regulatory_violation"
            case aiConsensusFailure = "ai_consensus_failure"
            case highFinancialImpact = "high_financial_impact"
            case ocrDiscrepancy = "ocr_discrepancy"
            case dataIntegrityIssue = "data_integrity_issue"
            case unusualPattern = "unusual_pattern"
        }

        public struct ReviewContext {
            let documentId: String
            let customerAccount: String
            let loanType: String
            let riskLevel: RiskLevel
            let previousReviews: [HumanReviewResult]
            let systemRecommendations: [String]
            let timeConstraints: [String]
            let requiredExpertise: [ExpertiseArea]

            public enum RiskLevel: String {
                case low = "low"
                case medium = "medium"
                case high = "high"
                case critical = "critical"
            }

            public enum ExpertiseArea: String {
                case mortgageLaw = "mortgage_law"
                case financialCalculations = "financial_calculations"
                case regulatoryCompliance = "regulatory_compliance"
                case dataAnalysis = "data_analysis"
                case customerService = "customer_service"
            }
        }

        public enum ReviewerRole: String, CaseIterable {
            case analyst = "analyst"
            case seniorAnalyst = "senior_analyst"
            case complianceOfficer = "compliance_officer"
            case legalCounsel = "legal_counsel"
            case managementReview = "management_review"
            case externalAuditor = "external_auditor"
        }

        public struct ReviewAuditEntry {
            let action: String
            let performer: String
            let timestamp: Date
            let details: [String: Any]
            let digitalSignature: String
        }
    }

    /// Human review result with detailed findings
    public struct HumanReviewResult {
        let requestId: UUID
        let reviewerId: String
        let reviewerRole: HumanReviewRequest.ReviewerRole
        let completionTimestamp: Date
        let reviewDuration: TimeInterval
        let findings: [ZeroToleranceAuditEngine.ZeroToleranceError]
        let validatedFindings: [ValidationDecision]
        let additionalObservations: [String]
        let recommendedActions: [ActionRecommendation]
        let confidenceAssessment: ConfidenceAssessment
        let escalationNeeded: Bool
        let followUpRequired: Bool
        let qualityScore: Double
        let reviewSignature: String

        public struct ValidationDecision {
            let errorId: UUID
            let decision: Decision
            let rationale: String
            let confidence: Double
            let supportingEvidence: [String]

            public enum Decision: String {
                case confirmed = "confirmed"
                case rejected = "rejected"
                case modified = "modified"
                case needsInvestigation = "needs_investigation"
            }
        }

        public struct ActionRecommendation {
            let priority: HumanReviewRequest.ReviewPriority
            let action: String
            let timeline: TimeInterval
            let responsibleParty: String
            let estimatedImpact: Double
        }

        public struct ConfidenceAssessment {
            let overallConfidence: Double
            let confidenceFactors: [String: Double]
            let uncertaintyAreas: [String]
            let recommendedFollowUp: [String]
        }
    }

    /// Workflow configuration
    public struct WorkflowConfiguration {
        let enableAutomaticReviewTriggers: Bool
        let confidenceThreshold: Double
        let criticalErrorAutoTrigger: Bool
        let maxPendingReviews: Int
        let defaultReviewTimeout: TimeInterval
        let escalationEnabled: Bool
        let qualityMetricsTracking: Bool
        let reviewerPoolManagement: Bool

        public static let strict = WorkflowConfiguration(
            enableAutomaticReviewTriggers: true,
            confidenceThreshold: 0.95,
            criticalErrorAutoTrigger: true,
            maxPendingReviews: 10,
            defaultReviewTimeout: 86400, // 24 hours
            escalationEnabled: true,
            qualityMetricsTracking: true,
            reviewerPoolManagement: true
        )

        public static let balanced = WorkflowConfiguration(
            enableAutomaticReviewTriggers: true,
            confidenceThreshold: 0.85,
            criticalErrorAutoTrigger: true,
            maxPendingReviews: 20,
            defaultReviewTimeout: 172800, // 48 hours
            escalationEnabled: true,
            qualityMetricsTracking: false,
            reviewerPoolManagement: false
        )
    }

    // MARK: - Properties

    @Published public var pendingReviews: [HumanReviewRequest] = []
    @Published public var completedReviews: [HumanReviewResult] = []
    @Published public var activeReviews: [UUID: ReviewSession] = [:]
    @Published public var workflowMetrics: WorkflowMetrics = WorkflowMetrics()

    public static let shared = QualityAssuranceWorkflowEngine()

    private let configuration: WorkflowConfiguration
    private let logger = Logger(subsystem: "MortgageGuardian", category: "QualityAssurance")

    // Workflow components
    private let reviewerPool: ReviewerPoolManager
    private let escalationManager: EscalationManager
    private let qualityMetrics: QualityMetricsTracker
    private let notificationService: ReviewNotificationService

    private var cancellables = Set<AnyCancellable>()

    /// Current review session
    public struct ReviewSession {
        let request: HumanReviewRequest
        let assignedReviewer: String
        let startTime: Date
        let expectedCompletion: Date
        let currentStatus: ReviewStatus
        let progressNotes: [String]

        public enum ReviewStatus: String {
            case assigned = "assigned"
            case inProgress = "in_progress"
            case awaitingInformation = "awaiting_information"
            case escalated = "escalated"
            case completed = "completed"
            case overdue = "overdue"
        }
    }

    /// Workflow performance metrics
    public struct WorkflowMetrics {
        var totalReviewsRequested: Int = 0
        var totalReviewsCompleted: Int = 0
        var averageReviewTime: TimeInterval = 0
        var reviewAccuracy: Double = 0
        var escalationRate: Double = 0
        var overdueTasks: Int = 0
        var reviewerProductivity: [String: Double] = [:]
        var qualityScores: [Double] = []

        var completionRate: Double {
            guard totalReviewsRequested > 0 else { return 0 }
            return Double(totalReviewsCompleted) / Double(totalReviewsRequested)
        }

        var averageQualityScore: Double {
            guard !qualityScores.isEmpty else { return 0 }
            return qualityScores.reduce(0, +) / Double(qualityScores.count)
        }
    }

    // MARK: - Initialization

    public init(
        configuration: WorkflowConfiguration = .strict,
        reviewerPool: ReviewerPoolManager = ReviewerPoolManager(),
        escalationManager: EscalationManager = EscalationManager(),
        qualityMetrics: QualityMetricsTracker = QualityMetricsTracker(),
        notificationService: ReviewNotificationService = ReviewNotificationService()
    ) {
        self.configuration = configuration
        self.reviewerPool = reviewerPool
        self.escalationManager = escalationManager
        self.qualityMetrics = qualityMetrics
        self.notificationService = notificationService

        setupWorkflowMonitoring()
    }

    // MARK: - Public Methods

    /// Request expert human review with complete context
    public func requestExpertReview(
        extractedData: ExtractedData,
        ruleBasedFindings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        aiFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        logger.info("Requesting expert review for document with \(ruleBasedFindings.count) rule-based and \(aiFindings.count) AI findings")

        // Analyze review triggers
        let triggers = analyzeReviewTriggers(
            ruleBasedFindings: ruleBasedFindings,
            aiFindings: aiFindings,
            extractedData: extractedData
        )

        guard !triggers.isEmpty else {
            logger.info("No review triggers identified - skipping human review")
            return combineFindings(ruleBasedFindings: ruleBasedFindings, aiFindings: aiFindings)
        }

        // Determine review priority and type
        let priority = determinePriority(triggers: triggers, findings: ruleBasedFindings + aiFindings)
        let reviewType = determineReviewType(triggers: triggers)

        // Create review context
        let reviewContext = createReviewContext(
            extractedData: extractedData,
            findings: ruleBasedFindings + aiFindings,
            triggers: triggers
        )

        // Create review request
        let reviewRequest = HumanReviewRequest(
            id: UUID(),
            priority: priority,
            requestType: reviewType,
            extractedData: extractedData,
            ruleBasedFindings: ruleBasedFindings,
            aiFindings: aiFindings,
            triggerReasons: triggers,
            suggestedReviewTime: calculateSuggestedReviewTime(
                complexity: extractedData.complexityScore,
                errorCount: ruleBasedFindings.count + aiFindings.count
            ),
            deadline: Date().addingTimeInterval(priority.responseTimeLimit),
            reviewContext: reviewContext,
            escalationPath: determineEscalationPath(priority: priority, reviewType: reviewType),
            auditTrail: []
        )

        // Check capacity and queue review
        guard pendingReviews.count < configuration.maxPendingReviews else {
            throw QualityAssuranceError.reviewQueueFull
        }

        // Add to pending reviews
        pendingReviews.append(reviewRequest)
        workflowMetrics.totalReviewsRequested += 1

        // Assign reviewer if pool management enabled
        if configuration.reviewerPoolManagement {
            try await assignReviewer(for: reviewRequest)
        }

        // Send notifications
        await notificationService.notifyReviewRequested(reviewRequest)

        // For immediate critical reviews, attempt synchronous processing
        if priority == .critical && configuration.criticalErrorAutoTrigger {
            return try await processCriticalReviewImmediate(reviewRequest)
        }

        // For other priorities, return combined findings pending human review
        logger.info("Review request queued with priority: \(priority.rawValue)")
        return combineFindings(ruleBasedFindings: ruleBasedFindings, aiFindings: aiFindings)
    }

    /// Submit review result from human reviewer
    public func submitReviewResult(_ result: HumanReviewResult) async throws {
        guard let reviewIndex = pendingReviews.firstIndex(where: { $0.id == result.requestId }) else {
            throw QualityAssuranceError.reviewNotFound
        }

        let reviewRequest = pendingReviews[reviewIndex]
        pendingReviews.remove(at: reviewIndex)

        // Add to completed reviews
        completedReviews.append(result)

        // Remove from active sessions
        activeReviews.removeValue(forKey: result.requestId)

        // Update metrics
        workflowMetrics.totalReviewsCompleted += 1
        workflowMetrics.qualityScores.append(result.qualityScore)

        // Track reviewer performance
        qualityMetrics.updateReviewerMetrics(
            reviewerId: result.reviewerId,
            reviewTime: result.reviewDuration,
            qualityScore: result.qualityScore
        )

        // Process escalation if needed
        if result.escalationNeeded {
            try await escalateReview(reviewRequest: reviewRequest, result: result)
        }

        // Send completion notifications
        await notificationService.notifyReviewCompleted(result)

        logger.info("Review completed by \(result.reviewerRole.rawValue) with quality score: \(String(format: "%.2f", result.qualityScore))")
    }

    /// Get pending reviews for specific reviewer role
    public func getPendingReviewsForRole(_ role: HumanReviewRequest.ReviewerRole) -> [HumanReviewRequest] {
        return pendingReviews.filter { review in
            review.escalationPath.contains(role)
        }.sorted { $0.priority > $1.priority }
    }

    /// Get workflow performance metrics
    public func getWorkflowMetrics() -> WorkflowMetrics {
        return workflowMetrics
    }

    /// Force escalate a review
    public func escalateReview(reviewId: UUID, reason: String) async throws {
        guard let reviewIndex = pendingReviews.firstIndex(where: { $0.id == reviewId }) else {
            throw QualityAssuranceError.reviewNotFound
        }

        let reviewRequest = pendingReviews[reviewIndex]
        try await escalationManager.escalateReview(
            request: reviewRequest,
            reason: reason,
            escalatedBy: "system"
        )

        logger.warning("Review \(reviewId) escalated: \(reason)")
    }

    // MARK: - Private Methods

    private func setupWorkflowMonitoring() {
        // Monitor for overdue reviews
        Timer.publish(every: 3600, on: .main, in: .common) // Check hourly
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkForOverdueReviews()
                }
            }
            .store(in: &cancellables)

        // Monitor workflow metrics
        if configuration.qualityMetricsTracking {
            Timer.publish(every: 86400, on: .main, in: .common) // Daily metrics update
                .autoconnect()
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.updateWorkflowMetrics()
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func analyzeReviewTriggers(
        ruleBasedFindings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        aiFindings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        extractedData: ExtractedData
    ) -> [HumanReviewRequest.ReviewTrigger] {

        var triggers: [HumanReviewRequest.ReviewTrigger] = []

        // Check for critical errors
        let criticalErrors = (ruleBasedFindings + aiFindings).filter { $0.severity == .critical }
        if !criticalErrors.isEmpty {
            triggers.append(.criticalError)
        }

        // Check for regulatory violations
        let regulatoryViolations = (ruleBasedFindings + aiFindings).filter { error in
            [.respaSection6Violation, .respaSection8Violation, .respaSection10Violation,
             .tilaDisclosureViolation, .automaticStayViolation].contains(error.category)
        }
        if !regulatoryViolations.isEmpty {
            triggers.append(.regulatoryViolation)
        }

        // Check for low confidence
        let allFindings = ruleBasedFindings + aiFindings
        if !allFindings.isEmpty {
            let averageConfidence = allFindings.reduce(0) { $0 + $1.confidence } / Double(allFindings.count)
            if averageConfidence < configuration.confidenceThreshold {
                triggers.append(.lowConfidence)
            }
        }

        // Check for high financial impact
        let totalFinancialImpact = allFindings.compactMap { $0.financialImpact.estimatedDamage }.reduce(0, +)
        if totalFinancialImpact > 10000 { // $10,000 threshold
            triggers.append(.highFinancialImpact)
        }

        // Check for AI consensus failure
        let ruleBasedCategories = Set(ruleBasedFindings.map { $0.category })
        let aiCategories = Set(aiFindings.map { $0.category })
        let consensusFailure = ruleBasedCategories.symmetricDifference(aiCategories).count > 2
        if consensusFailure {
            triggers.append(.aiConsensusFailure)
        }

        return triggers
    }

    private func determinePriority(
        triggers: [HumanReviewRequest.ReviewTrigger],
        findings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> HumanReviewRequest.ReviewPriority {

        // Critical priority triggers
        if triggers.contains(.criticalError) || triggers.contains(.regulatoryViolation) {
            return .critical
        }

        // Urgent priority triggers
        if triggers.contains(.highFinancialImpact) {
            return .urgent
        }

        // High priority triggers
        if triggers.contains(.aiConsensusFailure) || triggers.contains(.dataIntegrityIssue) {
            return .high
        }

        // Normal priority for other triggers
        if triggers.contains(.lowConfidence) || triggers.contains(.ocrDiscrepancy) {
            return .normal
        }

        // Default to routine
        return .routine
    }

    private func determineReviewType(
        triggers: [HumanReviewRequest.ReviewTrigger]
    ) -> HumanReviewRequest.ReviewType {

        if triggers.contains(.criticalError) {
            return .criticalErrorReview
        } else if triggers.contains(.regulatoryViolation) {
            return .complianceVerification
        } else if triggers.contains(.aiConsensusFailure) {
            return .conflictResolution
        } else if triggers.contains(.lowConfidence) {
            return .confidenceValidation
        } else {
            return .qualityAssurance
        }
    }

    private func createReviewContext(
        extractedData: ExtractedData,
        findings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        triggers: [HumanReviewRequest.ReviewTrigger]
    ) -> HumanReviewRequest.ReviewContext {

        let riskLevel: HumanReviewRequest.ReviewContext.RiskLevel
        let criticalCount = findings.filter { $0.severity == .critical }.count
        let highCount = findings.filter { $0.severity == .high }.count

        if criticalCount > 0 {
            riskLevel = .critical
        } else if highCount > 2 {
            riskLevel = .high
        } else if findings.count > 5 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }

        let requiredExpertise = determineRequiredExpertise(triggers: triggers, findings: findings)

        return HumanReviewRequest.ReviewContext(
            documentId: extractedData.documentId ?? "unknown",
            customerAccount: extractedData.accountNumber ?? "unknown",
            loanType: extractedData.loanType?.rawValue ?? "unknown",
            riskLevel: riskLevel,
            previousReviews: [],
            systemRecommendations: generateSystemRecommendations(findings: findings),
            timeConstraints: [],
            requiredExpertise: requiredExpertise
        )
    }

    private func determineRequiredExpertise(
        triggers: [HumanReviewRequest.ReviewTrigger],
        findings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> [HumanReviewRequest.ReviewContext.ExpertiseArea] {

        var expertise: [HumanReviewRequest.ReviewContext.ExpertiseArea] = []

        if triggers.contains(.regulatoryViolation) {
            expertise.append(.regulatoryCompliance)
            expertise.append(.mortgageLaw)
        }

        if findings.contains(where: { $0.category == .interestMiscalculation || $0.category == .principalMisapplication }) {
            expertise.append(.financialCalculations)
        }

        if triggers.contains(.dataIntegrityIssue) || triggers.contains(.ocrDiscrepancy) {
            expertise.append(.dataAnalysis)
        }

        return expertise.isEmpty ? [.dataAnalysis] : Array(Set(expertise))
    }

    private func determineEscalationPath(
        priority: HumanReviewRequest.ReviewPriority,
        reviewType: HumanReviewRequest.ReviewType
    ) -> [HumanReviewRequest.ReviewerRole] {

        switch priority {
        case .critical:
            return [.complianceOfficer, .legalCounsel, .managementReview]
        case .urgent:
            return [.seniorAnalyst, .complianceOfficer]
        case .high:
            return [.seniorAnalyst, .complianceOfficer]
        case .normal:
            return [.analyst, .seniorAnalyst]
        case .routine:
            return [.analyst]
        }
    }

    private func calculateSuggestedReviewTime(complexity: Double, errorCount: Int) -> TimeInterval {
        let baseTime: TimeInterval = 1800 // 30 minutes base
        let complexityFactor = complexity * 1800 // Up to 30 minutes for complexity
        let errorFactor = Double(errorCount) * 300 // 5 minutes per error

        return baseTime + complexityFactor + errorFactor
    }

    private func generateSystemRecommendations(
        findings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> [String] {

        var recommendations: [String] = []

        let criticalFindings = findings.filter { $0.severity == .critical }
        if !criticalFindings.isEmpty {
            recommendations.append("Priority: Address \(criticalFindings.count) critical findings immediately")
        }

        let paymentErrors = findings.filter {
            [.paymentMisallocation, .paymentCalculationError, .duplicatePaymentProcessing].contains($0.category)
        }
        if !paymentErrors.isEmpty {
            recommendations.append("Focus: Payment processing issues require detailed review")
        }

        let complianceIssues = findings.filter {
            [.respaSection6Violation, .tilaDisclosureViolation, .automaticStayViolation].contains($0.category)
        }
        if !complianceIssues.isEmpty {
            recommendations.append("Legal: Regulatory compliance violations detected - legal review recommended")
        }

        return recommendations
    }

    private func combineFindings(
        ruleBasedFindings: [ZeroToleranceAuditEngine.ZeroToleranceError],
        aiFindings: [ZeroToleranceAuditEngine.ZeroToleranceError]
    ) -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        var combinedFindings = ruleBasedFindings

        // Add AI findings that don't duplicate rule-based findings
        for aiError in aiFindings {
            let isDuplicate = ruleBasedFindings.contains { ruleError in
                ruleError.category == aiError.category &&
                ruleError.title == aiError.title
            }

            if !isDuplicate {
                combinedFindings.append(aiError)
            }
        }

        return combinedFindings.sorted { $0.severity > $1.severity }
    }

    private func assignReviewer(for request: HumanReviewRequest) async throws {
        let assignedReviewer = try await reviewerPool.assignReviewer(
            for: request.priority,
            requiredExpertise: request.reviewContext.requiredExpertise,
            estimatedTime: request.suggestedReviewTime
        )

        let session = ReviewSession(
            request: request,
            assignedReviewer: assignedReviewer,
            startTime: Date(),
            expectedCompletion: request.deadline,
            currentStatus: .assigned,
            progressNotes: []
        )

        activeReviews[request.id] = session

        await notificationService.notifyReviewerAssigned(
            reviewerId: assignedReviewer,
            request: request
        )
    }

    private func processCriticalReviewImmediate(
        _ request: HumanReviewRequest
    ) async throws -> [ZeroToleranceAuditEngine.ZeroToleranceError] {

        logger.critical("Processing critical review immediately: \(request.id)")

        // For critical issues, we would integrate with emergency review protocols
        // This might involve:
        // 1. Immediate notification to on-call compliance officer
        // 2. Escalation to legal team
        // 3. Automatic compliance holds
        // 4. Emergency remediation workflows

        // For now, return the combined findings with enhanced audit trail
        let combinedFindings = combineFindings(
            ruleBasedFindings: request.ruleBasedFindings,
            aiFindings: request.aiFindings
        )

        // Add critical review markers to audit trail
        for finding in combinedFindings where finding.severity == .critical {
            logger.critical("CRITICAL FINDING: \(finding.title) - \(finding.description)")
        }

        return combinedFindings
    }

    private func escalateReview(
        reviewRequest: HumanReviewRequest,
        result: HumanReviewResult
    ) async throws {

        await escalationManager.escalateReview(
            request: reviewRequest,
            reason: "Human reviewer recommended escalation",
            escalatedBy: result.reviewerId
        )

        workflowMetrics.escalationRate = Double(workflowMetrics.totalReviewsCompleted) /
            Double(workflowMetrics.totalReviewsRequested)
    }

    private func checkForOverdueReviews() async {
        let now = Date()
        var overdueCount = 0

        for review in pendingReviews {
            if review.deadline < now {
                overdueCount += 1

                // Send overdue notifications
                await notificationService.notifyReviewOverdue(review)

                // Auto-escalate critical overdue reviews
                if review.priority == .critical {
                    try? await escalateReview(
                        reviewId: review.id,
                        reason: "Critical review overdue"
                    )
                }
            }
        }

        workflowMetrics.overdueTasks = overdueCount

        if overdueCount > 0 {
            logger.warning("\(overdueCount) reviews are overdue")
        }
    }

    private func updateWorkflowMetrics() async {
        // Calculate average review time
        if !completedReviews.isEmpty {
            let totalTime = completedReviews.reduce(0) { $0 + $1.reviewDuration }
            workflowMetrics.averageReviewTime = totalTime / Double(completedReviews.count)
        }

        // Update reviewer productivity metrics
        qualityMetrics.updateWorkflowMetrics(&workflowMetrics)

        logger.info("Workflow metrics updated - Completion rate: \(String(format: "%.1f", workflowMetrics.completionRate * 100))%")
    }
}

// MARK: - Supporting Classes

/// Manages reviewer assignments and capacity
private class ReviewerPoolManager {
    func assignReviewer(
        for priority: QualityAssuranceWorkflowEngine.HumanReviewRequest.ReviewPriority,
        requiredExpertise: [QualityAssuranceWorkflowEngine.HumanReviewRequest.ReviewContext.ExpertiseArea],
        estimatedTime: TimeInterval
    ) async throws -> String {
        // Implementation would integrate with HR systems or reviewer management
        return "reviewer_\(UUID().uuidString.prefix(8))"
    }
}

/// Handles review escalations
private class EscalationManager {
    func escalateReview(
        request: QualityAssuranceWorkflowEngine.HumanReviewRequest,
        reason: String,
        escalatedBy: String
    ) async throws {
        // Implementation would handle escalation workflows
    }
}

/// Tracks quality metrics and reviewer performance
private class QualityMetricsTracker {
    func updateReviewerMetrics(reviewerId: String, reviewTime: TimeInterval, qualityScore: Double) {
        // Implementation would track individual reviewer performance
    }

    func updateWorkflowMetrics(_ metrics: inout QualityAssuranceWorkflowEngine.WorkflowMetrics) {
        // Implementation would update comprehensive workflow metrics
    }
}

/// Sends notifications for review events
private class ReviewNotificationService {
    func notifyReviewRequested(_ request: QualityAssuranceWorkflowEngine.HumanReviewRequest) async {
        // Implementation would send notifications via email, Slack, etc.
    }

    func notifyReviewerAssigned(reviewerId: String, request: QualityAssuranceWorkflowEngine.HumanReviewRequest) async {
        // Implementation would notify assigned reviewer
    }

    func notifyReviewCompleted(_ result: QualityAssuranceWorkflowEngine.HumanReviewResult) async {
        // Implementation would notify stakeholders of completion
    }

    func notifyReviewOverdue(_ request: QualityAssuranceWorkflowEngine.HumanReviewRequest) async {
        // Implementation would send overdue notifications
    }
}

// MARK: - Errors

public enum QualityAssuranceError: LocalizedError {
    case reviewQueueFull
    case reviewNotFound
    case reviewerUnavailable
    case escalationFailed

    public var errorDescription: String? {
        switch self {
        case .reviewQueueFull:
            return "Review queue is at capacity"
        case .reviewNotFound:
            return "Review request not found"
        case .reviewerUnavailable:
            return "No available reviewer for this request"
        case .escalationFailed:
            return "Failed to escalate review"
        }
    }
}