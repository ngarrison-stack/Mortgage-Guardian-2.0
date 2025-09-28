import SwiftUI
import SwiftData

@Observable
class DataManager {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: SavedMortgageScenario.self, UserSettings.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            modelContext = modelContainer.mainContext
            
            // Initialize default settings if none exist
            if try modelContext.fetch(FetchDescriptor<UserSettings>()).isEmpty {
                let defaultSettings = UserSettings()
                modelContext.insert(defaultSettings)
                try modelContext.save()
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    func fetchScenarios() throws -> [SavedMortgageScenario] {
        let descriptor = FetchDescriptor<SavedMortgageScenario>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func saveScenario(
        name: String = "New Scenario",
        principalAmount: Double,
        annualInterestRate: Double,
        loanTermYears: Int,
        downPayment: Double,
        notes: String? = nil
    ) throws {
        let scenario = SavedMortgageScenario(
            name: name,
            principalAmount: principalAmount,
            annualInterestRate: annualInterestRate,
            loanTermYears: loanTermYears,
            downPayment: downPayment,
            notes: notes
        )
        modelContext.insert(scenario)
        try modelContext.save()
    }
    
    func deleteScenario(_ scenario: SavedMortgageScenario) throws {
        modelContext.delete(scenario)
        try modelContext.save()
    }
    
    func fetchSettings() throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        let settings = try modelContext.fetch(descriptor)
        return settings.first ?? UserSettings()
    }
    
    func updateSettings(_ settings: UserSettings) throws {
        try modelContext.save()
    }
    
    func clearAllData() throws {
        try modelContext.delete(model: SavedMortgageScenario.self)
        try modelContext.delete(model: UserSettings.self)
        let defaultSettings = UserSettings()
        modelContext.insert(defaultSettings)
        try modelContext.save()
    }
}