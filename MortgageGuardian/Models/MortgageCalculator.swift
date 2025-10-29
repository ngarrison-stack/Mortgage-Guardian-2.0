import Foundation

struct MortgageCalculation {
    let principalAmount: Double
    let annualInterestRate: Double
    let loanTermYears: Int
    let downPayment: Double
    
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

struct MortgageScenario: Identifiable {
    let id = UUID()
    let calculation: MortgageCalculation
    let date: Date
    let notes: String?
}