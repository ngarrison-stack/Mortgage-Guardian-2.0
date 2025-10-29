import SwiftUI

struct AIScenarioAnalyzer: View {
    let scenario: SavedMortgageScenario
    @State private var isAnalyzing = false
    @State private var selectedAnalysis: AnalysisType = .risk
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiCoordinator = MortgageAICoordinator()
    
    enum AnalysisType: String, CaseIterable {
        case risk = "Risk Analysis"
        case prediction = "Value Prediction"
        case recommendation = "Recommendations"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Analysis Type Selector
                    Picker("Analysis Type", selection: $selectedAnalysis) {
                        ForEach(AnalysisType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    switch selectedAnalysis {
                    case .risk:
                        riskAnalysisView
                    case .prediction:
                        valuePredictionView
                    case .recommendation:
                        recommendationsView
                    }
                }
                .padding()
            }
            .navigationTitle("AI Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isAnalyzing {
                    ProgressView("Analyzing scenario...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
        }
        .task {
            await analyzeScenario()
        }
    }
    
    private var riskAnalysisView: some View {
        VStack(spacing: 16) {
            if let risk = scenario.riskAssessment {
                // Risk Score
                VStack {
                    ZStack {
                        Circle()
                            .stroke(
                                Color.gray.opacity(0.2),
                                lineWidth: 15
                            )
                        
                        Circle()
                            .trim(from: 0, to: risk.riskScore / 100)
                            .stroke(
                                risk.riskScore > 70 ? Color.green :
                                    risk.riskScore > 40 ? Color.orange : Color.red,
                                style: StrokeStyle(
                                    lineWidth: 15,
                                    lineCap: .round
                                )
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text("\(Int(risk.riskScore))")
                                .font(.system(size: 44, weight: .bold))
                            Text("Risk Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)
                    .padding()
                    
                    // Risk Factors
                    ForEach(risk.riskFactors, id: \.type) { factor in
                        HStack {
                            Text(factor.type.rawValue)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            ProgressView(value: factor.severity) {
                                Text("\(Int(factor.severity * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 100)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var valuePredictionView: some View {
        VStack(spacing: 16) {
            if let prediction = scenario.propertyValuePrediction {
                VStack(spacing: 8) {
                    Text("Predicted Value")
                        .font(.headline)
                    
                    Text(prediction.predictedValue, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .bold))
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("in 5 years")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Value Change
                let change = prediction.predictedValue - scenario.principalAmount
                let percentage = (change / scenario.principalAmount) * 100
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Projected Change")
                            .font(.subheadline)
                        Text(change, format: .currency(code: "USD"))
                            .font(.title3)
                            .foregroundStyle(change >= 0 ? .green : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Percentage")
                            .font(.subheadline)
                        Text(percentage, format: .percent.precision(.fractionLength(1)))
                            .font(.title3)
                            .foregroundStyle(change >= 0 ? .green : .red)
                    }
                }
                
                // Confidence Level
                VStack(spacing: 4) {
                    Text("Prediction Confidence")
                        .font(.subheadline)
                    
                    ProgressView(value: prediction.confidence) {
                        Text("\(Int(prediction.confidence * 100))%")
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
    
    private var recommendationsView: some View {
        VStack(spacing: 16) {
            if let recommendations = scenario.aiRecommendations {
                // Optimized Terms
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optimized Loan Terms")
                        .font(.headline)
                    
                    HStack {
                        recommendationCard(
                            title: "Loan Term",
                            value: "\(recommendations.recommendedLoanTerm) years",
                            current: "\(scenario.loanTermYears) years",
                            isImprovement: recommendations.recommendedLoanTerm <= scenario.loanTermYears
                        )
                        
                        recommendationCard(
                            title: "Down Payment",
                            value: recommendations.recommendedDownPayment,
                            format: .currency(code: "USD"),
                            current: scenario.downPayment,
                            isImprovement: recommendations.recommendedDownPayment >= scenario.downPayment
                        )
                    }
                    
                    recommendationCard(
                        title: "Interest Rate",
                        value: recommendations.recommendedInterestRate,
                        format: .percent,
                        current: scenario.annualInterestRate / 100,
                        isImprovement: recommendations.recommendedInterestRate <= scenario.annualInterestRate / 100
                    )
                }
                
                // Reasoning
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Insights")
                        .font(.headline)
                    
                    ForEach(recommendations.reasoning, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func recommendationCard<T: Numeric>(
        title: String,
        value: T,
        format: FloatingPointFormatStyle<Double> = .number,
        current: T,
        isImprovement: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let value = value as? Double {
                    Text(value, format: format)
                        .font(.title3)
                        .fontWeight(.medium)
                } else {
                    Text("\(value as! Int)")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                Image(systemName: isImprovement ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(isImprovement ? .green : .red)
                    .font(.caption)
            }
            
            if let current = current as? Double {
                Text("Current: \(current, format: format)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Current: \(current as! Int)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func analyzeScenario() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Create a sample user profile (in production, this would come from user data)
        let userProfile = UserProfile(
            annualIncome: 120000,
            creditScore: 750,
            employmentYears: 5,
            location: "Sample Location",
            existingDebts: 10000,
            monthlyExpenses: 3000
        )
        
        do {
            try await aiCoordinator.analyzeScenario(scenario, userProfile: userProfile)
        } catch {
            print("Error analyzing scenario: \(error)")
        }
    }
}