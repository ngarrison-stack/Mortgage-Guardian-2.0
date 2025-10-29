import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var selectedSeverity: AuditResult.Severity? = nil
    @State private var selectedIssueType: AuditResult.IssueType? = nil
    @State private var searchText = ""
    @State private var showingFilterSheet = false
    @State private var selectedIssue: AuditResult?
    @State private var showingLetterGenerator = false

    private var filteredIssues: [AuditResult] {
        var issues = userStore.auditResults

        // Filter by severity
        if let selectedSeverity = selectedSeverity {
            issues = issues.filter { $0.severity == selectedSeverity }
        }

        // Filter by issue type
        if let selectedIssueType = selectedIssueType {
            issues = issues.filter { $0.issueType == selectedIssueType }
        }

        // Filter by search text
        if !searchText.isEmpty {
            issues = issues.filter { issue in
                issue.title.localizedCaseInsensitiveContains(searchText) ||
                issue.description.localizedCaseInsensitiveContains(searchText) ||
                issue.issueType.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by severity (critical first) then by date
        return issues.sorted { first, second in
            if first.severity != second.severity {
                return severityPriority(first.severity) < severityPriority(second.severity)
            }
            return first.createdDate > second.createdDate
        }
    }

    private func severityPriority(_ severity: AuditResult.Severity) -> Int {
        switch severity {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar

                if userStore.isLoading {
                    LoadingView(message: "Analyzing documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredIssues.isEmpty {
                    emptyStateView
                } else {
                    issuesListView
                }
            }
            .navigationTitle("Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Generate Letter") {
                            showingLetterGenerator = true
                        }

                        Button("Export Report") {
                            exportReport()
                        }

                        Button("Share Analysis") {
                            shareAnalysis()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                AnalysisFilterSheet(
                    selectedSeverity: $selectedSeverity,
                    selectedIssueType: $selectedIssueType,
                    isPresented: $showingFilterSheet
                )
            }
            .sheet(item: $selectedIssue) { issue in
                IssueDetailView(issue: issue)
            }
            .sheet(isPresented: $showingLetterGenerator) {
                LetterGeneratorView()
            }
            .refreshable {
                userStore.refreshData()
            }
        }
    }

    // MARK: - Search and Filter Bar
    @ViewBuilder
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search issues...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
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

            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedSeverity == nil
                        ) {
                            selectedSeverity = nil
                        }

                        ForEach(AuditResult.Severity.allCases, id: \.self) { severity in
                            FilterChip(
                                title: severity.displayName,
                                isSelected: selectedSeverity == severity
                            ) {
                                selectedSeverity = severity
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            Spacer()

            if searchText.isEmpty && selectedSeverity == nil && selectedIssueType == nil {
                EmptyStateView(
                    icon: "checkmark.shield.fill",
                    title: "No Issues Found",
                    message: "Great news! We haven't detected any issues in your mortgage documents. Upload more documents for comprehensive analysis.",
                    actionTitle: "Upload Documents",
                    action: {
                        // TODO: Navigate to documents tab
                    }
                )
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No issues match your search criteria. Try adjusting your filters or search terms.",
                    actionTitle: "Clear Filters",
                    action: {
                        searchText = ""
                        selectedSeverity = nil
                        selectedIssueType = nil
                    }
                )
            }

            Spacer()
        }
    }

    // MARK: - Issues List
    @ViewBuilder
    private var issuesListView: some View {
        List {
            // Summary Section
            Section {
                AnalysisSummaryView(
                    totalIssues: userStore.auditResults.count,
                    criticalIssues: userStore.criticalIssuesCount(),
                    highIssues: userStore.highIssuesCount(),
                    potentialSavings: userStore.totalPotentialSavings()
                )
            }

            // Issues by Severity
            let groupedIssues = Dictionary(grouping: filteredIssues) { $0.severity }
            let sortedGroups = groupedIssues.sorted { first, second in
                severityPriority(first.key) < severityPriority(second.key)
            }

            ForEach(sortedGroups, id: \.key) { severity, issues in
                Section(header: SeveritySectionHeader(severity: severity, count: issues.count)) {
                    ForEach(issues) { issue in
                        IssueRow(auditResult: issue) {
                            selectedIssue = issue
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Generate Letter") {
                                generateLetterForIssue(issue)
                            }
                            .tint(.blue)

                            Button("Share") {
                                shareIssue(issue)
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Actions
    private func exportReport() {
        // TODO: Implement report export
        print("Exporting analysis report")
    }

    private func shareAnalysis() {
        // TODO: Implement analysis sharing
        print("Sharing analysis")
    }

    private func generateLetterForIssue(_ issue: AuditResult) {
        // TODO: Implement letter generation for specific issue
        print("Generating letter for issue: \(issue.title)")
    }

    private func shareIssue(_ issue: AuditResult) {
        // TODO: Implement issue sharing
        print("Sharing issue: \(issue.title)")
    }
}

// MARK: - Analysis Summary View
struct AnalysisSummaryView: View {
    let totalIssues: Int
    let criticalIssues: Int
    let highIssues: Int
    let potentialSavings: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(totalIssues)")
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Potential Savings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(potentialSavings))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 16) {
                SeverityCountView(
                    severity: .critical,
                    count: criticalIssues,
                    icon: "exclamationmark.triangle.fill"
                )

                SeverityCountView(
                    severity: .high,
                    count: highIssues,
                    icon: "exclamationmark.circle.fill"
                )

                Spacer()
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

// MARK: - Severity Count View
struct SeverityCountView: View {
    let severity: AuditResult.Severity
    let count: Int
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(severity.color)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(severity.color)

                Text(severity.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Severity Section Header
struct SeveritySectionHeader: View {
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

// MARK: - Analysis Filter Sheet
struct AnalysisFilterSheet: View {
    @Binding var selectedSeverity: AuditResult.Severity?
    @Binding var selectedIssueType: AuditResult.IssueType?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                Section("Severity") {
                    Button("All Severities") {
                        selectedSeverity = nil
                    }
                    .foregroundColor(selectedSeverity == nil ? .blue : .primary)

                    ForEach(AuditResult.Severity.allCases, id: \.self) { severity in
                        Button(severity.displayName) {
                            selectedSeverity = severity
                        }
                        .foregroundColor(selectedSeverity == severity ? .blue : .primary)
                    }
                }

                Section("Issue Type") {
                    Button("All Types") {
                        selectedIssueType = nil
                    }
                    .foregroundColor(selectedIssueType == nil ? .blue : .primary)

                    ForEach(AuditResult.IssueType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            selectedIssueType = type
                        }
                        .foregroundColor(selectedIssueType == type ? .blue : .primary)
                    }
                }
            }
            .navigationTitle("Filter Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedSeverity = nil
                        selectedIssueType = nil
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Issue Detail View
struct IssueDetailView: View {
    let issue: AuditResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Issue Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: issue.issueType.icon)
                                .foregroundColor(issue.severity.color)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Text(issue.issueType.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(issue.severity.displayName.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(issue.severity.color.opacity(0.2))
                                )
                                .foregroundColor(issue.severity.color)
                        }

                        if let amount = issue.affectedAmount {
                            Text("Potential savings: \(formatCurrency(amount))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(issue.description)
                            .font(.body)
                    }

                    // Detailed Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detailed Explanation")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(issue.detailedExplanation)
                            .font(.body)
                    }

                    // Suggested Action
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Action")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(issue.suggestedAction)
                            .font(.body)
                    }

                    // Calculation Details
                    if let calculationDetails = issue.calculationDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calculation Details")
                                .font(.headline)
                                .fontWeight(.semibold)

                            if let expectedValue = calculationDetails.expectedValue,
                               let actualValue = calculationDetails.actualValue {
                                HStack {
                                    Text("Expected:")
                                    Spacer()
                                    Text(formatCurrency(expectedValue))
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("Actual:")
                                    Spacer()
                                    Text(formatCurrency(actualValue))
                                        .fontWeight(.medium)
                                }

                                if let difference = calculationDetails.difference {
                                    HStack {
                                        Text("Difference:")
                                        Spacer()
                                        Text(formatCurrency(difference))
                                            .fontWeight(.medium)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }

                    // Detection Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Information")
                            .font(.headline)
                            .fontWeight(.semibold)

                        HStack {
                            Text("Method:")
                            Spacer()
                            Text(issue.detectionMethod.displayName)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Confidence:")
                            Spacer()
                            Text("\(Int(issue.confidence * 100))%")
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Detected:")
                            Spacer()
                            Text(formatDate(issue.createdDate))
                                .fontWeight(.medium)
                        }
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button("Generate Notice of Error Letter") {
                            // TODO: Implement letter generation
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Share Issue") {
                            // TODO: Implement sharing
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Issue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Letter Generator View (Placeholder)
struct LetterGeneratorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Letter Generator")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Generate a formal Notice of Error letter to send to your mortgage servicer regarding the identified issues.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button("Generate Letter") {
                        // TODO: Implement letter generation
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Generate Letter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AnalysisView()
        .environmentObject(UserStore())
}