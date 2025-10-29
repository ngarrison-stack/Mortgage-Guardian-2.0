import Foundation
import SwiftUI
import Combine
import Charts

/// Enhanced ViewModel for sophisticated analysis management with advanced filtering, sorting, and data processing
@MainActor
class AnalysisViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var auditResults: [AuditResult] = []
    @Published var filteredResults: [AuditResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Filter Properties
    @Published var searchText = ""
    @Published var selectedSeverities: Set<AuditResult.Severity> = []
    @Published var selectedIssueTypes: Set<AuditResult.IssueType> = []
    @Published var selectedDetectionMethods: Set<AuditResult.DetectionMethod> = []
    @Published var dateRange: DateRange = .all
    @Published var confidenceThreshold: Double = 0.0
    @Published var sortBy: SortOption = .dateDescending

    // MARK: - View State
    @Published var selectedIssue: AuditResult?
    @Published var showingFilters = false
    @Published var showingChartsView = false
    @Published var showingReportView = false
    @Published var bulkActionMode = false
    @Published var selectedIssueIds: Set<UUID> = []

    // MARK: - Analysis Results
    @Published var analysisMetrics = AnalysisMetrics()
    @Published var chartData = ChartData()
    @Published var timelineData: [TimelineEntry] = []

    private var cancellables = Set<AnyCancellable>()
    private let userStore: UserStore

    // MARK: - Initialization
    init(userStore: UserStore) {
        self.userStore = userStore
        setupBindings()
        loadData()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Observe changes in search text, filters, and sort options
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            $selectedSeverities,
            $selectedIssueTypes,
            $selectedDetectionMethods
        )
        .combineLatest(
            Publishers.CombineLatest3(
                $dateRange,
                $confidenceThreshold,
                $sortBy
            )
        )
        .sink { [weak self] _ in
            self?.applyFiltersAndSort()
        }
        .store(in: &cancellables)

        // Observe audit results changes from UserStore
        userStore.$auditResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.auditResults = results
                self?.applyFiltersAndSort()
                self?.updateMetrics()
                self?.updateChartData()
                self?.updateTimelineData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading
    func loadData() {
        isLoading = true
        errorMessage = nil

        // In a real app, this would fetch from an API
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.auditResults = self.userStore.auditResults
            self.isLoading = false
        }
    }

    func refreshData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Simulate API call
            try await Task.sleep(nanoseconds: 1_000_000_000)
            await userStore.refreshData()
        } catch {
            errorMessage = "Failed to refresh data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Filtering and Sorting
    private func applyFiltersAndSort() {
        var results = auditResults

        // Apply search filter
        if !searchText.isEmpty {
            results = results.filter { issue in
                issue.title.localizedCaseInsensitiveContains(searchText) ||
                issue.description.localizedCaseInsensitiveContains(searchText) ||
                issue.detailedExplanation.localizedCaseInsensitiveContains(searchText) ||
                issue.issueType.displayName.localizedCaseInsensitiveContains(searchText) ||
                issue.suggestedAction.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply severity filter
        if !selectedSeverities.isEmpty {
            results = results.filter { selectedSeverities.contains($0.severity) }
        }

        // Apply issue type filter
        if !selectedIssueTypes.isEmpty {
            results = results.filter { selectedIssueTypes.contains($0.issueType) }
        }

        // Apply detection method filter
        if !selectedDetectionMethods.isEmpty {
            results = results.filter { selectedDetectionMethods.contains($0.detectionMethod) }
        }

        // Apply date range filter
        if dateRange != .all {
            let calendar = Calendar.current
            let now = Date()
            let startDate: Date

            switch dateRange {
            case .today:
                startDate = calendar.startOfDay(for: now)
            case .thisWeek:
                startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            case .thisMonth:
                startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
            case .lastThreeMonths:
                startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .all:
                startDate = Date.distantPast
            }

            results = results.filter { $0.createdDate >= startDate }
        }

        // Apply confidence threshold filter
        results = results.filter { $0.confidence >= confidenceThreshold }

        // Apply sorting
        results.sort { first, second in
            switch sortBy {
            case .dateDescending:
                return first.createdDate > second.createdDate
            case .dateAscending:
                return first.createdDate < second.createdDate
            case .severityHighToLow:
                if first.severity != second.severity {
                    return severityPriority(first.severity) < severityPriority(second.severity)
                }
                return first.createdDate > second.createdDate
            case .severityLowToHigh:
                if first.severity != second.severity {
                    return severityPriority(first.severity) > severityPriority(second.severity)
                }
                return first.createdDate > second.createdDate
            case .amountHighToLow:
                let firstAmount = first.affectedAmount ?? 0
                let secondAmount = second.affectedAmount ?? 0
                return firstAmount > secondAmount
            case .amountLowToHigh:
                let firstAmount = first.affectedAmount ?? 0
                let secondAmount = second.affectedAmount ?? 0
                return firstAmount < secondAmount
            case .confidenceHighToLow:
                return first.confidence > second.confidence
            case .confidenceLowToHigh:
                return first.confidence < second.confidence
            }
        }

        filteredResults = results
    }

    private func severityPriority(_ severity: AuditResult.Severity) -> Int {
        switch severity {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    // MARK: - Metrics Calculation
    private func updateMetrics() {
        let results = auditResults

        let criticalCount = results.filter { $0.severity == .critical }.count
        let highCount = results.filter { $0.severity == .high }.count
        let mediumCount = results.filter { $0.severity == .medium }.count
        let lowCount = results.filter { $0.severity == .low }.count

        let totalSavings = results.compactMap { $0.affectedAmount }.reduce(0, +)
        let averageConfidence = results.isEmpty ? 0 : results.map { $0.confidence }.reduce(0, +) / Double(results.count)

        let issueTypeDistribution = Dictionary(grouping: results, by: { $0.issueType })
            .mapValues { $0.count }

        let detectionMethodDistribution = Dictionary(grouping: results, by: { $0.detectionMethod })
            .mapValues { $0.count }

        analysisMetrics = AnalysisMetrics(
            totalIssues: results.count,
            criticalIssues: criticalCount,
            highIssues: highCount,
            mediumIssues: mediumCount,
            lowIssues: lowCount,
            totalPotentialSavings: totalSavings,
            averageConfidence: averageConfidence,
            issuesThisMonth: results.filter { Calendar.current.isDate($0.createdDate, equalTo: Date(), toGranularity: .month) }.count,
            issueTypeDistribution: issueTypeDistribution,
            detectionMethodDistribution: detectionMethodDistribution
        )
    }

    private func updateChartData() {
        let results = auditResults

        // Severity distribution
        let severityData = AuditResult.Severity.allCases.map { severity in
            ChartDataPoint(
                name: severity.displayName,
                value: Double(results.filter { $0.severity == severity }.count),
                color: severity.color
            )
        }

        // Issue type distribution
        let issueTypeData = AuditResult.IssueType.allCases.map { type in
            ChartDataPoint(
                name: type.displayName,
                value: Double(results.filter { $0.issueType == type }.count),
                color: .blue
            )
        }

        // Monthly trend data
        let calendar = Calendar.current
        let monthlyTrend = Dictionary(grouping: results) { result in
            calendar.dateInterval(of: .month, for: result.createdDate)?.start ?? result.createdDate
        }
        .map { date, issues in
            TrendDataPoint(
                date: date,
                count: issues.count,
                amount: issues.compactMap { $0.affectedAmount }.reduce(0, +)
            )
        }
        .sorted { $0.date < $1.date }

        // Financial impact over time
        let financialImpact = results
            .filter { $0.affectedAmount != nil }
            .map { result in
                FinancialDataPoint(
                    date: result.createdDate,
                    amount: result.affectedAmount!,
                    severity: result.severity,
                    issueType: result.issueType
                )
            }
            .sorted { $0.date < $1.date }

        chartData = ChartData(
            severityDistribution: severityData,
            issueTypeDistribution: issueTypeData,
            monthlyTrend: monthlyTrend,
            financialImpact: financialImpact
        )
    }

    private func updateTimelineData() {
        timelineData = auditResults
            .sorted { $0.createdDate > $1.createdDate }
            .map { result in
                TimelineEntry(
                    id: result.id,
                    date: result.createdDate,
                    title: result.title,
                    description: result.description,
                    severity: result.severity,
                    issueType: result.issueType,
                    amount: result.affectedAmount
                )
            }
    }

    // MARK: - Filter Management
    func clearAllFilters() {
        searchText = ""
        selectedSeverities.removeAll()
        selectedIssueTypes.removeAll()
        selectedDetectionMethods.removeAll()
        dateRange = .all
        confidenceThreshold = 0.0
        sortBy = .dateDescending
    }

    func toggleSeverityFilter(_ severity: AuditResult.Severity) {
        if selectedSeverities.contains(severity) {
            selectedSeverities.remove(severity)
        } else {
            selectedSeverities.insert(severity)
        }
    }

    func toggleIssueTypeFilter(_ type: AuditResult.IssueType) {
        if selectedIssueTypes.contains(type) {
            selectedIssueTypes.remove(type)
        } else {
            selectedIssueTypes.insert(type)
        }
    }

    func toggleDetectionMethodFilter(_ method: AuditResult.DetectionMethod) {
        if selectedDetectionMethods.contains(method) {
            selectedDetectionMethods.remove(method)
        } else {
            selectedDetectionMethods.insert(method)
        }
    }

    // MARK: - Bulk Actions
    func toggleBulkActionMode() {
        bulkActionMode.toggle()
        if !bulkActionMode {
            selectedIssueIds.removeAll()
        }
    }

    func toggleIssueSelection(_ issueId: UUID) {
        if selectedIssueIds.contains(issueId) {
            selectedIssueIds.remove(issueId)
        } else {
            selectedIssueIds.insert(issueId)
        }
    }

    func selectAllVisibleIssues() {
        selectedIssueIds = Set(filteredResults.map { $0.id })
    }

    func deselectAllIssues() {
        selectedIssueIds.removeAll()
    }

    func performBulkAction(_ action: BulkAction) {
        let selectedIssues = filteredResults.filter { selectedIssueIds.contains($0.id) }

        switch action {
        case .generateLetters:
            generateLettersForIssues(selectedIssues)
        case .markAsResolved:
            markIssuesAsResolved(selectedIssues)
        case .export:
            exportIssues(selectedIssues)
        case .share:
            shareIssues(selectedIssues)
        }

        // Exit bulk action mode after performing action
        bulkActionMode = false
        selectedIssueIds.removeAll()
    }

    // MARK: - Issue Actions
    private func generateLettersForIssues(_ issues: [AuditResult]) {
        // TODO: Implement bulk letter generation
        print("Generating letters for \(issues.count) issues")
    }

    private func markIssuesAsResolved(_ issues: [AuditResult]) {
        // TODO: Implement issue resolution tracking
        print("Marking \(issues.count) issues as resolved")
    }

    private func exportIssues(_ issues: [AuditResult]) {
        // TODO: Implement issue export
        print("Exporting \(issues.count) issues")
    }

    private func shareIssues(_ issues: [AuditResult]) {
        // TODO: Implement issue sharing
        print("Sharing \(issues.count) issues")
    }

    // MARK: - Data Types
    struct AnalysisMetrics {
        var totalIssues = 0
        var criticalIssues = 0
        var highIssues = 0
        var mediumIssues = 0
        var lowIssues = 0
        var totalPotentialSavings = 0.0
        var averageConfidence = 0.0
        var issuesThisMonth = 0
        var issueTypeDistribution: [AuditResult.IssueType: Int] = [:]
        var detectionMethodDistribution: [AuditResult.DetectionMethod: Int] = [:]
    }

    struct ChartData {
        var severityDistribution: [ChartDataPoint] = []
        var issueTypeDistribution: [ChartDataPoint] = []
        var monthlyTrend: [TrendDataPoint] = []
        var financialImpact: [FinancialDataPoint] = []
    }

    struct ChartDataPoint {
        let name: String
        let value: Double
        let color: Color
    }

    struct TrendDataPoint {
        let date: Date
        let count: Int
        let amount: Double
    }

    struct FinancialDataPoint {
        let date: Date
        let amount: Double
        let severity: AuditResult.Severity
        let issueType: AuditResult.IssueType
    }

    struct TimelineEntry {
        let id: UUID
        let date: Date
        let title: String
        let description: String
        let severity: AuditResult.Severity
        let issueType: AuditResult.IssueType
        let amount: Double?
    }

    enum DateRange: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastThreeMonths = "Last 3 Months"
        case all = "All Time"

        var displayName: String { rawValue }
    }

    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case severityHighToLow = "High Severity First"
        case severityLowToHigh = "Low Severity First"
        case amountHighToLow = "Highest Amount First"
        case amountLowToHigh = "Lowest Amount First"
        case confidenceHighToLow = "Highest Confidence First"
        case confidenceLowToHigh = "Lowest Confidence First"

        var displayName: String { rawValue }
    }

    enum BulkAction: String, CaseIterable {
        case generateLetters = "Generate Letters"
        case markAsResolved = "Mark as Resolved"
        case export = "Export"
        case share = "Share"

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .generateLetters: return "doc.text"
            case .markAsResolved: return "checkmark.circle"
            case .export: return "square.and.arrow.up"
            case .share: return "square.and.arrow.up"
            }
        }
    }
}