import Foundation
import CoreML
import SwiftUI

// MARK: - MLPredictor Helper Methods Extension
extension MLPredictor {

    // MARK: - Property Type and Market Calculations

    func encodePropertyType(_ type: String) -> Double {
        switch type.lowercased() {
        case "single_family", "single family": return 1.0
        case "condo", "condominium": return 2.0
        case "townhouse", "townhome": return 3.0
        case "multi_family", "multi family": return 4.0
        default: return 1.0
        }
    }

    func getPropertyTypeMultiplier(_ type: String) -> Double {
        switch type.lowercased() {
        case "single_family", "single family": return 1.0
        case "condo", "condominium": return 0.95
        case "townhouse", "townhome": return 0.98
        case "multi_family", "multi family": return 1.05
        default: return 1.0
        }
    }

    func calculateMarketMultiplier(marketData: MarketDataService.MarketData) -> Double {
        let heatIndex = marketData.marketTrends.marketHeatIndex
        let inventoryLevel = marketData.regionalData.inventoryLevel

        // High heat + low inventory = higher appreciation
        let multiplier = 0.8 + (heatIndex * 0.3) + ((2.0 - inventoryLevel) * 0.1)
        return max(0.7, min(1.3, multiplier)) // Clamp between 0.7 and 1.3
    }

    func calculatePredictionConfidence(
        marketData: MarketDataService.MarketData?,
        timeframe: TimeInterval,
        hasMLModel: Bool
    ) -> Double {
        var confidence = hasMLModel ? 0.85 : 0.75

        // Reduce confidence for longer timeframes
        let years = timeframe / (365.25 * 24 * 3600)
        if years > 5 {
            confidence *= 0.8
        } else if years > 2 {
            confidence *= 0.9
        }

        // Reduce confidence if market data is unavailable
        if marketData == nil {
            confidence *= 0.8
        }

        return max(0.5, min(0.95, confidence))
    }

    // MARK: - Risk Assessment Helpers

    func calculateRiskFactors(
        scenario: SavedMortgageScenario,
        annualIncome: Double,
        creditScore: Int,
        employmentYears: Double
    ) async -> [MortgageRiskAssessment.RiskFactor] {
        var riskFactors: [MortgageRiskAssessment.RiskFactor] = []

        // Debt-to-Income Ratio
        let monthlyIncome = annualIncome / 12
        let debtToIncomeRatio = scenario.monthlyPayment / monthlyIncome
        let dtiSeverity = calculateDTISeverity(ratio: debtToIncomeRatio)

        riskFactors.append(.init(
            type: .debtToIncome,
            severity: dtiSeverity,
            description: "DTI ratio: \(String(format: "%.1f", debtToIncomeRatio * 100))% (\(getDTIRiskDescription(severity: dtiSeverity)))"
        ))

        // Credit Score Risk
        let creditSeverity = calculateCreditSeverity(score: creditScore)
        riskFactors.append(.init(
            type: .employmentStability,
            severity: creditSeverity,
            description: "Credit score: \(creditScore) (\(getCreditRiskDescription(severity: creditSeverity)))"
        ))

        // Employment Stability
        let employmentSeverity = calculateEmploymentSeverity(years: employmentYears)
        riskFactors.append(.init(
            type: .employmentStability,
            severity: employmentSeverity,
            description: "Employment: \(String(format: "%.1f", employmentYears)) years (\(getEmploymentRiskDescription(severity: employmentSeverity)))"
        ))

        // Market Conditions
        await marketDataService.refreshMarketData()
        if let marketData = marketDataService.currentMarketData {
            let marketSeverity = calculateMarketRiskSeverity(marketData: marketData)
            riskFactors.append(.init(
                type: .propertyMarket,
                severity: marketSeverity,
                description: "Market conditions: \(getMarketRiskDescription(severity: marketSeverity))"
            ))

            // Interest Rate Volatility
            let rateSeverity = calculateInterestRateRiskSeverity(marketData: marketData)
            riskFactors.append(.init(
                type: .interestRateVolatility,
                severity: rateSeverity,
                description: "Interest rate risk: \(getRateRiskDescription(severity: rateSeverity))"
            ))
        }

        return riskFactors
    }

    func calculateDTISeverity(ratio: Double) -> Double {
        if ratio <= 0.28 { return 0.1 }
        if ratio <= 0.36 { return 0.3 }
        if ratio <= 0.43 { return 0.6 }
        return 0.9
    }

    func calculateCreditSeverity(score: Int) -> Double {
        if score >= 740 { return 0.1 }
        if score >= 670 { return 0.3 }
        if score >= 580 { return 0.6 }
        return 0.9
    }

    func calculateEmploymentSeverity(years: Double) -> Double {
        if years >= 2 { return 0.1 }
        if years >= 1 { return 0.4 }
        if years >= 0.5 { return 0.7 }
        return 0.9
    }

    func calculateMarketRiskSeverity(marketData: MarketDataService.MarketData) -> Double {
        let heatIndex = marketData.marketTrends.marketHeatIndex
        let volatility = abs(marketData.marketTrends.monthOverMonthChange)

        if heatIndex > 0.8 && volatility > 0.02 { return 0.7 }
        if heatIndex > 0.9 { return 0.5 }
        if volatility > 0.03 { return 0.6 }
        return 0.2
    }

    func calculateInterestRateRiskSeverity(marketData: MarketDataService.MarketData) -> Double {
        let currentRate = marketData.averageMortgageRate
        let fedRate = marketData.federalRate

        // Higher spread indicates higher risk
        let spread = currentRate - fedRate
        if spread > 0.03 { return 0.7 }
        if spread > 0.02 { return 0.4 }
        return 0.2
    }

    func calculateOverallRiskScore(riskFactors: [MortgageRiskAssessment.RiskFactor]) -> Double {
        let weights: [MortgageRiskAssessment.RiskFactorType: Double] = [
            .debtToIncome: 0.3,
            .employmentStability: 0.25,
            .propertyMarket: 0.2,
            .interestRateVolatility: 0.15,
            .propertyCondition: 0.05,
            .economicIndicators: 0.05
        ]

        let weightedScore = riskFactors.reduce(0.0) { total, factor in
            let weight = weights[factor.type] ?? 0.0
            return total + (factor.severity * weight * 100)
        }

        return max(0, min(100, weightedScore))
    }

    func calculateRiskAssessmentConfidence(
        scenario: SavedMortgageScenario,
        annualIncome: Double,
        creditScore: Int,
        employmentYears: Double
    ) -> Double {
        var confidence = 0.9

        // Reduce confidence for missing or questionable data
        if annualIncome <= 0 { confidence -= 0.2 }
        if creditScore < 300 || creditScore > 850 { confidence -= 0.1 }
        if employmentYears < 0 { confidence -= 0.1 }

        return max(0.5, confidence)
    }

    // MARK: - Recommendation Helpers

    func calculateOptimalLoanTerm(
        price: Double,
        income: Double,
        creditScore: Int,
        savings: Double
    ) -> Int {
        let monthlyIncome = income / 12
        let maxPayment = monthlyIncome * 0.28 // 28% DTI rule

        // Test different terms to find optimal
        let terms = [15, 20, 25, 30]
        for term in terms {
            let principal = price * 0.8 // Assume 20% down
            let rate = estimateInterestRate(creditScore: creditScore, marketData: nil)
            let monthlyRate = rate / 12
            let payments = Double(term * 12)

            let monthlyPayment = principal * monthlyRate * pow(1 + monthlyRate, payments) / (pow(1 + monthlyRate, payments) - 1)

            if monthlyPayment <= maxPayment {
                return term
            }
        }

        return 30 // Default to 30 years if nothing fits
    }

    func calculateOptimalDownPayment(
        price: Double,
        income: Double,
        creditScore: Int,
        savings: Double
    ) -> Double {
        let maxDownPayment = savings * 0.8 // Keep 20% of savings as emergency fund
        let minimumDown = price * 0.03 // 3% minimum
        let preferredDown = price * 0.2 // 20% to avoid PMI

        if maxDownPayment >= preferredDown {
            return preferredDown
        } else if maxDownPayment >= minimumDown {
            return maxDownPayment
        } else {
            return minimumDown
        }
    }

    func estimateInterestRate(
        creditScore: Int,
        marketData: MarketDataService.MarketData?
    ) -> Double {
        let baseRate = marketData?.averageMortgageRate ?? 0.065

        // Adjust based on credit score
        let creditAdjustment: Double
        if creditScore >= 740 {
            creditAdjustment = -0.005
        } else if creditScore >= 670 {
            creditAdjustment = 0.0
        } else if creditScore >= 580 {
            creditAdjustment = 0.01
        } else {
            creditAdjustment = 0.02
        }

        return baseRate + creditAdjustment
    }

    func generateRecommendationReasoning(
        desiredPrice: Double,
        annualIncome: Double,
        creditScore: Int,
        savingsAmount: Double,
        recommendedTerm: Int,
        recommendedDownPayment: Double,
        recommendedRate: Double,
        marketData: MarketDataService.MarketData?
    ) -> [String] {
        var reasoning: [String] = []

        // Income-based reasoning
        let monthlyIncome = annualIncome / 12
        let principal = desiredPrice - recommendedDownPayment
        let monthlyRate = recommendedRate / 12
        let payments = Double(recommendedTerm * 12)
        let monthlyPayment = principal * monthlyRate * pow(1 + monthlyRate, payments) / (pow(1 + monthlyRate, payments) - 1)
        let dti = monthlyPayment / monthlyIncome

        reasoning.append("Monthly payment of $\(Int(monthlyPayment)) represents \(String(format: "%.1f", dti * 100))% of gross income")

        // Credit score reasoning
        if creditScore >= 740 {
            reasoning.append("Excellent credit score qualifies for best available rates")
        } else if creditScore >= 670 {
            reasoning.append("Good credit score qualifies for competitive rates")
        } else {
            reasoning.append("Credit score may result in higher interest rates")
        }

        // Down payment reasoning
        let downPaymentPercent = recommendedDownPayment / desiredPrice
        if downPaymentPercent >= 0.2 {
            reasoning.append("20% down payment avoids PMI and reduces monthly costs")
        } else {
            reasoning.append("Lower down payment preserves cash but may require PMI")
        }

        // Market conditions
        if let marketData = marketData {
            if marketData.marketTrends.marketHeatIndex > 0.8 {
                reasoning.append("Hot market conditions suggest acting quickly on opportunities")
            }
            if marketData.marketTrends.forecastedChange > 0.03 {
                reasoning.append("Property values expected to appreciate above average")
            }
        }

        return reasoning
    }

    func calculateRecommendationConfidence(
        marketData: MarketDataService.MarketData?,
        creditScore: Int,
        hasCompleteData: Bool
    ) -> Double {
        var confidence = 0.85

        if marketData == nil { confidence -= 0.1 }
        if !hasCompleteData { confidence -= 0.1 }
        if creditScore < 580 { confidence -= 0.05 }

        return max(0.6, confidence)
    }

    // MARK: - Risk Description Helpers

    func getDTIRiskDescription(severity: Double) -> String {
        if severity <= 0.2 { return "Low risk" }
        if severity <= 0.4 { return "Moderate risk" }
        if severity <= 0.7 { return "High risk" }
        return "Very high risk"
    }

    func getCreditRiskDescription(severity: Double) -> String {
        if severity <= 0.2 { return "Excellent" }
        if severity <= 0.4 { return "Good" }
        if severity <= 0.7 { return "Fair" }
        return "Poor"
    }

    func getEmploymentRiskDescription(severity: Double) -> String {
        if severity <= 0.2 { return "Stable" }
        if severity <= 0.5 { return "Moderately stable" }
        if severity <= 0.8 { return "Less stable" }
        return "Unstable"
    }

    func getMarketRiskDescription(severity: Double) -> String {
        if severity <= 0.3 { return "Stable market" }
        if severity <= 0.6 { return "Moderate volatility" }
        return "High volatility"
    }

    func getRateRiskDescription(severity: Double) -> String {
        if severity <= 0.3 { return "Low rate risk" }
        if severity <= 0.6 { return "Moderate rate risk" }
        return "High rate risk"
    }

    // MARK: - Caching Methods

    func getCachedPrediction(key: String) -> PropertyValuePrediction? {
        guard let data = cache.object(forKey: NSString(string: key)) as Data?,
              let prediction = try? JSONDecoder().decode(PropertyValuePrediction.self, from: data) else {
            return nil
        }
        return prediction
    }

    func cachePrediction(key: String, prediction: PropertyValuePrediction) {
        guard let data = try? JSONEncoder().encode(prediction) else { return }
        cache.setObject(data as NSData, forKey: NSString(string: key))
    }
}