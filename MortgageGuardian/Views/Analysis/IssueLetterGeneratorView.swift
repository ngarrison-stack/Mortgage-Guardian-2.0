import SwiftUI

/// Letter generation interface for specific issues
struct IssueLetterGeneratorView: View {
    let issue: AuditResult
    @Environment(\.dismiss) private var dismiss

    @State private var letterType: LetterType = .noticeOfError
    @State private var selectedTemplate: LetterTemplate?
    @State private var customizations = LetterCustomizations()
    @State private var isGenerating = false
    @State private var generatedLetter: String?
    @State private var showingPreview = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    letterHeaderSection

                    // Letter Type Selection
                    letterTypeSection

                    // Template Selection
                    templateSelectionSection

                    // Customization Options
                    customizationSection

                    // Generate Button
                    generateSection
                }
                .padding()
            }
            .navigationTitle("Generate Letter")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingPreview) {
                if let letter = generatedLetter {
                    LetterPreviewView(letterContent: letter, issue: issue)
                }
            }
        }
    }

    // MARK: - Header Section
    @ViewBuilder
    private var letterHeaderSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: issue.issueType.icon)
                    .font(.title)
                    .foregroundColor(issue.severity.color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(issue.severity.color.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Generate formal correspondence")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if let amount = issue.affectedAmount {
                HStack {
                    Text("Potential Recovery:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatCurrency(amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Letter Type Section
    @ViewBuilder
    private var letterTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Letter Type")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(LetterType.allCases, id: \.self) { type in
                    LetterTypeCard(
                        type: type,
                        isSelected: letterType == type,
                        isRecommended: type.isRecommendedFor(issue: issue)
                    ) {
                        letterType = type
                    }
                }
            }
        }
    }

    // MARK: - Template Selection
    @ViewBuilder
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Selection")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(availableTemplates, id: \.id) { template in
                    TemplateRow(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id
                    ) {
                        selectedTemplate = template
                    }
                }
            }
        }
    }

    // MARK: - Customization Section
    @ViewBuilder
    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customization")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                Toggle("Include supporting evidence", isOn: $customizations.includeEvidence)
                Toggle("Include calculation details", isOn: $customizations.includeCalculations)
                Toggle("Request formal response", isOn: $customizations.requestResponse)
                Toggle("CC to regulatory agencies", isOn: $customizations.ccRegulatoryAgencies)

                if customizations.requestResponse {
                    HStack {
                        Text("Response timeframe:")
                        Spacer()
                        Picker("Days", selection: $customizations.responseTimeframe) {
                            Text("30 days").tag(30)
                            Text("60 days").tag(60)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 200)
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

    // MARK: - Generate Section
    @ViewBuilder
    private var generateSection: some View {
        VStack(spacing: 16) {
            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Generating letter...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Button {
                    generateLetter()
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
                .disabled(selectedTemplate == nil)
            }

            if generatedLetter != nil {
                Button {
                    showingPreview = true
                } label: {
                    HStack {
                        Image(systemName: "eye")
                        Text("Preview Letter")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if generatedLetter != nil {
                Menu {
                    Button("Preview Letter") {
                        showingPreview = true
                    }

                    Button("Email Letter") {
                        emailLetter()
                    }

                    Button("Save to Files") {
                        saveToFiles()
                    }

                    Button("Print Letter") {
                        printLetter()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var availableTemplates: [LetterTemplate] {
        // Mock templates - in real app, would load from TemplateLoader
        [
            LetterTemplate(
                id: "notice_of_error_formal",
                name: "Formal Notice of Error",
                description: "Professional template citing RESPA regulations",
                category: .noticeOfError,
                content: "Mock template content"
            ),
            LetterTemplate(
                id: "notice_of_error_detailed",
                name: "Detailed Notice of Error",
                description: "Comprehensive template with evidence sections",
                category: .noticeOfError,
                content: "Mock template content"
            )
        ]
    }

    // MARK: - Actions
    private func generateLetter() {
        guard let template = selectedTemplate else { return }

        isGenerating = true

        // Simulate letter generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let generator = LetterGenerator(
                issue: issue,
                template: template,
                customizations: customizations
            )

            generatedLetter = generator.generateLetter()
            isGenerating = false
        }
    }

    private func emailLetter() {
        // TODO: Implement email functionality
        print("Emailing letter")
    }

    private func saveToFiles() {
        // TODO: Implement save to files
        print("Saving to files")
    }

    private func printLetter() {
        // TODO: Implement print functionality
        print("Printing letter")
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Supporting Types

enum LetterType: String, CaseIterable {
    case noticeOfError = "Notice of Error"
    case qualifiedWrittenRequest = "Qualified Written Request"
    case complaintLetter = "Complaint Letter"
    case demandLetter = "Demand Letter"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .noticeOfError:
            return "Formal notice under RESPA Section 6 for servicer errors"
        case .qualifiedWrittenRequest:
            return "Request for account information under RESPA Section 6"
        case .complaintLetter:
            return "Formal complaint to servicer management"
        case .demandLetter:
            return "Demand for immediate correction and compensation"
        }
    }

    var recommendedFor: [AuditResult.IssueType] {
        switch self {
        case .noticeOfError:
            return [.misappliedPayment, .latePaymentError, .incorrectBalance, .unauthorizedFee]
        case .qualifiedWrittenRequest:
            return [.escrowError, .missingPayment, .incorrectInterest]
        case .complaintLetter:
            return [.forcePlacedInsurance, .duplicateCharge]
        case .demandLetter:
            return [.unauthorizedFee, .duplicateCharge]
        }
    }

    func isRecommendedFor(issue: AuditResult) -> Bool {
        recommendedFor.contains(issue.issueType) || issue.severity == .critical
    }
}

struct LetterCustomizations {
    var includeEvidence = true
    var includeCalculations = true
    var requestResponse = true
    var responseTimeframe = 30
    var ccRegulatoryAgencies = false
}

// MARK: - Supporting Views

struct LetterTypeCard: View {
    let type: LetterType
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateRow: View {
    let template: LetterTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Letter Generator
class LetterGenerator {
    private let issue: AuditResult
    private let template: LetterTemplate
    private let customizations: LetterCustomizations

    init(issue: AuditResult, template: LetterTemplate, customizations: LetterCustomizations) {
        self.issue = issue
        self.template = template
        self.customizations = customizations
    }

    func generateLetter() -> String {
        // Mock letter generation - in real app would use actual template engine
        let date = DateFormatter.letterDate.string(from: Date())

        return """
        \(date)

        [Your Mortgage Servicer]
        [Servicer Address]

        RE: Notice of Error - Account #[Your Account Number]

        Dear Servicer,

        I am writing to notify you of an error on my mortgage account pursuant to the Real Estate Settlement Procedures Act (RESPA), 12 U.S.C. § 2605(e).

        ISSUE DESCRIPTION:
        \(issue.title)

        \(issue.detailedExplanation)

        \(customizations.includeEvidence ? "\nEVIDENCE:\n\(issue.evidenceText ?? "See attached documentation")" : "")

        \(customizations.includeCalculations && issue.calculationDetails != nil ? "\nCALCULATION DETAILS:\nExpected: \(formatCurrency(issue.calculationDetails?.expectedValue ?? 0))\nActual: \(formatCurrency(issue.calculationDetails?.actualValue ?? 0))" : "")

        REQUESTED ACTION:
        \(issue.suggestedAction)

        \(customizations.requestResponse ? "Please provide a written response within \(customizations.responseTimeframe) days as required by RESPA." : "")

        Thank you for your prompt attention to this matter.

        Sincerely,
        [Your Name]
        [Your Contact Information]

        \(customizations.ccRegulatoryAgencies ? "\ncc: Consumer Financial Protection Bureau" : "")
        """
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Letter Preview View
struct LetterPreviewView: View {
    let letterContent: String
    let issue: AuditResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(letterContent)
                    .font(.system(.body, design: .serif))
                    .padding()
            }
            .navigationTitle("Letter Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Email") { }
                        Button("Print") { }
                        Button("Save to Files") { }
                        Button("Copy to Clipboard") {
                            UIPasteboard.general.string = letterContent
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let letterDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
}

#Preview {
    IssueLetterGeneratorView(issue: AuditResult.sampleResult())
}