import SwiftUI
import SwiftData

struct ScenarioDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let scenario: SavedMortgageScenario
    
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 8) {
                        Text(scenario.monthlyPayment, format: .currency(code: "USD"))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.light.primary)
                        
                        Text("Monthly Payment")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.Colors.light.surface)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    
                    // Loan Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Loan Details")
                            .font(.headline)
                        
                        DetailRow(title: "Principal", value: scenario.principalAmount)
                        DetailRow(title: "Down Payment", value: scenario.downPayment)
                        DetailRow(title: "Interest Rate", value: scenario.annualInterestRate, format: .percent)
                        DetailRow(title: "Loan Term", value: "\(scenario.loanTermYears) Years")
                    }
                    .padding()
                    .background(AppTheme.Colors.light.surface)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    
                    // Cost Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cost Breakdown")
                            .font(.headline)
                        
                        DetailRow(title: "Total Principal", value: scenario.principalAmount - scenario.downPayment)
                        DetailRow(title: "Total Interest", value: scenario.totalInterest)
                        DetailRow(
                            title: "Total Cost",
                            value: scenario.monthlyPayment * Double(scenario.loanTermYears * 12),
                            style: .prominent
                        )
                    }
                    .padding()
                    .background(AppTheme.Colors.light.surface)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    
                    if let notes = scenario.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(notes)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.Colors.light.surface)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
                .padding()
            }
            .navigationTitle(scenario.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        }
                    }
            )
        }
        .offset(y: max(0, dragOffset.height))
    }
}

private struct DetailRow: View {
    let title: String
    let value: Double
    let format: FloatingPointFormatStyle<Double> = .currency(code: "USD")
    let style: DetailRowStyle
    
    enum DetailRowStyle {
        case normal
        case prominent
    }
    
    init(title: String, value: Double, format: FloatingPointFormatStyle<Double> = .currency(code: "USD"), style: DetailRowStyle = .normal) {
        self.title = title
        self.value = value
        self.style = style
    }
    
    init(title: String, value: String) {
        self.title = title
        self.value = 0
        self.style = .normal
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if value == 0 {
                Text(title)
                    .fontWeight(style == .prominent ? .bold : .regular)
            } else {
                Text(value, format: format)
                    .fontWeight(style == .prominent ? .bold : .regular)
            }
        }
    }
}