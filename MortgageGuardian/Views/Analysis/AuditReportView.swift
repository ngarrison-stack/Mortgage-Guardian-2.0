import SwiftUI
import PDFKit

/// Comprehensive audit report view with professional formatting and export capabilities
struct AuditReportView: View {
    let viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reportStyle: ReportStyle = .comprehensive
    @State private var includeCharts = true
    @State private var includeEvidence = true
    @State private var includeCalculations = true
    @State private var includeRecommendations = true
    @State private var selectedSeverities: Set<AuditResult.Severity> = Set(AuditResult.Severity.allCases)
    @State private var customDateRange: DateRange?

    @State private var isGeneratingReport = false
    @State private var showingPreview = false
    @State private var showingShareSheet = false
    @State private var generatedReportData: Data?
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    reportHeaderSection

                    // Report Configuration
                    reportConfigurationSection

                    // Content Options
                    contentOptionsSection

                    // Filtering Options
                    filteringOptionsSection

                    // Preview Section
                    if !isGeneratingReport {
                        previewSection
                    }

                    // Generation Status
                    if isGeneratingReport {
                        generationStatusSection
                    }
                }
                .padding()
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingPreview) {
                if let reportData = generatedReportData {
                    ReportPreviewView(reportData: reportData)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Header Section
    @ViewBuilder
    private var reportHeaderSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Mortgage Audit Report")
                .font(.title)
                .fontWeight(.bold)

            Text("Generate a comprehensive analysis report of your mortgage servicing issues")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Quick Stats
            HStack(spacing: 20) {
                QuickStat(
                    value: "\(viewModel.analysisMetrics.totalIssues)",
                    label: "Total Issues",
                    color: .blue
                )

                QuickStat(
                    value: formatCurrency(viewModel.analysisMetrics.totalPotentialSavings),
                    label: "Potential Savings",
                    color: .green
                )

                QuickStat(
                    value: "\(viewModel.analysisMetrics.criticalIssues)",
                    label: "Critical Issues",
                    color: .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Report Configuration
    @ViewBuilder
    private var reportConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Report Configuration", icon: "gearshape")

            VStack(spacing: 12) {
                // Report Style
                HStack {
                    Text("Report Style")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Picker("Style", selection: $reportStyle) {
                        ForEach(ReportStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 200)
                }

                // Report Description
                Text(reportStyle.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Content Options
    @ViewBuilder
    private var contentOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Include in Report", icon: "checklist")

            VStack(spacing: 12) {
                ToggleRow(
                    title: "Charts and Visualizations",
                    subtitle: "Include analysis charts and graphs",
                    isOn: $includeCharts
                )

                ToggleRow(
                    title: "Evidence Documentation",
                    subtitle: "Include supporting evidence and screenshots",
                    isOn: $includeEvidence
                )

                ToggleRow(
                    title: "Calculation Details",
                    subtitle: "Include detailed calculations and formulas",
                    isOn: $includeCalculations
                )

                ToggleRow(
                    title: "Action Recommendations",
                    subtitle: "Include suggested actions and next steps",
                    isOn: $includeRecommendations
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Filtering Options
    @ViewBuilder
    private var filteringOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Filter Issues", icon: "line.3.horizontal.decrease")

            VStack(spacing: 12) {
                // Severity Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Severity Levels")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(AuditResult.Severity.allCases, id: \.self) { severity in
                            SeverityToggle(
                                severity: severity,
                                isSelected: selectedSeverities.contains(severity)
                            ) {
                                toggleSeverity(severity)
                            }
                        }
                    }
                }

                Divider()

                // Date Range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Range")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("All detected issues")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Customize") {
                            // TODO: Implement custom date range picker
                        }
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

    // MARK: - Preview Section
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Report Preview", icon: "eye")

            ReportPreviewCard(
                style: reportStyle,
                issueCount: filteredIssues.count,
                totalSavings: filteredTotalSavings,
                includeCharts: includeCharts,
                includeEvidence: includeEvidence
            )

            // Generate Button
            Button {
                generateReport()
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Generate Report")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedSeverities.isEmpty)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Generation Status
    @ViewBuilder
    private var generationStatusSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Generating Report...")
                .font(.headline)
                .fontWeight(.medium)

            Text("Compiling analysis data and formatting your comprehensive mortgage audit report")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if generatedReportData != nil {
                Menu {
                    Button {
                        showingPreview = true
                    } label: {
                        Label("Preview Report", systemImage: "eye")
                    }

                    Button {
                        shareReport()
                    } label: {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        saveReport()
                    } label: {
                        Label("Save to Files", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var filteredIssues: [AuditResult] {
        viewModel.auditResults.filter { selectedSeverities.contains($0.severity) }
    }

    private var filteredTotalSavings: Double {
        filteredIssues.compactMap { $0.affectedAmount }.reduce(0, +)
    }

    // MARK: - Actions
    private func toggleSeverity(_ severity: AuditResult.Severity) {
        if selectedSeverities.contains(severity) {
            selectedSeverities.remove(severity)
        } else {
            selectedSeverities.insert(severity)
        }
    }

    private func generateReport() {
        isGeneratingReport = true

        // Simulate report generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let reportGenerator = ReportGenerator(
                issues: filteredIssues,
                metrics: viewModel.analysisMetrics,
                style: reportStyle,
                options: ReportOptions(
                    includeCharts: includeCharts,
                    includeEvidence: includeEvidence,
                    includeCalculations: includeCalculations,
                    includeRecommendations: includeRecommendations
                )
            )

            generatedReportData = reportGenerator.generatePDF()
            isGeneratingReport = false
        }
    }

    private func shareReport() {
        guard let reportData = generatedReportData else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MortgageAuditReport_\(Date().timeIntervalSince1970).pdf")

        do {
            try reportData.write(to: tempURL)
            shareItems = [tempURL]
            showingShareSheet = true
        } catch {
            print("Error sharing report: \(error)")
        }
    }

    private func saveReport() {
        // TODO: Implement save to files functionality
        print("Saving report to Files app")
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types

enum ReportStyle: String, CaseIterable {
    case summary = "Summary"
    case comprehensive = "Comprehensive"
    case legal = "Legal"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .summary:
            return "A concise overview of key findings and recommendations"
        case .comprehensive:
            return "Detailed analysis with complete documentation and evidence"
        case .legal:
            return "Formal report suitable for legal proceedings and complaints"
        }
    }
}

struct ReportOptions {
    let includeCharts: Bool
    let includeEvidence: Bool
    let includeCalculations: Bool
    let includeRecommendations: Bool
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()
        }
    }
}

struct QuickStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct SeverityToggle: View {
    let severity: AuditResult.Severity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? severity.color : .secondary)

                Text(severity.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? severity.color : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReportPreviewCard: View {
    let style: ReportStyle
    let issueCount: Int
    let totalSavings: Double
    let includeCharts: Bool
    let includeEvidence: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Report Preview")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(style.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                PreviewRow(label: "Issues included", value: "\(issueCount)")
                PreviewRow(label: "Total potential savings", value: formatCurrency(totalSavings))
                PreviewRow(label: "Charts included", value: includeCharts ? "Yes" : "No")
                PreviewRow(label: "Evidence included", value: includeEvidence ? "Yes" : "No")
            }

            Text(estimatedPageCount)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        )
    }

    private var estimatedPageCount: String {
        var pages = 2 // Base pages
        pages += issueCount / 3 // Issues per page
        if includeCharts { pages += 2 }
        if includeEvidence { pages += issueCount / 2 }
        return "Estimated \(pages) pages"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Report Generator
class ReportGenerator {
    private let issues: [AuditResult]
    private let metrics: AnalysisViewModel.AnalysisMetrics
    private let style: ReportStyle
    private let options: ReportOptions

    init(issues: [AuditResult], metrics: AnalysisViewModel.AnalysisMetrics, style: ReportStyle, options: ReportOptions) {
        self.issues = issues
        self.metrics = metrics
        self.style = style
        self.options = options
    }

    func generatePDF() -> Data {
        // This is a mock implementation
        // In a real app, you would use PDFKit or similar to generate actual PDF content
        let mockPDFContent = """
        MORTGAGE AUDIT REPORT
        Generated: \(Date())

        EXECUTIVE SUMMARY
        Total Issues Found: \(issues.count)
        Critical Issues: \(metrics.criticalIssues)
        High Severity Issues: \(metrics.highIssues)
        Total Potential Savings: \(formatCurrency(metrics.totalPotentialSavings))

        DETAILED FINDINGS
        \(issues.map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))

        RECOMMENDATIONS
        - Review all identified issues with your mortgage servicer
        - Send formal Notice of Error letters for critical issues
        - Maintain detailed records of all communications
        - Consider filing CFPB complaint if issues persist

        Report generated by Mortgage Guardian
        """

        return mockPDFContent.data(using: .utf8) ?? Data()
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Report Preview View
struct ReportPreviewView: View {
    let reportData: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(String(data: reportData, encoding: .utf8) ?? "Unable to preview report")
                    .font(.caption)
                    .padding()
            }
            .navigationTitle("Report Preview")
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
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AuditReportView(viewModel: AnalysisViewModel(userStore: UserStore()))
}