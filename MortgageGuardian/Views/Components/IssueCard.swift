import SwiftUI

/// Enhanced issue card component with rich presentation, selection support, and accessibility
struct EnhancedIssueCard: View {
    let issue: AuditResult
    let isSelected: Bool
    let bulkActionMode: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main Content
                HStack(spacing: 12) {
                    // Selection Indicator (Bulk Mode)
                    if bulkActionMode {
                        selectionIndicator
                    }

                    // Issue Icon and Severity
                    issueIconSection

                    // Issue Content
                    VStack(alignment: .leading, spacing: 6) {
                        issueHeader
                        issueDescription
                        issueMetadata
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Financial Impact
                    if let amount = issue.affectedAmount {
                        financialImpactSection(amount: amount)
                    }

                    // Disclosure Indicator
                    if !bulkActionMode {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Confidence and Detection Info
                confidenceAndDetectionSection
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Selection Indicator
    @ViewBuilder
    private var selectionIndicator: some View {
        Button(action: onToggleSelection) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Select issue")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Issue Icon Section
    @ViewBuilder
    private var issueIconSection: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(issue.severity.color.opacity(0.1))
                .frame(width: iconSize, height: iconSize)

            // Severity Ring
            Circle()
                .stroke(issue.severity.color.opacity(0.3), lineWidth: 2)
                .frame(width: iconSize, height: iconSize)

            // Issue Icon
            Image(systemName: issue.issueType.icon)
                .font(.system(size: iconSize * 0.4, weight: .medium))
                .foregroundColor(issue.severity.color)
        }
        .overlay(
            // Severity Indicator
            Circle()
                .fill(issue.severity.color)
                .frame(width: 12, height: 12)
                .offset(x: iconSize * 0.3, y: -iconSize * 0.3)
        )
    }

    // MARK: - Issue Header
    @ViewBuilder
    private var issueHeader: some View {
        HStack {
            Text(issue.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            // Severity Badge
            Text(issue.severity.displayName.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(issue.severity.color.opacity(0.15))
                )
                .foregroundColor(issue.severity.color)
        }
    }

    // MARK: - Issue Description
    @ViewBuilder
    private var issueDescription: some View {
        Text(issue.description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    // MARK: - Issue Metadata
    @ViewBuilder
    private var issueMetadata: some View {
        HStack(spacing: 12) {
            // Issue Type
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(issue.issueType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Date
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(formatDate(issue.createdDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Financial Impact Section
    @ViewBuilder
    private func financialImpactSection(amount: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount > 0 ? .green : .red)

            Text("Impact")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Confidence and Detection Section
    @ViewBuilder
    private var confidenceAndDetectionSection: some View {
        HStack {
            // Confidence Indicator
            HStack(spacing: 4) {
                Image(systemName: "gauge.medium")
                    .font(.caption2)
                    .foregroundColor(confidenceColor)

                Text("Confidence: \(Int(issue.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Confidence Bar
                ProgressView(value: issue.confidence)
                    .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                    .frame(width: 40, height: 2)
            }

            Spacer()

            // Detection Method
            HStack(spacing: 4) {
                Image(systemName: detectionMethodIcon)
                    .font(.caption2)
                    .foregroundColor(.blue)

                Text(issue.detectionMethod.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Background and Border
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
    }

    @ViewBuilder
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isSelected ? Color.blue :
                (issue.severity == .critical ? issue.severity.color.opacity(0.3) : Color.clear),
                lineWidth: isSelected ? 2 : 1
            )
    }

    // MARK: - Computed Properties
    private var iconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 36
        case .medium, .large: return 44
        case .xLarge, .xxLarge: return 52
        default: return 60
        }
    }

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

    private var accessibilityLabel: String {
        var label = "\(issue.title). \(issue.severity.displayName) severity. "
        if let amount = issue.affectedAmount {
            label += "Financial impact: \(formatCurrency(amount)). "
        }
        label += "Confidence: \(Int(issue.confidence * 100))%. "
        label += "Detected using \(issue.detectionMethod.displayName). "
        label += "Created on \(formatDate(issue.createdDate))."
        return label
    }

    private var accessibilityHint: String {
        if bulkActionMode {
            return isSelected ? "Tap to deselect" : "Tap to select"
        } else {
            return "Double tap to view details"
        }
    }

    // MARK: - Formatting Helpers
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

/// Compact issue card for use in lists or grids
struct CompactIssueCard: View {
    let issue: AuditResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: issue.issueType.icon)
                    .font(.title3)
                    .foregroundColor(issue.severity.color)
                    .frame(width: 24, height: 24)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(issue.severity.displayName)
                        .font(.caption)
                        .foregroundColor(issue.severity.color)
                }

                Spacer()

                // Amount
                if let amount = issue.affectedAmount {
                    Text(formatCurrency(amount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
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

/// Issue card for widgets or dashboard views
struct WidgetIssueCard: View {
    let issue: AuditResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: issue.issueType.icon)
                    .font(.caption)
                    .foregroundColor(issue.severity.color)

                Spacer()

                Text(issue.severity.displayName.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(issue.severity.color)
            }

            Text(issue.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            if let amount = issue.affectedAmount {
                Text(formatCurrency(amount))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
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

#Preview {
    VStack(spacing: 16) {
        EnhancedIssueCard(
            issue: AuditResult.sampleResult(),
            isSelected: false,
            bulkActionMode: false,
            onTap: {},
            onToggleSelection: {}
        )

        EnhancedIssueCard(
            issue: AuditResult.sampleResult(),
            isSelected: true,
            bulkActionMode: true,
            onTap: {},
            onToggleSelection: {}
        )

        CompactIssueCard(
            issue: AuditResult.sampleResult(),
            onTap: {}
        )

        WidgetIssueCard(issue: AuditResult.sampleResult())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}