import SwiftUI

struct AIInsightCard: View {
    let title: String
    let insights: [InsightItem]
    let confidence: Double
    let type: InsightType
    
    enum InsightType {
        case positive
        case neutral
        case negative
        
        var color: Color {
            switch self {
            case .positive:
                return .green
            case .neutral:
                return .blue
            case .negative:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .positive:
                return "arrow.up.circle.fill"
            case .neutral:
                return "equal.circle.fill"
            case .negative:
                return "arrow.down.circle.fill"
            }
        }
    }
    
    struct InsightItem {
        let title: String
        let value: String
        let description: String?
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundStyle(type.color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(Int(confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(insights, id: \.title) { insight in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.title)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(insight.value)
                            .fontWeight(.medium)
                    }
                    
                    if let description = insight.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}