import SwiftUI
import CoreML
import Combine

@MainActor
class MortgageAICoordinator: ObservableObject {
    private let marketDataService = MarketDataService()
    private let mlPredictor = MLPredictor.shared
    private var propertyValueModel: MLModel?
    private var riskAssessmentModel: MLModel?
    private var recommendationModel: MLModel?
    
    // Services state
    @Published private(set) var isTrainingModels = false
    @Published private(set) var lastModelUpdate: Date?
    @Published private(set) var modelAccuracy: Double?
    
    init() {
        loadModels()
        setupPeriodicModelUpdates()
    }
    
    private func loadModels() {
        // Load compiled models from bundle
        do {
            if let modelURL = Bundle.main.url(forResource: "PropertyValuePredictor", withExtension: "mlmodelc") {
                propertyValueModel = try MLModel(contentsOf: modelURL)
            }
            // Load other models similarly
        } catch {
            print("Error loading models: \(error)")
        }
    }
    
    private func setupPeriodicModelUpdates() {
        // Schedule periodic model retraining (e.g., weekly)
        Task {
            while true {
                await updateModelsIfNeeded()
                try? await Task.sleep(nanoseconds: 7 * 24 * 60 * 60 * 1_000_000_000) // Weekly
            }
        }
    }
    
    func updateModelsIfNeeded() async {
        guard !isTrainingModels else { return }
        isTrainingModels = true
        defer { isTrainingModels = false }
        
        do {
            // Get latest market data
            await marketDataService.refreshMarketData()
            
            // TODO: Implement model training
            // let trainer = MLModelTrainer(...)
            // try await trainer.trainPropertyValueModel()
            print("Model training not yet implemented")
            
            // Reload models
            loadModels()
            
            lastModelUpdate = Date()
        } catch {
            print("Error updating models: \(error)")
        }
    }
    
    func analyzeScenario(_ scenario: SavedMortgageScenario, userProfile: UserProfile) async throws {
        // Get latest market data
        await marketDataService.refreshMarketData()

        do {
            // Perform comprehensive AI analysis using MLPredictor

            // 1. Property Value Prediction (if property info available)
            if let propertyValue = scenario.principalAmount + scenario.downPayment {
                let propertyPrediction = try await mlPredictor.predictPropertyValue(
                    currentValue: propertyValue,
                    location: userProfile.location,
                    propertyType: "single_family", // Default, could be enhanced with property type selection
                    timeframe: TimeInterval(scenario.loanTermYears * 365 * 24 * 3600) // Convert years to seconds
                )
                scenario.propertyValuePrediction = propertyPrediction
            }

            // 2. Risk Assessment
            let riskAssessment = try await mlPredictor.assessMortgageRisk(
                scenario: scenario,
                annualIncome: userProfile.annualIncome,
                creditScore: userProfile.creditScore,
                employmentYears: userProfile.employmentYears
            )
            scenario.riskAssessment = riskAssessment

            // 3. Generate Recommendations
            let recommendations = try await mlPredictor.generateRecommendations(
                desiredPrice: scenario.principalAmount + scenario.downPayment,
                annualIncome: userProfile.annualIncome,
                creditScore: userProfile.creditScore,
                location: userProfile.location,
                savingsAmount: scenario.downPayment * 1.5 // Estimate available savings
            )
            scenario.aiRecommendations = recommendations

            scenario.lastAIUpdateDate = Date()

            print("✅ AI analysis completed for scenario \(scenario.name)")
            print("- Risk Score: \(riskAssessment.riskScore)")
            print("- Property Value Prediction: \(scenario.propertyValuePrediction?.predictedValue ?? 0)")
            print("- Recommended Loan Term: \(recommendations.recommendedLoanTerm) years")

        } catch {
            print("❌ AI analysis failed for scenario \(scenario.name): \(error.localizedDescription)")
            throw error
        }
    }
    
    func exportModelMetrics() -> String {
        // Generate a report of model performance metrics
        var report = "AI Model Performance Report\n"
        report += "================================\n"
        report += "Last Update: \(lastModelUpdate?.formatted() ?? "Never")\n"

        // Get model status from MLPredictor
        let modelStatus = mlPredictor.getModelStatus()
        report += "Property Value Model: \(modelStatus.propertyValue ? "✅ Loaded" : "❌ Not Available")\n"
        report += "Risk Assessment Model: \(modelStatus.riskAssessment ? "✅ Available" : "❌ Not Available")\n"
        report += "Recommendation Model: \(modelStatus.recommendations ? "✅ Available" : "❌ Not Available")\n"

        if let accuracy = modelAccuracy {
            report += "Model Accuracy: \(accuracy * 100)%\n"
        }

        // Add performance metrics from MLPredictor
        let performanceMetrics = mlPredictor.getPerformanceMetrics()
        if !performanceMetrics.isEmpty {
            report += "\nPerformance Metrics:\n"
            for (metric, value) in performanceMetrics {
                report += "- \(metric): \(String(format: "%.3f", value))\n"
            }
        }

        report += "\nTraining Status: \(isTrainingModels ? "In Progress" : "Idle")\n"

        return report
    }

    // MARK: - Additional ML Coordinator Methods

    func reloadMLModels() async {
        await mlPredictor.reloadModels()
        loadModels() // Reload local models too
    }

    func clearMLCache() {
        mlPredictor.clearCache()
    }

    func getModelAvailability() -> (propertyValue: Bool, riskAssessment: Bool, recommendations: Bool) {
        return mlPredictor.getModelStatus()
    }
}