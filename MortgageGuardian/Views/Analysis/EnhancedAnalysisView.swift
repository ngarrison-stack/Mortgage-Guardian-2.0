import SwiftUI
import Charts

/// Enhanced analysis view with sophisticated issue categorization, filtering, and visualization
struct EnhancedAnalysisView: View {
    @StateObject private var viewModel: AnalysisViewModel
    @EnvironmentObject var userStore: UserStore
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showingNewFeatureAlert = false

    init(userStore: UserStore) {
        self._viewModel = StateObject(wrappedValue: AnalysisViewModel(userStore: userStore))
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    LoadingView(message: "Analyzing mortgage documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Enhanced Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                AdvancedFiltersView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingChartsView) {
                AnalysisChartsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingReportView) {
                AuditReportView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedIssue) { issue in
                IssueDetailView(issue: issue, viewModel: viewModel)
            }
            .alert("Enhanced Analysis", isPresented: $showingNewFeatureAlert) {
                Button("OK") { }
            } message: {
                Text("Welcome to the enhanced analysis experience with advanced filtering, charts, and comprehensive reporting!")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasSeenEnhancedAnalysis") {
                showingNewFeatureAlert = true
                UserDefaults.standard.set(true, forKey: "hasSeenEnhancedAnalysis")
            }
        }
    }

    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Search and Quick Filters
            searchAndQuickFiltersSection
                .background(Color(.systemBackground))

            if viewModel.filteredResults.isEmpty {
                emptyStateView
            } else {
                // Results Content
                if horizontalSizeClass == .regular {
                    // iPad Layout - Side by side
                    HSplitView {
                        resultsListView
                            .frame(minWidth: 400)

                        if let selectedIssue = viewModel.selectedIssue {
                            IssueDetailView(issue: selectedIssue, viewModel: viewModel)
                        } else {
                            VStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Select an issue to view details")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                } else {
                    // iPhone Layout - Full screen list
                    resultsListView
                }
            }
        }
    }

    // MARK: - Search and Quick Filters
    @ViewBuilder
    private var searchAndQuickFiltersSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search issues, descriptions, actions...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !viewModel.searchText.isEmpty {
                    Button("Clear") {
                        viewModel.searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )

            // Quick Filters and Sort
            HStack {
                // Severity Quick Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickFilterChip(
                            title: "All",
                            count: viewModel.auditResults.count,
                            isSelected: viewModel.selectedSeverities.isEmpty,
                            color: .blue
                        ) {
                            viewModel.selectedSeverities.removeAll()
                        }

                        ForEach(AuditResult.Severity.allCases, id: \.self) { severity in
                            let count = viewModel.auditResults.filter { $0.severity == severity }.count
                            QuickFilterChip(
                                title: severity.displayName,
                                count: count,
                                isSelected: viewModel.selectedSeverities.contains(severity),
                                color: severity.color
                            ) {
                                viewModel.toggleSeverityFilter(severity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 8) {
                    Button {
                        viewModel.showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }

                    Button {
                        viewModel.toggleBulkActionMode()
                    } label: {
                        Image(systemName: viewModel.bulkActionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundColor(viewModel.bulkActionMode ? .blue : .secondary)
                    }
                }
                .padding(.trailing)
            }

            // Active Filters Summary
            if !viewModel.selectedSeverities.isEmpty || !viewModel.selectedIssueTypes.isEmpty || viewModel.dateRange != .all {
                activeFiltersSection
            }

            // Bulk Action Bar
            if viewModel.bulkActionMode {
                bulkActionBar
            }
        }
        .padding(.vertical)
    }

    // MARK: - Active Filters
    @ViewBuilder
    private var activeFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Selected Severities
                ForEach(Array(viewModel.selectedSeverities), id: \.self) { severity in
                    ActiveFilterChip(
                        title: severity.displayName,
                        color: severity.color
                    ) {
                        viewModel.toggleSeverityFilter(severity)
                    }
                }

                // Selected Issue Types
                ForEach(Array(viewModel.selectedIssueTypes), id: \.self) { type in
                    ActiveFilterChip(
                        title: type.displayName,
                        color: .blue
                    ) {
                        viewModel.toggleIssueTypeFilter(type)
                    }
                }

                // Date Range
                if viewModel.dateRange != .all {
                    ActiveFilterChip(
                        title: viewModel.dateRange.displayName,
                        color: .purple
                    ) {
                        viewModel.dateRange = .all
                    }
                }

                // Clear All
                Button("Clear All") {
                    viewModel.clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Bulk Action Bar
    @ViewBuilder
    private var bulkActionBar: some View {
        HStack {
            Text("\(viewModel.selectedIssueIds.count) selected")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            if !viewModel.selectedIssueIds.isEmpty {
                HStack(spacing: 12) {
                    ForEach(AnalysisViewModel.BulkAction.allCases, id: \.self) { action in
                        Button {
                            viewModel.performBulkAction(action)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: action.icon)
                                Text(action.displayName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Button("Done") {
                viewModel.toggleBulkActionMode()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Results List
    @ViewBuilder
    private var resultsListView: some View {
        List {
            // Summary Section
            Section {
                EnhancedSummarySection(metrics: viewModel.analysisMetrics, viewModel: viewModel)
            }

            // Results Section
            Section {
                if viewModel.filteredResults.isEmpty {
                    ContentUnavailableView {
                        Label("No matching issues", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try adjusting your search terms or filters")
                    }
                } else {
                    ForEach(groupedResults, id: \.severity) { group in
                        DisclosureGroup(isExpanded: .constant(true)) {
                            ForEach(group.issues) { issue in
                                EnhancedIssueCard(
                                    issue: issue,
                                    isSelected: viewModel.selectedIssueIds.contains(issue.id),
                                    bulkActionMode: viewModel.bulkActionMode,
                                    onTap: {
                                        if viewModel.bulkActionMode {
                                            viewModel.toggleIssueSelection(issue.id)
                                        } else {
                                            viewModel.selectedIssue = issue
                                        }
                                    },
                                    onToggleSelection: {
                                        viewModel.toggleIssueSelection(issue.id)
                                    }
                                )
                            }
                        } label: {
                            SeverityGroupHeader(severity: group.severity, count: group.issues.count)
                        }
                    }
                }
            } header: {
                resultsHeader
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Results Header
    @ViewBuilder
    private var resultsHeader: some View {
        HStack {
            Text("\(viewModel.filteredResults.count) Issues")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Menu {
                ForEach(AnalysisViewModel.SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortBy = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            if viewModel.auditResults.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No Issues Found",
                    message: "Great news! We haven't detected any issues in your mortgage documents. Upload more documents for comprehensive analysis.",
                    actionTitle: "Upload Documents"
                ) {
                    // Navigate to documents
                }
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Matching Results",
                    message: "No issues match your current search and filter criteria. Try adjusting your filters or search terms.",
                    actionTitle: "Clear Filters"
                ) {
                    viewModel.clearAllFilters()
                }
            }

            Spacer()
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    viewModel.showingChartsView = true
                } label: {
                    Label("View Charts", systemImage: "chart.pie")
                }

                Button {
                    viewModel.showingReportView = true
                } label: {
                    Label("Generate Report", systemImage: "doc.text")
                }

                Divider()

                Button {
                    exportAllIssues()
                } label: {
                    Label("Export All", systemImage: "square.and.arrow.up")
                }

                Button {
                    shareAnalysis()
                } label: {
                    Label("Share Analysis", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.bulkActionMode {
                Button {
                    if viewModel.selectedIssueIds.count == viewModel.filteredResults.count {
                        viewModel.deselectAllIssues()
                    } else {
                        viewModel.selectAllVisibleIssues()
                    }
                } label: {
                    Text(viewModel.selectedIssueIds.count == viewModel.filteredResults.count ? "Deselect All" : "Select All")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var groupedResults: [(severity: AuditResult.Severity, issues: [AuditResult])] {
        let grouped = Dictionary(grouping: viewModel.filteredResults) { $0.severity }
        return AuditResult.Severity.allCases.compactMap { severity in
            guard let issues = grouped[severity], !issues.isEmpty else { return nil }
            return (severity: severity, issues: issues)
        }
    }

    // MARK: - Actions
    private func exportAllIssues() {
        // TODO: Implement export functionality
        print("Exporting all issues")
    }

    private func shareAnalysis() {
        // TODO: Implement sharing functionality
        print("Sharing analysis")
    }
}

// MARK: - Supporting Views

/// Quick filter chip with count indicator
struct QuickFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 4)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : color)
        }
    }
}

/// Active filter chip with remove button
struct ActiveFilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: 1)
                )
        )
        .foregroundColor(color)
    }
}

/// Enhanced summary section with metrics and quick actions
struct EnhancedSummarySection: View {
    let metrics: AnalysisViewModel.AnalysisMetrics
    let viewModel: AnalysisViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Key Metrics
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(metrics.totalIssues)")
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Potential Savings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(metrics.totalPotentialSavings))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }

            // Severity Breakdown
            HStack(spacing: 12) {
                SeverityMetricView(
                    severity: .critical,
                    count: metrics.criticalIssues,
                    total: metrics.totalIssues
                )

                SeverityMetricView(
                    severity: .high,
                    count: metrics.highIssues,
                    total: metrics.totalIssues
                )

                Spacer()

                // Quick Actions
                HStack(spacing: 8) {
                    Button {
                        viewModel.showingChartsView = true
                    } label: {
                        Image(systemName: "chart.pie")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Button {
                        viewModel.showingReportView = true
                    } label: {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

/// Severity metric view with progress indicator
struct SeverityMetricView: View {
    let severity: AuditResult.Severity
    let count: Int
    let total: Int

    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(severity.color)
                    .frame(width: 8, height: 8)

                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(severity.color)
            }

            Text(severity.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)

            if count > 0 {
                ProgressView(value: percentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: severity.color))
                    .frame(width: 40)
            }
        }
    }
}

/// Severity group header
struct SeverityGroupHeader: View {
    let severity: AuditResult.Severity
    let count: Int

    var body: some View {
        HStack {
            Circle()
                .fill(severity.color)
                .frame(width: 8, height: 8)

            Text(severity.displayName.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(severity.color)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    EnhancedAnalysisView(userStore: UserStore())
        .environmentObject(UserStore())
}