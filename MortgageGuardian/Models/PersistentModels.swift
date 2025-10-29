import SwiftUI
import SwiftData

@Model
final class SavedMortgageScenario {
    var name: String
    var principalAmount: Double
    var annualInterestRate: Double
    var loanTermYears: Int
    var downPayment: Double
    var notes: String?
    var createdAt: Date
    
    // AI-powered insights
    var riskAssessment: MortgageRiskAssessment?
    var propertyValuePrediction: PropertyValuePrediction?
    var aiRecommendations: MortgageRecommendation?
    var lastAIUpdateDate: Date?
    
    init(
        name: String = "New Scenario",
        principalAmount: Double,
        annualInterestRate: Double,
        loanTermYears: Int,
        downPayment: Double,
        notes: String? = nil
    ) {
        self.name = name
        self.principalAmount = principalAmount
        self.annualInterestRate = annualInterestRate
        self.loanTermYears = loanTermYears
        self.downPayment = downPayment
        self.notes = notes
        self.createdAt = Date()
    }
    
    var monthlyPayment: Double {
        let principal = principalAmount - downPayment
        let monthlyRate = annualInterestRate / 12 / 100
        let numberOfPayments = Double(loanTermYears * 12)
        
        let numerator = principal * monthlyRate * pow((1 + monthlyRate), numberOfPayments)
        let denominator = pow((1 + monthlyRate), numberOfPayments) - 1
        
        return numerator / denominator
    }
    
    var totalInterest: Double {
        (monthlyPayment * Double(loanTermYears * 12)) - (principalAmount - downPayment)
    }
}

@Model
final class UserSettings {
    var defaultLoanTerm: Int
    var defaultInterestRate: Double
    var useLocalCurrency: Bool
    var includePMI: Bool
    var includePropertyTax: Bool
    var includeHomeInsurance: Bool
    var lastUpdated: Date
    
    init(
        defaultLoanTerm: Int = 30,
        defaultInterestRate: Double = 6.5,
        useLocalCurrency: Bool = false,
        includePMI: Bool = true,
        includePropertyTax: Bool = true,
        includeHomeInsurance: Bool = true
    ) {
        self.defaultLoanTerm = defaultLoanTerm
        self.defaultInterestRate = defaultInterestRate
        self.useLocalCurrency = useLocalCurrency
        self.includePMI = includePMI
        self.includePropertyTax = includePropertyTax
        self.includeHomeInsurance = includeHomeInsurance
        self.lastUpdated = Date()
    }
}