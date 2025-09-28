import SwiftUI
import QuickLook

/// Comprehensive issue detail view with evidence presentation and action recommendations
struct IssueDetailView: View {
    let issue: AuditResult
    let viewModel: AnalysisViewModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedTab: DetailTab = .overview
    @State private var showingLetterGenerator = false
    @State private var showingDocumentViewer = false
    @State private var showingShareSheet = false
    @State private var showingEvidenceHighlight = false
    @State private var expandedSections: Set<String> = ["overview", "calculation"]
    @State private var shareItems: [Any] = []

    init(issue: AuditResult, viewModel: AnalysisViewModel? = nil) {
        self.issue = issue
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header Section
                        issueHeaderSection

                        // Tab Selection (for smaller screens)
                        if horizontalSizeClass == .compact {
                            tabSelectionSection
                        }

                        // Content Sections
                        if horizontalSizeClass == .regular {
                            // iPad: Side-by-side layout
                            HSplitView {
                                leftColumnContent
                                    .frame(minWidth: 400)
                                rightColumnContent
                                    .frame(minWidth: 300)
                            }
                            .frame(minHeight: 600)
                        } else {
                            // iPhone: Stacked layout
                            VStack(spacing: 0) {
                                switch selectedTab {
                                case .overview:
                                    overviewContent
                                case .evidence:
                                    evidenceContent
                                case .calculation:
                                    calculationContent
                                case .timeline:
                                    timelineContent
                                case .actions:
                                    actionsContent
                                }
                            }
                        }

                        // Action Buttons
                        actionButtonsSection
                            .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Issue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .sheet(isPresented: $showingLetterGenerator) {
            IssueLetterGeneratorView(issue: issue)
        }
        .sheet(isPresented: $showingDocumentViewer) {
            DocumentEvidenceViewer(issue: issue)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .onAppear {
            setupShareItems()
        }
    }

    // MARK: - Header Section
    @ViewBuilder
    private var issueHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Severity
            HStack(alignment: .top, spacing: 12) {
                // Issue Icon
                ZStack {
                    Circle()
                        .fill(issue.severity.color.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Circle()
                        .stroke(issue.severity.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 56, height: 56)

                    Image(systemName: issue.issueType.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(issue.severity.color)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(issue.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    HStack {
                        SeverityBadge(severity: issue.severity)

                        Spacer()

                        if let amount = issue.affectedAmount {
                            FinancialImpactBadge(amount: amount)
                        }
                    }

                    Text(issue.issueType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Key Metrics Row
            keyMetricsRow
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Key Metrics Row
    @ViewBuilder
    private var keyMetricsRow: some View {
        HStack(spacing: 20) {
            MetricView(
                title: "Confidence",
                value: "\(Int(issue.confidence * 100))%",
                icon: "gauge.medium",
                color: confidenceColor
            )

            MetricView(
                title: "Detected",
                value: formatShortDate(issue.createdDate),
                icon: "calendar",
                color: .blue
            )

            MetricView(
                title: "Method",
                value: issue.detectionMethod.displayName,
                icon: detectionMethodIcon,
                color: .purple
            )
        }
    }

    // MARK: - Tab Selection
    @ViewBuilder
    private var tabSelectionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    // MARK: - Content Sections for iPad
    @ViewBuilder
    private var leftColumnContent: some View {
        VStack(spacing: 20) {
            overviewContent
            calculationContent
        }
        .padding()
    }

    @ViewBuilder
    private var rightColumnContent: some View {
        VStack(spacing: 20) {
            evidenceContent
            timelineContent
            actionsContent
        }
        .padding()
    }

    // MARK: - Overview Content
    @ViewBuilder
    private var overviewContent: some View {
        ExpandableSection(
            title: "Overview",
            icon: "info.circle",
            isExpanded: expandedSections.contains("overview")
        ) {
            toggleSection("overview")
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                DetailTextSection(
                    title: "Description",
                    content: issue.description,
                    style: .body
                )

                DetailTextSection(
                    title: "Detailed Explanation",
                    content: issue.detailedExplanation,
                    style: .body
                )

                DetailTextSection(
                    title: "Suggested Action",
                    content: issue.suggestedAction,
                    style: .callout,
                    backgroundColor: Color.blue.opacity(0.1)
                )
            }
        }
    }

    // MARK: - Evidence Content
    @ViewBuilder
    private var evidenceContent: some View {
        ExpandableSection(
            title: "Evidence",
            icon: "doc.text.magnifyingglass",
            isExpanded: expandedSections.contains("evidence")
        ) {
            toggleSection("evidence")
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                if let evidenceText = issue.evidenceText {
                    EvidenceTextView(text: evidenceText)
                } else {
                    EmptyEvidenceView()
                }

                // Supporting Documents Section
                supportingDocumentsSection

                // Evidence Highlight Button
                Button {
                    showingEvidenceHighlight = true
                } label: {
                    HStack {
                        Image(systemName: "highlighter")
                        Text("View Highlighted Evidence")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Calculation Content
    @ViewBuilder
    private var calculationContent: some View {
        ExpandableSection(
            title: "Calculations",
            icon: "calculator",
            isExpanded: expandedSections.contains("calculation")
        ) {
            toggleSection("calculation")
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                if let calcDetails = issue.calculationDetails {
                    CalculationDetailsView(details: calcDetails)
                } else {
                    Text("No calculation details available for this issue.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Timeline Content
    @ViewBuilder
    private var timelineContent: some View {
        ExpandableSection(
            title: "Timeline",
            icon: "clock",
            isExpanded: expandedSections.contains("timeline")
        ) {
            toggleSection("timeline")
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                TimelineEvent(
                    date: issue.createdDate,
                    title: "Issue Detected",
                    description: "Automated analysis identified this issue using \(issue.detectionMethod.displayName)",
                    icon: "magnifyingglass",
                    color: .blue
                )

                // Additional timeline events based on issue type
                additionalTimelineEvents
            }
        }
    }

    // MARK: - Actions Content
    @ViewBuilder
    private var actionsContent: some View {
        ExpandableSection(
            title: "Recommended Actions",
            icon: "list.bullet.clipboard",
            isExpanded: expandedSections.contains("actions")
        ) {
            toggleSection("actions")
        } content: {
            VStack(spacing: 12) {
                ActionRecommendationCard(
                    title: "Generate Notice of Error Letter",
                    description: "Create a formal letter to your mortgage servicer",
                    priority: .high,
                    action: { showingLetterGenerator = true }
                )

                ActionRecommendationCard(
                    title: "Document the Issue",
                    description: "Save evidence and create a paper trail",
                    priority: .medium,
                    action: { documentIssue() }
                )

                ActionRecommendationCard(
                    title: "Contact Servicer",
                    description: "Call or email your mortgage servicer directly",
                    priority: .medium,
                    action: { contactServicer() }
                )

                ActionRecommendationCard(
                    title: "File Complaint",
                    description: "Submit a complaint to CFPB if needed",
                    priority: .low,
                    action: { fileComplaint() }
                )
            }
        }
    }

    // MARK: - Supporting Documents
    @ViewBuilder
    private var supportingDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supporting Documents")
                .font(.headline)
                .fontWeight(.semibold)

            // Mock document references - in real app, would show actual documents
            ForEach(mockSupportingDocuments, id: \.name) { document in
                DocumentReferenceRow(document: document) {
                    showingDocumentViewer = true
                }
            }
        }
    }

    // MARK: - Additional Timeline Events
    @ViewBuilder
    private var additionalTimelineEvents: some View {
        // Mock additional events based on issue type
        switch issue.issueType {
        case .latePaymentError:
            TimelineEvent(
                date: Calendar.current.date(byAdding: .day, value: -5, to: issue.createdDate) ?? issue.createdDate,
                title: "Payment Sent",
                description: "Payment was initiated from your bank account",
                icon: "arrow.up.circle",
                color: .green
            )

            TimelineEvent(
                date: Calendar.current.date(byAdding: .day, value: -2, to: issue.createdDate) ?? issue.createdDate,
                title: "Late Fee Applied",
                description: "Servicer incorrectly applied a late payment fee",
                icon: "exclamationmark.triangle",
                color: .red
            )

        case .escrowError:
            TimelineEvent(
                date: Calendar.current.date(byAdding: .month, value: -1, to: issue.createdDate) ?? issue.createdDate,
                title: "Escrow Analysis Received",
                description: "Annual escrow analysis statement was received",
                icon: "doc.text",
                color: .orange
            )

        default:
            EmptyView()
        }
    }

    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary Action
            Button {
                showingLetterGenerator = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Generate Letter")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Secondary Actions
            HStack(spacing: 12) {
                Button {
                    showingShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    markAsResolved()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Mark Resolved")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
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
            Menu {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share Issue", systemImage: "square.and.arrow.up")
                }

                Button {
                    exportIssue()
                } label: {
                    Label("Export PDF", systemImage: "doc.text")
                }

                Button {
                    markAsResolved()
                } label: {
                    Label("Mark as Resolved", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helper Functions
    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func setupShareItems() {
        let issueText = """
        Issue: \(issue.title)
        Type: \(issue.issueType.displayName)
        Severity: \(issue.severity.displayName)
        Description: \(issue.description)
        Suggested Action: \(issue.suggestedAction)
        """
        shareItems = [issueText]
    }

    private func documentIssue() {
        // TODO: Implement documentation functionality
        print("Documenting issue")
    }

    private func contactServicer() {
        // TODO: Implement servicer contact functionality
        print("Contacting servicer")
    }

    private func fileComplaint() {
        // TODO: Implement CFPB complaint functionality
        print("Filing complaint")
    }

    private func markAsResolved() {
        // TODO: Implement resolution tracking
        print("Marking issue as resolved")
    }

    private func exportIssue() {
        // TODO: Implement PDF export
        print("Exporting issue to PDF")
    }

    // MARK: - Computed Properties
    private var confidenceColor: Color {
        switch issue.confidence {
        case 0.9...1.0: return .green
        case 0.7...0.9: return .orange
        default: return .red
        }
    }

    private var detectionMethodIcon: String {
        switch issue.detectionMethod {
        case .aiAnalysis: return "brain"
        case .manualCalculation: return "calculator"
        case .plaidVerification: return "creditcard"
        case .combinedAnalysis: return "gearshape.2"
        }
    }

    private var mockSupportingDocuments: [MockDocument] {
        [
            MockDocument(name: "Mortgage Statement - January 2025.pdf", type: "PDF", size: "2.1 MB"),
            MockDocument(name: "Bank Statement - December 2024.pdf", type: "PDF", size: "1.8 MB"),
            MockDocument(name: "Payment Confirmation.jpg", type: "Image", size: "0.5 MB")
        ]
    }

    // MARK: - Formatting Helpers
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

enum DetailTab: String, CaseIterable {
    case overview = "Overview"
    case evidence = "Evidence"
    case calculation = "Calculation"
    case timeline = "Timeline"
    case actions = "Actions"

    var icon: String {
        switch self {
        case .overview: return "info.circle"
        case .evidence: return "doc.text.magnifyingglass"
        case .calculation: return "calculator"
        case .timeline: return "clock"
        case .actions: return "list.bullet.clipboard"
        }
    }
}

struct MockDocument {
    let name: String
    let type: String
    let size: String
}

// MARK: - Supporting Views

struct SeverityBadge: View {
    let severity: AuditResult.Severity

    var body: some View {
        Text(severity.displayName.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(severity.color.opacity(0.15))
            )
            .foregroundColor(severity.color)
    }
}

struct FinancialImpactBadge: View {
    let amount: Double

    var body: some View {
        Text(formatCurrency(amount))
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
            .foregroundColor(.green)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TabButton: View {
    let tab: DetailTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)

                Text(tab.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.blue)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .padding()
                }
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

// Additional supporting views would be implemented here...
// (DetailTextSection, EvidenceTextView, CalculationDetailsView, etc.)

#Preview {
    IssueDetailView(issue: AuditResult.sampleResult())
}