import SwiftUI

/// A reusable row component for displaying audit issues
struct IssueRow: View {
    let auditResult: AuditResult
    let action: (() -> Void)?

    init(auditResult: AuditResult, action: (() -> Void)? = nil) {
        self.auditResult = auditResult
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                // Issue icon and severity indicator
                ZStack {
                    Circle()
                        .fill(auditResult.severity.color.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: auditResult.issueType.icon)
                        .foregroundColor(auditResult.severity.color)
                        .font(.system(size: 16, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(auditResult.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if let amount = auditResult.affectedAmount {
                            Text(formatCurrency(amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(auditResult.severity.color)
                        }
                    }

                    Text(auditResult.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack {
                        // Severity badge
                        Text(auditResult.severity.displayName.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(auditResult.severity.color.opacity(0.2))
                            )
                            .foregroundColor(auditResult.severity.color)

                        Spacer()

                        Text(formatDate(auditResult.createdDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if action != nil {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 8) {
        IssueRow(auditResult: AuditResult.sampleResult(), action: {})

        IssueRow(
            auditResult: AuditResult(
                issueType: .unauthorizedFee,
                severity: .critical,
                title: "Unauthorized Late Fee",
                description: "Late fee charged without proper notice",
                detailedExplanation: "",
                suggestedAction: "",
                affectedAmount: 35.00,
                detectionMethod: .aiAnalysis,
                confidence: 0.92,
                evidenceText: "",
                calculationDetails: nil,
                createdDate: Date()
            )
        )
    }
    .padding()
}