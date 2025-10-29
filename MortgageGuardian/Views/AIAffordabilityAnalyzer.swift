import SwiftUI
import Charts

struct AIAffordabilityAnalyzer: View {
    let userProfile: UserProfile
    @State private var targetHomePrice: Double = 500000
    @State private var isAnalyzing = false
    @State private var analysisResults: AffordabilityAnalysis?
    
    struct AffordabilityAnalysis {
        let maxAffordablePrice: Double
        let recommendedPrice: Double
        let monthlyBudget: Double
        let debtToIncomeRatio: Double
        let stressTestResult: StressTestResult
        let affordabilityScore: Double // 0-100
        
        struct StressTestResult {
            let passedAt: Double // interest rate
            let failedAt: Double
            let currentMargin: Double
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Price Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Home Price")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                        TextField("Home Price", value: $targetHomePrice, format: .number)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Analyze") {
                            Task {
                                await analyzeAffordability()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing)
                    }
                }
                .padding()
                .background(AppTheme.Colors.light.surface)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                
                if let results = analysisResults {
                    // Affordability Score
                    affordabilityScoreCard(results)
                    
                    // Income Analysis
                    incomeAnalysisChart(results)
                    
                    // Stress Test Visualization
                    stressTestVisualization(results)
                    
                    // Recommendations
                    recommendationsCard(results)
                    
                    // Monthly Budget Breakdown
                    monthlyBudgetBreakdown(results)
                }
            }
            .padding()
        }
        .navigationTitle("AI Affordability Analysis")
        .overlay {
            if isAnalyzing {
                ProgressView("Analyzing affordability...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private func affordabilityScoreCard(_ results: AffordabilityAnalysis) -> some View {
        VStack(spacing: 16) {
            Text("Affordability Score")
                .font(.headline)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                // Score arc
                Circle()
                    .trim(from: 0, to: results.affordabilityScore / 100)
                    .stroke(
                        scoreColor(results.affordabilityScore),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: results.affordabilityScore)
                
                VStack {
                    Text("\(Int(results.affordabilityScore))")
                        .font(.system(size: 48, weight: .bold))
                    
                    Text(scoreDescription(results.affordabilityScore))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            
            HStack(spacing: 40) {
                VStack {
                    Text("Max Affordable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(results.maxAffordablePrice, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                VStack {
                    Text("Recommended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(results.recommendedPrice, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func incomeAnalysisChart(_ results: AffordabilityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income Distribution Analysis")
                .font(.headline)
            
            Chart {
                // Monthly income breakdown
                let data = [
                    ("Housing", results.monthlyBudget),
                    ("Other Debt", userProfile.existingDebts / 12),
                    ("Living Expenses", userProfile.monthlyExpenses),
                    ("Savings", userProfile.annualIncome / 12 - results.monthlyBudget - userProfile.existingDebts / 12 - userProfile.monthlyExpenses)
                ]
                
                ForEach(data, id: \.0) { item in
                    SectorMark(
                        angle: .value("Amount", max(0, item.1)),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.0))
                    .cornerRadius(4)
                }
            }
            .frame(height: 250)
            .chartAngleSelection(value: .constant(nil))
            .chartLegend(position: .bottom)
            
            // DTI Ratio Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Debt-to-Income Ratio")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(results.debtToIncomeRatio * 100))%")
                        .fontWeight(.medium)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // DTI Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dtiColor(results.debtToIncomeRatio))
                            .frame(width: geometry.size.width * min(results.debtToIncomeRatio, 1.0))
                        
                        // Recommended line
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2)
                            .offset(x: geometry.size.width * 0.28) // 28% recommended
                    }
                }
                .frame(height: 20)
                
                Text("Recommended: < 28%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func stressTestVisualization(_ results: AffordabilityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interest Rate Stress Test")
                .font(.headline)
            
            Chart {
                // Show affordability at different interest rates
                ForEach(Array(stride(from: 3.0, through: 10.0, by: 0.5)), id: \.self) { rate in
                    LineMark(
                        x: .value("Rate", rate),
                        y: .value("Payment", calculatePayment(at: rate))
                    )
                    .foregroundStyle(.blue)
                    
                    if rate == results.stressTestResult.failedAt {
                        RuleMark(x: .value("Failed At", rate))
                            .foregroundStyle(.red)
                            .annotation(position: .top) {
                                Text("Stress Test Limit")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                    }
                }
                
                // Current rate marker
                RuleMark(x: .value("Current", 6.5))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(dash: [5, 5]))
            }
            .frame(height: 200)
            .chartXAxisLabel("Interest Rate (%)")
            .chartYAxisLabel("Monthly Payment")
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Current Margin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(results.stressTestResult.currentMargin, format: .percent)")
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading) {
                    Text("Passes Until")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(results.stressTestResult.failedAt, format: .percent)% rate")
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func recommendationsCard(_ results: AffordabilityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Recommendations", systemImage: "lightbulb.fill")
                .font(.headline)
            
            if targetHomePrice > results.maxAffordablePrice {
                recommendation(
                    icon: "exclamationmark.triangle.fill",
                    text: "Consider a lower price point or increase down payment",
                    type: .warning
                )
            }
            
            if results.debtToIncomeRatio > 0.28 {
                recommendation(
                    icon: "creditcard.fill",
                    text: "Reduce existing debts to improve affordability",
                    type: .warning
                )
            }
            
            recommendation(
                icon: "percent",
                text: "Shop for better rates - 0.5% lower could save $\(Int(calculateSavings()))/month",
                type: .tip
            )
            
            recommendation(
                icon: "calendar",
                text: "Consider waiting 6 months while saving could improve your position",
                type: .tip
            )
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func monthlyBudgetBreakdown(_ results: AffordabilityAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Payment Breakdown")
                .font(.headline)
            
            let principal = results.monthlyBudget * 0.7
            let interest = results.monthlyBudget * 0.3
            let propertyTax = targetHomePrice * 0.01 / 12
            let insurance = targetHomePrice * 0.0035 / 12
            let pmi = targetHomePrice * 0.005 / 12
            
            budgetItem("Principal", amount: principal, color: .blue)
            budgetItem("Interest", amount: interest, color: .orange)
            budgetItem("Property Tax", amount: propertyTax, color: .green)
            budgetItem("Insurance", amount: insurance, color: .purple)
            if targetHomePrice * 0.8 > results.recommendedPrice {
                budgetItem("PMI", amount: pmi, color: .red)
            }
            
            Divider()
            
            HStack {
                Text("Total Monthly")
                    .fontWeight(.medium)
                Spacer()
                Text(results.monthlyBudget, format: .currency(code: "USD"))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    // Helper Views
    private func recommendation(icon: String, text: String, type: RecommendationType) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(type.color)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func budgetItem(_ title: String, amount: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // Helper Functions
    private func analyzeAffordability() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        analysisResults = AffordabilityAnalysis(
            maxAffordablePrice: calculateMaxAffordable(),
            recommendedPrice: calculateMaxAffordable() * 0.85,
            monthlyBudget: calculateMonthlyBudget(),
            debtToIncomeRatio: calculateDTI(),
            stressTestResult: .init(
                passedAt: 6.5,
                failedAt: 8.2,
                currentMargin: 0.17
            ),
            affordabilityScore: calculateAffordabilityScore()
        )
    }
    
    private func calculateMaxAffordable() -> Double {
        let monthlyIncome = userProfile.annualIncome / 12
        let maxPayment = monthlyIncome * 0.28 - (userProfile.existingDebts / 12)
        return maxPayment * 12 * 25 // Rough estimate
    }
    
    private func calculateMonthlyBudget() -> Double {
        let principal = targetHomePrice * 0.8 // 20% down
        let rate = 0.065 / 12
        let n = 30 * 12
        return principal * (rate * pow(1 + rate, Double(n))) / (pow(1 + rate, Double(n)) - 1)
    }
    
    private func calculateDTI() -> Double {
        let monthlyIncome = userProfile.annualIncome / 12
        let totalDebt = calculateMonthlyBudget() + userProfile.existingDebts / 12
        return totalDebt / monthlyIncome
    }
    
    private func calculateAffordabilityScore() -> Double {
        let dtiScore = max(0, 100 - (calculateDTI() * 200))
        let priceScore = targetHomePrice <= calculateMaxAffordable() ? 100 : 50
        return (dtiScore + priceScore) / 2
    }
    
    private func calculatePayment(at rate: Double) -> Double {
        let principal = targetHomePrice * 0.8
        let monthlyRate = rate / 100 / 12
        let n = 30 * 12
        return principal * (monthlyRate * pow(1 + monthlyRate, Double(n))) / (pow(1 + monthlyRate, Double(n)) - 1)
    }
    
    private func calculateSavings() -> Double {
        let currentPayment = calculatePayment(at: 6.5)
        let lowerPayment = calculatePayment(at: 6.0)
        return currentPayment - lowerPayment
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Poor"
        }
    }
    
    private func dtiColor(_ ratio: Double) -> Color {
        switch ratio {
        case 0..<0.28: return .green
        case 0.28..<0.36: return .yellow
        case 0.36..<0.43: return .orange
        default: return .red
        }
    }
    
    enum RecommendationType {
        case warning, tip
        
        var color: Color {
            switch self {
            case .warning: return .orange
            case .tip: return .blue
            }
        }
    }
}