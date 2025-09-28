import SwiftUI

struct ScenarioListView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var scenarios: [MortgageScenario] = []
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if scenarios.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "house.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.Colors.light.gradient)
                        
                        Text("No Scenarios Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Save mortgage calculations to compare different scenarios")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        
                        BrandedButton("Add First Scenario") {
                            showingAddSheet = true
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(scenarios) { scenario in
                                ScenarioListItem(
                                    title: "Scenario \(scenarios.firstIndex(where: { $0.id == scenario.id })! + 1)",
                                    subtitle: scenario.notes ?? "No notes",
                                    value: String(format: "$%.2f/mo", scenario.calculation.monthlyPayment)
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scenarios")
            .toolbar {
                if !scenarios.isEmpty {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppTheme.Colors.light.primary)
                    }
                }
            }
        }
    }
}