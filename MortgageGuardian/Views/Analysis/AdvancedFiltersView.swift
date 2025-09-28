import SwiftUI

/// Advanced filtering interface for sophisticated issue analysis
struct AdvancedFiltersView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var hasUnsavedChanges = false

    var body: some View {
        NavigationView {
            List {
                // Severity Filters
                Section("Severity Levels") {
                    ForEach(AuditResult.Severity.allCases, id: \.self) { severity in
                        FilterToggleRow(
                            title: severity.displayName,
                            subtitle: "\(severityCount(severity)) issues",
                            isSelected: viewModel.selectedSeverities.contains(severity),
                            color: severity.color
                        ) {
                            viewModel.toggleSeverityFilter(severity)
                            hasUnsavedChanges = true
                        }
                    }
                }

                // Issue Type Filters
                Section("Issue Types") {
                    ForEach(AuditResult.IssueType.allCases, id: \.self) { issueType in
                        FilterToggleRow(
                            title: issueType.displayName,
                            subtitle: "\(issueTypeCount(issueType)) issues",
                            isSelected: viewModel.selectedIssueTypes.contains(issueType),
                            color: .blue
                        ) {
                            viewModel.toggleIssueTypeFilter(issueType)
                            hasUnsavedChanges = true
                        }
                    }
                }

                // Detection Method Filters
                Section("Detection Methods") {
                    ForEach(AuditResult.DetectionMethod.allCases, id: \.self) { method in
                        FilterToggleRow(
                            title: method.displayName,
                            subtitle: "\(detectionMethodCount(method)) issues",
                            isSelected: viewModel.selectedDetectionMethods.contains(method),
                            color: .purple
                        ) {
                            viewModel.toggleDetectionMethodFilter(method)
                            hasUnsavedChanges = true
                        }
                    }
                }

                // Date Range Filter
                Section("Date Range") {
                    ForEach(AnalysisViewModel.DateRange.allCases, id: \.self) { range in
                        HStack {
                            Text(range.displayName)
                            Spacer()
                            if viewModel.dateRange == range {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.dateRange = range
                            hasUnsavedChanges = true
                        }
                    }
                }

                // Confidence Threshold
                Section("Confidence Threshold") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum Confidence")
                            Spacer()
                            Text("\(Int(viewModel.confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $viewModel.confidenceThreshold,
                            in: 0...1,
                            step: 0.1
                        ) {
                            hasUnsavedChanges = true
                        }
                        .accentColor(.blue)

                        Text("Only show issues with confidence above this threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Sort Options
                Section("Sort Order") {
                    ForEach(AnalysisViewModel.SortOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.displayName)
                            Spacer()
                            if viewModel.sortBy == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.sortBy = option
                            hasUnsavedChanges = true
                        }
                    }
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .confirmationDialog(
                "Unsaved Changes",
                isPresented: .constant(false), // We'll handle this manually
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved filter changes. Are you sure you want to discard them?")
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Clear All") {
                viewModel.clearAllFilters()
                hasUnsavedChanges = true
            }
            .disabled(isFiltersEmpty)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                dismiss()
            }
        }
    }

    // MARK: - Computed Properties
    private var isFiltersEmpty: Bool {
        viewModel.selectedSeverities.isEmpty &&
        viewModel.selectedIssueTypes.isEmpty &&
        viewModel.selectedDetectionMethods.isEmpty &&
        viewModel.dateRange == .all &&
        viewModel.confidenceThreshold == 0.0 &&
        viewModel.sortBy == .dateDescending
    }

    // MARK: - Helper Functions
    private func severityCount(_ severity: AuditResult.Severity) -> Int {
        viewModel.auditResults.filter { $0.severity == severity }.count
    }

    private func issueTypeCount(_ issueType: AuditResult.IssueType) -> Int {
        viewModel.auditResults.filter { $0.issueType == issueType }.count
    }

    private func detectionMethodCount(_ method: AuditResult.DetectionMethod) -> Int {
        viewModel.auditResults.filter { $0.detectionMethod == method }.count
    }
}

// MARK: - Supporting Views

struct FilterToggleRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .secondary)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AdvancedFiltersView(viewModel: AnalysisViewModel(userStore: UserStore()))
}