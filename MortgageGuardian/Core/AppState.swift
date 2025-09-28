import SwiftUI

enum Tab {
    case calculator
    case scenarios
    case settings
}

@Observable
class AppState {
    var selectedTab: Tab = .calculator
    var savedScenarios: [MortgageScenario] = []
    
    // App settings
    var defaultLoanTerm: Int = 30
    var defaultInterestRate: Double = 6.5
    
    func saveScenario(_ scenario: MortgageScenario) {
        savedScenarios.append(scenario)
        // TODO: Implement persistence
    }
}