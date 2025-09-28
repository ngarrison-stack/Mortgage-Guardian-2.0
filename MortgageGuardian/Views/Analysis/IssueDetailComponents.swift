import SwiftUI

// MARK: - Supporting Components for IssueDetailView

/// Detailed text section with optional background styling
struct DetailTextSection: View {
    let title: String
    let content: String
    let style: Font.TextStyle
    let backgroundColor: Color?

    init(title: String, content: String, style: Font.TextStyle = .body, backgroundColor: Color? = nil) {
        self.title = title
        self.content = content
        self.style = style
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(Font(style))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            backgroundColor.map { color in
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            }
        )
    }
}

/// Evidence text view with highlighting capabilities
struct EvidenceTextView: View {
    let text: String
    @State private var selectedText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evidence Text")
                .font(.headline)
                .fontWeight(.semibold)

            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)

                Text("This text was extracted from your mortgage documents")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Empty evidence placeholder
struct EmptyEvidenceView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No Evidence Text Available")
                .font(.headline)
                .fontWeight(.medium)

            Text("Evidence text may not be available for this type of issue or detection method.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

/// Calculation details view with formatted presentation
struct CalculationDetailsView: View {
    let details: AuditResult.CalculationDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Expected vs Actual Values
            if let expectedValue = details.expectedValue,
               let actualValue = details.actualValue {
                calculationValuesSection(expected: expectedValue, actual: actualValue, difference: details.difference)
            }

            // Formula
            if let formula = details.formula {
                formulaSection(formula: formula)
            }

            // Assumptions
            if !details.assumptions.isEmpty {
                assumptionsSection(assumptions: details.assumptions)
            }

            // Warning Flags
            if !details.warningFlags.isEmpty {
                warningFlagsSection(flags: details.warningFlags)
            }
        }
    }

    @ViewBuilder
    private func calculationValuesSection(expected: Double, actual: Double, difference: Double?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calculation Values")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                CalculationRow(label: "Expected", value: formatCurrency(expected), color: .green)
                CalculationRow(label: "Actual", value: formatCurrency(actual), color: .primary)

                if let difference = difference {
                    Divider()
                    CalculationRow(
                        label: "Difference",
                        value: formatCurrency(difference),
                        color: difference > 0 ? .red : .green
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }

    @ViewBuilder
    private func formulaSection(formula: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Formula")
                .font(.headline)
                .fontWeight(.semibold)

            Text(formula)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
        }
    }

    @ViewBuilder
    private func assumptionsSection(assumptions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(assumptions, id: \.self) { assumption in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)

                        Text(assumption)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func warningFlagsSection(flags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warning Flags")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(flags, id: \.self) { flag in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)

                        Text(flag)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.1))
                    )
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
}

/// Calculation row component
struct CalculationRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

/// Timeline event component
struct TimelineEvent: View {
    let date: Date
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(color.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }

            // Event content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Action recommendation card
struct ActionRecommendationCard: View {
    let title: String
    let description: String
    let priority: ActionPriority
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Priority indicator
                VStack {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 8, height: 8)

                    Text(priority.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(priority.color)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 8)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(priority.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Document reference row
struct DocumentReferenceRow: View {
    let document: MockDocument
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: documentIcon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack {
                        Text(document.type)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(document.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var documentIcon: String {
        switch document.type {
        case "PDF": return "doc.fill"
        case "Image": return "photo.fill"
        default: return "doc"
        }
    }
}

/// Empty state view with action
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 300)
    }
}

// MARK: - Supporting Types

enum ActionPriority: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

/// Filter chip component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}