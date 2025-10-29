import SwiftUI
import SwiftData

@Model
final class UserProfile {
    var annualIncome: Double
    var creditScore: Int
    var employmentYears: Double
    var location: String
    var existingDebts: Double
    var monthlyExpenses: Double
    var lastUpdated: Date
    
    // Financial ratios
    var debtToIncomeRatio: Double {
        (existingDebts + monthlyExpenses * 12) / annualIncome
    }
    
    // Credit profile
    var creditTier: CreditTier {
        switch creditScore {
        case 800...:
            return .exceptional
        case 740...799:
            return .excellent
        case 670...739:
            return .good
        case 580...669:
            return .fair
        default:
            return .poor
        }
    }
    
    enum CreditTier: String {
        case exceptional
        case excellent
        case good
        case fair
        case poor
        
        var recommendedLTV: Double {
            switch self {
            case .exceptional: return 0.95
            case .excellent: return 0.90
            case .good: return 0.85
            case .fair: return 0.80
            case .poor: return 0.75
            }
        }
        
        var color: Color {
            switch self {
            case .exceptional: return .green
            case .excellent: return .mint
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
    
    init(
        annualIncome: Double = 0,
        creditScore: Int = 650,
        employmentYears: Double = 0,
        location: String = "",
        existingDebts: Double = 0,
        monthlyExpenses: Double = 0
    ) {
        self.annualIncome = annualIncome
        self.creditScore = creditScore
        self.employmentYears = employmentYears
        self.location = location
        self.existingDebts = existingDebts
        self.monthlyExpenses = monthlyExpenses
        self.lastUpdated = Date()
    }
}