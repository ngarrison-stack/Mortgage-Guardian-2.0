import SwiftUI

/// A reusable summary card component for displaying key metrics and information
struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let action: (() -> Void)?

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = .blue,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)

                    Spacer()

                    if action != nil {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

#Preview {
    VStack(spacing: 16) {
        SummaryCard(
            title: "Critical Issues",
            value: "3",
            subtitle: "Requires immediate attention",
            icon: "exclamationmark.triangle.fill",
            color: .red,
            action: {}
        )

        SummaryCard(
            title: "Potential Savings",
            value: "$2,450",
            subtitle: "From identified errors",
            icon: "dollarsign.circle.fill",
            color: .green
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}