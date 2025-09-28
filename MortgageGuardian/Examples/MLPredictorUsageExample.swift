import Foundation
import CoreML
import SwiftUI

/// Example usage of the MLPredictor class for Mortgage Guardian
/// This demonstrates how to use the comprehensive ML prediction capabilities
class MLPredictorUsageExample {

    /// Example: Property Value Prediction
    static func examplePropertyValuePrediction() async {
        print("🏠 Property Value Prediction Example")
        print("====================================")

        let mlPredictor = MLPredictor.shared

        do {
            // Predict property value in 5 years
            let prediction = try await mlPredictor.predictPropertyValue(
                currentValue: 650000,
                location: "Austin, TX",
                propertyType: "single_family",
                timeframe: TimeInterval(5 * 365 * 24 * 3600) // 5 years in seconds
            )

            print("Current Value: $650,000")
            print("Predicted Value (5 years): $\(Int(prediction.predictedValue))")
            print("Confidence: \(Int(prediction.confidence * 100))%")

            let appreciation = ((prediction.predictedValue - 650000) / 650000) * 100
            print("Total Appreciation: \(String(format: "%.1f", appreciation))%")
            print("Annual Appreciation: \(String(format: "%.1f", appreciation / 5))%")

        } catch {
            print("❌ Prediction failed: \(error.localizedDescription)")
        }
    }

    /// Example: Mortgage Risk Assessment
    static func exampleMortgageRiskAssessment() async {
        print("\n⚠️ Mortgage Risk Assessment Example")
        print("===================================")

        let mlPredictor = MLPredictor.shared

        // Create a sample mortgage scenario
        let scenario = SavedMortgageScenario(
            name: "Dream Home Purchase",
            principalAmount: 520000, // $650k home - $130k down
            annualInterestRate: 6.75,
            loanTermYears: 30,
            downPayment: 130000
        )

        do {
            let riskAssessment = try await mlPredictor.assessMortgageRisk(
                scenario: scenario,
                annualIncome: 120000,
                creditScore: 740,
                employmentYears: 3.5
            )

            print("Risk Score: \(Int(riskAssessment.riskScore))/100")
            print("Confidence: \(Int(riskAssessment.confidenceLevel * 100))%")
            print("Risk Level: \(getRiskLevelDescription(riskAssessment.riskScore))")

            print("\nRisk Factors:")
            for factor in riskAssessment.riskFactors {
                let severity = Int(factor.severity * 100)
                print("  • \(factor.description) (Severity: \(severity)%)")
            }

        } catch {
            print("❌ Risk assessment failed: \(error.localizedDescription)")
        }
    }

    /// Example: Mortgage Recommendations
    static func exampleMortgageRecommendations() async {
        print("\n💡 Mortgage Recommendations Example")
        print("===================================")

        let mlPredictor = MLPredictor.shared

        do {
            let recommendations = try await mlPredictor.generateRecommendations(
                desiredPrice: 750000,
                annualIncome: 150000,
                creditScore: 780,
                location: "Seattle, WA",
                savingsAmount: 200000
            )

            print("Desired Home Price: $750,000")
            print("Annual Income: $150,000")
            print("Credit Score: 780")
            print("Available Savings: $200,000")
            print()

            print("Recommendations:")
            print("  Loan Term: \(recommendations.recommendedLoanTerm) years")
            print("  Down Payment: $\(Int(recommendations.recommendedDownPayment))")
            print("  Interest Rate: \(String(format: "%.3f", recommendations.recommendedInterestRate * 100))%")
            print("  Confidence: \(Int(recommendations.confidence * 100))%")

            // Calculate monthly payment
            let principal = 750000 - recommendations.recommendedDownPayment
            let monthlyRate = recommendations.recommendedInterestRate / 12
            let payments = Double(recommendations.recommendedLoanTerm * 12)
            let monthlyPayment = principal * monthlyRate * pow(1 + monthlyRate, payments) / (pow(1 + monthlyRate, payments) - 1)

            print("  Estimated Monthly Payment: $\(Int(monthlyPayment))")

            let dti = (monthlyPayment * 12) / 150000
            print("  Debt-to-Income Ratio: \(String(format: "%.1f", dti * 100))%")

            print("\nReasoning:")
            for reason in recommendations.reasoning {
                print("  • \(reason)")
            }

        } catch {
            print("❌ Recommendations failed: \(error.localizedDescription)")
        }
    }

    /// Example: Complete ML Analysis Pipeline
    static func exampleCompleteAnalysis() async {
        print("\n🤖 Complete ML Analysis Pipeline Example")
        print("========================================")

        print("Mortgage Guardian 2.0 - ML Predictor Comprehensive Example")
        print("This example demonstrates all three ML capabilities:")
        print("1. Property Value Prediction")
        print("2. Risk Assessment")
        print("3. Personalized Recommendations")
        print()

        // Check model availability
        let mlPredictor = MLPredictor.shared
        let modelStatus = mlPredictor.getModelStatus()

        print("📊 ML Model Status:")
        print("  Property Value Model: \(modelStatus.propertyValue ? "✅ Available" : "❌ Using Algorithms")")
        print("  Risk Assessment: \(modelStatus.riskAssessment ? "✅ Available" : "❌ Unavailable")")
        print("  Recommendations: \(modelStatus.recommendations ? "✅ Available" : "❌ Unavailable")")
        print()

        // Run all examples
        await examplePropertyValuePrediction()
        await exampleMortgageRiskAssessment()
        await exampleMortgageRecommendations()

        // Performance metrics
        let metrics = mlPredictor.getPerformanceMetrics()
        if !metrics.isEmpty {
            print("\n📈 Performance Metrics:")
            for (metric, value) in metrics {
                print("  \(metric): \(String(format: "%.4f", value))")
            }
        }

        print("\n✅ Complete ML analysis pipeline example finished")
        print("The MLPredictor provides production-ready ML capabilities with:")
        print("  • Real CoreML model integration")
        print("  • Intelligent algorithmic fallbacks")
        print("  • Comprehensive error handling")
        print("  • Market data integration")
        print("  • Performance monitoring")
        print("  • Caching for efficiency")
    }

    // Helper functions
    private static func getRiskLevelDescription(_ riskScore: Double) -> String {
        switch riskScore {
        case 0..<25:
            return "Low Risk (Excellent borrower profile)"
        case 25..<50:
            return "Moderate Risk (Good borrower profile)"
        case 50..<75:
            return "High Risk (Fair borrower profile)"
        default:
            return "Very High Risk (Poor borrower profile)"
        }
    }
}

// MARK: - SwiftUI Preview for Testing
struct MLPredictorExampleView: View {
    @State private var isRunning = false
    @State private var output = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MLPredictor Example")
                    .font(.largeTitle)
                    .bold()

                Text("This example demonstrates the comprehensive MLPredictor implementation with real CoreML functionality.")
                    .font(.body)
                    .foregroundColor(.secondary)

                Button(action: runExample) {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isRunning ? "Running..." : "Run ML Example")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isRunning)

                if !output.isEmpty {
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("ML Predictor")
        }
    }

    private func runExample() {
        isRunning = true
        output = ""

        Task {
            // Capture console output
            await MLPredictorUsageExample.exampleCompleteAnalysis()

            await MainActor.run {
                isRunning = false
                output = "Example completed! Check the console for detailed output."
            }
        }
    }
}

#Preview {
    MLPredictorExampleView()
}