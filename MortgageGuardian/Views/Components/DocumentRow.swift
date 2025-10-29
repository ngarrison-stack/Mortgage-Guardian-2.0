import SwiftUI

/// A reusable row component for displaying mortgage documents
struct DocumentRow: View {
    let document: MortgageDocument
    let action: (() -> Void)?

    init(document: MortgageDocument, action: (() -> Void)? = nil) {
        self.document = document
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                // Document type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: document.documentType.icon)
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(document.fileName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // Analysis status indicator
                        statusIndicator
                    }

                    Text(document.documentType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Uploaded " + formatDate(document.uploadDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !document.analysisResults.isEmpty {
                            Text("\(document.analysisResults.count) issues found")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }

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

    @ViewBuilder
    private var statusIndicator: some View {
        if document.isAnalyzed {
            if document.analysisResults.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        } else {
            Image(systemName: "clock.fill")
                .foregroundColor(.gray)
                .font(.caption)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 8) {
        DocumentRow(
            document: MortgageDocument(
                fileName: "January_2025_Statement.pdf",
                documentType: .mortgageStatement,
                uploadDate: Date(),
                originalText: "",
                extractedData: nil,
                analysisResults: [AuditResult.sampleResult()],
                isAnalyzed: true
            ),
            action: {}
        )

        DocumentRow(
            document: MortgageDocument(
                fileName: "Escrow_Analysis_2024.pdf",
                documentType: .escrowStatement,
                uploadDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                originalText: "",
                extractedData: nil,
                analysisResults: [],
                isAnalyzed: false
            )
        )
    }
    .padding()
}