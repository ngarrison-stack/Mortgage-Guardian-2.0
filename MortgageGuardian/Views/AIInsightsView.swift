import SwiftUI

struct AIInsightsView: View {
    let scenario: SavedMortgageScenario
    @State private var isLoading = false
    @State private var selectedTimeframe: TimeFrame = .fiveYears
    
    enum TimeFrame: String, CaseIterable {
        case oneYear = "1 Year"
        case threeYears = "3 Years"
        case fiveYears = "5 Years"
        case tenYears = "10 Years"
        
        var timeInterval: TimeInterval {
            switch self {
            case .oneYear:
                return 365 * 24 * 60 * 60
            case .threeYears:
                return 3 * 365 * 24 * 60 * 60
            case .fiveYears:
                return 5 * 365 * 24 * 60 * 60
            case .tenYears:
                return 10 * 365 * 24 * 60 * 60
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Property Value Prediction
                if let prediction = scenario.propertyValuePrediction {
                    AIInsightCard(
                        title: "Property Value Forecast",
                        insights: [
                            .init(
                                title: "Current Value",
                                value: scenario.principalAmount.formatted(.currency(code: "USD")),
                                description: nil
                            ),
                            .init(
                                title: "Predicted Value",
                                value: prediction.predictedValue.formatted(.currency(code: "USD")),
                                description: "Estimated value after \(selectedTimeframe.rawValue)"
                            ),
                            .init(
                                title: "Potential Appreciation",
                                value: String(format: "%.1f%%", 
                                    ((prediction.predictedValue - scenario.principalAmount) / 
                                     scenario.principalAmount) * 100),
                                description: "Based on market trends and location analysis"
                            )
                        ],
                        confidence: prediction.confidence,
                        type: prediction.predictedValue > scenario.principalAmount ? .positive : .negative
                    )
                    
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                // Risk Assessment
                if let risk = scenario.riskAssessment {
                    AIInsightCard(
                        title: "Risk Assessment",
                        insights: risk.riskFactors.map { factor in
                            .init(
                                title: factor.type.rawValue,
                                value: String(format: "%.0f%%", factor.severity * 100),
                                description: factor.description
                            )
                        },
                        confidence: risk.confidenceLevel,
                        type: risk.riskScore > 70 ? .positive : 
                              risk.riskScore > 40 ? .neutral : .negative
                    )
                }
                
                // AI Recommendations
                if let recommendations = scenario.aiRecommendations {
                    AIInsightCard(
                        title: "Smart Recommendations",
                        insights: [
                            .init(
                                title: "Recommended Loan Term",
                                value: "\(recommendations.recommendedLoanTerm) years",
                                description: recommendations.reasoning.first
                            ),
                            .init(
                                title: "Recommended Down Payment",
                                value: recommendations.recommendedDownPayment.formatted(.currency(code: "USD")),
                                description: recommendations.reasoning.last
                            ),
                            .init(
                                title: "Target Interest Rate",
                                value: String(format: "%.2f%%", recommendations.recommendedInterestRate * 100),
                                description: "Based on your credit profile and market conditions"
                            )
                        ],
                        confidence: recommendations.confidence,
                        type: .neutral
                    )
                }
                
                // Update Button
                Button(action: {
                    Task {
                        await updateAIInsights()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Update AI Insights", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                if let lastUpdate = scenario.lastAIUpdateDate {
                    Text("Last updated: \(lastUpdate.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("AI Insights")
    }
    
    private func updateAIInsights() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create a sample user profile (in production, this would come from user data)
            let userProfile = UserProfile(
                annualIncome: 120000,
                creditScore: 750,
                employmentYears: 5,
                location: "Sample Location",
                existingDebts: 10000,
                monthlyExpenses: 3000
            )
            
            try await AIManager().analyzeScenario(scenario, userProfile: userProfile)
        } catch {
            print("Error updating AI insights: \(error)")
        }
    }
}