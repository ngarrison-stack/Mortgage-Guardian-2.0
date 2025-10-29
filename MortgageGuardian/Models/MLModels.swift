import CoreML
import Foundation
import SwiftUI
import OSLog

struct PropertyValuePrediction: Codable {
    let predictedValue: Double
    let confidence: Double
    let timeframe: TimeInterval
}

struct MortgageRiskAssessment {
    let riskScore: Double // 0-100
    let confidenceLevel: Double
    let riskFactors: [RiskFactor]
    
    struct RiskFactor {
        let type: RiskFactorType
        let severity: Double // 0-1
        let description: String
    }
    
    enum RiskFactorType {
        case debtToIncome
        case propertyMarket
        case interestRateVolatility
        case employmentStability
        case propertyCondition
        case economicIndicators
    }
}

enum MLPredictorError: LocalizedError {
    case modelNotFound(String)
    case invalidInput(String)
    case predictionFailed(Error)
    case modelLoadingFailed(Error)
    case marketDataUnavailable

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "ML model not found: \(model)"
        case .invalidInput(let reason):
            return "Invalid input data: \(reason)"
        case .predictionFailed(let error):
            return "Prediction failed: \(error.localizedDescription)"
        case .modelLoadingFailed(let error):
            return "Model loading failed: \(error.localizedDescription)"
        case .marketDataUnavailable:
            return "Market data unavailable for enhanced predictions"
        }
    }
}

struct MortgageRecommendation {
    let recommendedLoanTerm: Int
    let recommendedDownPayment: Double
    let recommendedInterestRate: Double
    let confidence: Double
    let reasoning: [String]
}

@MainActor
@Observable
class MLPredictor {
    static let shared = MLPredictor()

    // CoreML Models
    private var propertyValueModel: MLModel?
    private var riskAssessmentModel: MLModel?
    private var recommendationModel: MLModel?

    // Services
    private let marketDataService = MarketDataService()
    private let logger = Logger(subsystem: "com.mortgageguardian.ml", category: "MLPredictor")

    // Model metadata and caching
    private var modelPerformanceMetrics: [String: Double] = [:]
    private let cache = NSCache<NSString, NSData>()
    private var lastModelUpdate: Date?

    // Configuration
    private let maxCacheAge: TimeInterval = 3600 // 1 hour
    private let fallbackConfidenceThreshold: Double = 0.7

    private init() {
        setupCache()
        loadModels()
    }

    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    // MARK: - Model Loading

    private func loadModels() {
        Task {
            await loadPropertyValueModel()
            await createFallbackModels()
        }
    }

    private func loadPropertyValueModel() async {
        do {
            // Try to load compiled model first
            if let compiledURL = Bundle.main.url(forResource: "PropertyValuePredictor", withExtension: "mlmodelc") {
                propertyValueModel = try MLModel(contentsOf: compiledURL)
                logger.info("Loaded compiled PropertyValuePredictor model")
            }
            // Fallback to .mlmodel file
            else if let modelURL = Bundle.main.url(forResource: "PropertyValuePredictor", withExtension: "mlmodel") {
                propertyValueModel = try MLModel(contentsOf: modelURL)
                logger.info("Loaded PropertyValuePredictor.mlmodel")
            } else {
                logger.warning("PropertyValuePredictor model not found in bundle")
            }

            lastModelUpdate = Date()
        } catch {
            logger.error("Failed to load PropertyValuePredictor model: \(error.localizedDescription)")
        }
    }

    private func createFallbackModels() async {
        // For now, we'll use algorithmic approaches as fallbacks
        // In a production app, these would be actual trained CoreML models
        logger.info("Using algorithmic fallbacks for risk assessment and recommendations")
    }

    // MARK: - Property Value Prediction

    func predictPropertyValue(
        currentValue: Double,
        location: String,
        propertyType: String,
        timeframe: TimeInterval
    ) async throws -> PropertyValuePrediction {
        logger.info("Predicting property value for \(propertyType) in \(location)")

        // Validate inputs
        guard currentValue > 0 else {
            throw MLPredictorError.invalidInput("Current value must be greater than 0")
        }
        guard timeframe > 0 else {
            throw MLPredictorError.invalidInput("Timeframe must be positive")
        }

        // Check cache first
        let cacheKey = "property_value_\(currentValue)_\(location)_\(propertyType)_\(Int(timeframe))"
        if let cachedData = getCachedPrediction(key: cacheKey) {
            logger.info("Returning cached property value prediction")
            return cachedData
        }

        var prediction: PropertyValuePrediction

        // Try CoreML model first
        if let model = propertyValueModel {
            prediction = try await predictWithCoreMLModel(
                model: model,
                currentValue: currentValue,
                location: location,
                propertyType: propertyType,
                timeframe: timeframe
            )
        } else {
            // Fallback to algorithmic prediction
            prediction = try await predictWithAlgorithm(
                currentValue: currentValue,
                location: location,
                propertyType: propertyType,
                timeframe: timeframe
            )
        }

        // Cache the result
        cachePrediction(key: cacheKey, prediction: prediction)

        return prediction
    }

    private func predictWithCoreMLModel(
        model: MLModel,
        currentValue: Double,
        location: String,
        propertyType: String,
        timeframe: TimeInterval
    ) async throws -> PropertyValuePrediction {
        do {
            // Get market data for enhanced prediction
            await marketDataService.refreshMarketData()
            let marketData = marketDataService.currentMarketData

            // Prepare input features
            let inputFeatures = try await preparePropertyValueInputs(
                currentValue: currentValue,
                location: location,
                propertyType: propertyType,
                timeframe: timeframe,
                marketData: marketData
            )

            // Make prediction
            let prediction = try model.prediction(from: inputFeatures)

            // Extract predicted value and confidence
            let predictedValue = extractPredictedValue(from: prediction)
            let confidence = extractConfidence(from: prediction)

            logger.info("CoreML prediction: \(predictedValue) with confidence \(confidence)")

            return PropertyValuePrediction(
                predictedValue: predictedValue,
                confidence: confidence,
                timeframe: timeframe
            )
        } catch {
            logger.error("CoreML prediction failed: \(error.localizedDescription)")
            throw MLPredictorError.predictionFailed(error)
        }
    }

    private func predictWithAlgorithm(
        currentValue: Double,
        location: String,
        propertyType: String,
        timeframe: TimeInterval
    ) async throws -> PropertyValuePrediction {
        logger.info("Using algorithmic fallback for property value prediction")

        // Get market data
        await marketDataService.refreshMarketData()
        guard let marketData = marketDataService.currentMarketData else {
            throw MLPredictorError.marketDataUnavailable
        }

        // Calculate appreciation based on multiple factors
        let years = timeframe / (365.25 * 24 * 3600) // Convert to years

        // Base appreciation rate from market trends
        let baseAppreciation = marketData.marketTrends.forecastedChange

        // Adjust for property type
        let propertyMultiplier = getPropertyTypeMultiplier(propertyType)

        // Adjust for market conditions
        let marketMultiplier = calculateMarketMultiplier(marketData: marketData)

        // Calculate final appreciation rate
        let adjustedAppreciation = baseAppreciation * propertyMultiplier * marketMultiplier

        // Apply compound growth
        let predictedValue = currentValue * pow(1 + adjustedAppreciation, years)

        // Calculate confidence based on data quality
        let confidence = calculatePredictionConfidence(
            marketData: marketData,
            timeframe: timeframe,
            hasMLModel: false
        )

        return PropertyValuePrediction(
            predictedValue: predictedValue,
            confidence: confidence,
            timeframe: timeframe
        )
    }

    // MARK: - Risk Assessment

    func assessMortgageRisk(
        scenario: SavedMortgageScenario,
        annualIncome: Double,
        creditScore: Int,
        employmentYears: Double
    ) async throws -> MortgageRiskAssessment {
        logger.info("Assessing mortgage risk for scenario: \(scenario.name)")

        // Validate inputs
        guard annualIncome > 0 else {
            throw MLPredictorError.invalidInput("Annual income must be greater than 0")
        }
        guard creditScore >= 300 && creditScore <= 850 else {
            throw MLPredictorError.invalidInput("Credit score must be between 300 and 850")
        }

        // Calculate comprehensive risk assessment
        let riskFactors = await calculateRiskFactors(
            scenario: scenario,
            annualIncome: annualIncome,
            creditScore: creditScore,
            employmentYears: employmentYears
        )

        // Calculate overall risk score (0-100, where 100 is highest risk)
        let riskScore = calculateOverallRiskScore(riskFactors: riskFactors)

        // Calculate confidence based on data completeness
        let confidence = calculateRiskAssessmentConfidence(
            scenario: scenario,
            annualIncome: annualIncome,
            creditScore: creditScore,
            employmentYears: employmentYears
        )

        return MortgageRiskAssessment(
            riskScore: riskScore,
            confidenceLevel: confidence,
            riskFactors: riskFactors
        )
    }

    // MARK: - Smart Recommendations

    func generateRecommendations(
        desiredPrice: Double,
        annualIncome: Double,
        creditScore: Int,
        location: String,
        savingsAmount: Double
    ) async throws -> MortgageRecommendation {
        logger.info("Generating mortgage recommendations for \(location)")

        // Validate inputs
        guard desiredPrice > 0 else {
            throw MLPredictorError.invalidInput("Desired price must be greater than 0")
        }
        guard annualIncome > 0 else {
            throw MLPredictorError.invalidInput("Annual income must be greater than 0")
        }

        // Get market data
        await marketDataService.refreshMarketData()
        let marketData = marketDataService.currentMarketData

        // Calculate optimal loan term
        let recommendedTerm = calculateOptimalLoanTerm(
            price: desiredPrice,
            income: annualIncome,
            creditScore: creditScore,
            savings: savingsAmount
        )

        // Calculate optimal down payment
        let recommendedDownPayment = calculateOptimalDownPayment(
            price: desiredPrice,
            income: annualIncome,
            creditScore: creditScore,
            savings: savingsAmount
        )

        // Estimate interest rate based on credit score and market conditions
        let recommendedRate = estimateInterestRate(
            creditScore: creditScore,
            marketData: marketData
        )

        // Generate reasoning
        let reasoning = generateRecommendationReasoning(
            desiredPrice: desiredPrice,
            annualIncome: annualIncome,
            creditScore: creditScore,
            savingsAmount: savingsAmount,
            recommendedTerm: recommendedTerm,
            recommendedDownPayment: recommendedDownPayment,
            recommendedRate: recommendedRate,
            marketData: marketData
        )

        // Calculate confidence
        let confidence = calculateRecommendationConfidence(
            marketData: marketData,
            creditScore: creditScore,
            hasCompleteData: true
        )

        return MortgageRecommendation(
            recommendedLoanTerm: recommendedTerm,
            recommendedDownPayment: recommendedDownPayment,
            recommendedInterestRate: recommendedRate,
            confidence: confidence,
            reasoning: reasoning
        )
    }

    // MARK: - Helper Methods

    private func preparePropertyValueInputs(
        currentValue: Double,
        location: String,
        propertyType: String,
        timeframe: TimeInterval,
        marketData: MarketDataService.MarketData?
    ) async throws -> MLFeatureProvider {
        // This would prepare the actual input features for the CoreML model
        // For now, we'll create a basic feature provider
        let features: [String: Any] = [
            "current_value": currentValue,
            "timeframe_years": timeframe / (365.25 * 24 * 3600),
            "market_trend": marketData?.marketTrends.yearOverYearChange ?? 0.03,
            "property_type_encoded": encodePropertyType(propertyType)
        ]

        return try MLDictionaryFeatureProvider(dictionary: features)
    }

    private func extractPredictedValue(from prediction: MLFeatureProvider) -> Double {
        // Extract the predicted value from the CoreML model output
        // This depends on the actual model's output structure
        return prediction.featureValue(for: "predicted_value")?.doubleValue ?? 0.0
    }

    private func extractConfidence(from prediction: MLFeatureProvider) -> Double {
        // Extract confidence from the model output
        return prediction.featureValue(for: "confidence")?.doubleValue ?? 0.8
    }

    // MARK: - Public Model Management

    func getModelStatus() -> (propertyValue: Bool, riskAssessment: Bool, recommendations: Bool) {
        return (
            propertyValue: propertyValueModel != nil,
            riskAssessment: true, // Always available via algorithms
            recommendations: true // Always available via algorithms
        )
    }

    func reloadModels() async {
        await loadModels()
    }

    func clearCache() {
        cache.removeAllObjects()
        logger.info("Cleared ML prediction cache")
    }

    func getPerformanceMetrics() -> [String: Double] {
        return modelPerformanceMetrics
    }
}