import SwiftUI
import Charts

struct AIScenarioComparison: View {
    let scenarios: [SavedMortgageScenario]
    @State private var selectedScenarios: Set<SavedMortgageScenario> = []
    @State private var comparisonResults: ComparisonResults?
    @State private var isAnalyzing = false
    @State private var comparisonType: ComparisonType = .totalCost
    
    enum ComparisonType: String, CaseIterable {
        case totalCost = "Total Cost"
        case monthlyPayment = "Monthly Payment"
        case equity = "Equity Build-up"
        case risk = "Risk Analysis"
        
        var icon: String {
            switch self {
            case .totalCost: return "dollarsign.circle"
            case .monthlyPayment: return "calendar"
            case .equity: return "chart.line.uptrend.xyaxis"
            case .risk: return "shield"
            }
        }
    }
    
    struct ComparisonResults {
        let bestOverall: SavedMortgageScenario
        let lowestPayment: SavedMortgageScenario
        let lowestRisk: SavedMortgageScenario
        let bestEquity: SavedMortgageScenario
        let insights: [String]
        let tradeoffs: [TradeOff]
        
        struct TradeOff {
            let scenario1: SavedMortgageScenario
            let scenario2: SavedMortgageScenario
            let description: String
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Scenario Selector
                scenarioSelector
                
                if selectedScenarios.count >= 2 {
                    // Comparison Type Selector
                    Picker("Comparison Type", selection: $comparisonType) {
                        ForEach(ComparisonType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Analysis Button
                    Button(action: {
                        Task {
                            await analyzeScenarios()
                        }
                    }) {
                        Label("Compare Scenarios", systemImage: "chart.bar.xaxis")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing)
                    
                    if let results = comparisonResults {
                        // Winner Card
                        winnerCard(results)
                        
                        // Comparison Chart
                        comparisonChart
                        
                        // Detailed Breakdown
                        detailedBreakdown
                        
                        // Trade-offs Analysis
                        tradeoffsCard(results)
                        
                        // AI Insights
                        insightsCard(results)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AI Scenario Comparison")
        .overlay {
            if isAnalyzing {
                ProgressView("Analyzing scenarios...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private var scenarioSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Scenarios to Compare")
                .font(.headline)
            
            Text("Choose at least 2 scenarios")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(scenarios) { scenario in
                    HStack {
                        Image(systemName: selectedScenarios.contains(scenario) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedScenarios.contains(scenario) ? .blue : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(scenario.name)
                                .fontWeight(.medium)
                            Text("\(scenario.monthlyPayment, format: .currency(code: "USD"))/month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(selectedScenarios.contains(scenario) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        if selectedScenarios.contains(scenario) {
                            selectedScenarios.remove(scenario)
                        } else if selectedScenarios.count < 4 {
                            selectedScenarios.insert(scenario)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func winnerCard(_ results: ComparisonResults) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading) {
                    Text("Best Overall Scenario")
                        .font(.headline)
                    Text(results.bestOverall.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
            
            // Category Winners
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                categoryWinner(
                    title: "Lowest Payment",
                    scenario: results.lowestPayment,
                    value: results.lowestPayment.monthlyPayment,
                    format: .currency(code: "USD")
                )
                
                categoryWinner(
                    title: "Lowest Risk",
                    scenario: results.lowestRisk,
                    value: results.lowestRisk.riskAssessment?.riskScore ?? 0,
                    format: .number
                )
                
                categoryWinner(
                    title: "Best Equity",
                    scenario: results.bestEquity,
                    value: calculateEquityAt5Years(results.bestEquity),
                    format: .currency(code: "USD")
                )
                
                categoryWinner(
                    title: "Total Cost",
                    scenario: results.bestOverall,
                    value: calculateTotalCost(results.bestOverall),
                    format: .currency(code: "USD")
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual Comparison")
                .font(.headline)
            
            Chart {
                switch comparisonType {
                case .totalCost:
                    ForEach(Array(selectedScenarios)) { scenario in
                        BarMark(
                            x: .value("Scenario", scenario.name),
                            y: .value("Cost", calculateTotalCost(scenario))
                        )
                        .foregroundStyle(by: .value("Type", "Total Cost"))
                    }
                    
                case .monthlyPayment:
                    ForEach(Array(selectedScenarios)) { scenario in
                        BarMark(
                            x: .value("Scenario", scenario.name),
                            y: .value("Payment", scenario.monthlyPayment)
                        )
                        .foregroundStyle(by: .value("Type", "Monthly"))
                    }
                    
                case .equity:
                    ForEach(0..<10, id: \.self) { year in
                        ForEach(Array(selectedScenarios)) { scenario in
                            LineMark(
                                x: .value("Year", year),
                                y: .value("Equity", calculateEquityAtYear(scenario, year: year))
                            )
                            .foregroundStyle(by: .value("Scenario", scenario.name))
                        }
                    }
                    
                case .risk:
                    ForEach(Array(selectedScenarios)) { scenario in
                        RadialMark(
                            angle: .value("Risk", scenario.riskAssessment?.riskScore ?? 50),
                            innerRadius: .ratio(0.5)
                        )
                        .foregroundStyle(by: .value("Scenario", scenario.name))
                    }
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var detailedBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Breakdown")
                .font(.headline)
            
            // Comparison table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Metric")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(Array(selectedScenarios).prefix(3)) { scenario in
                        Text(scenario.name)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                
                Divider()
                
                // Rows
                metricRow("Monthly Payment") { scenario in
                    Text(scenario.monthlyPayment, format: .currency(code: "USD"))
                }
                
                metricRow("Total Interest") { scenario in
                    Text(scenario.totalInterest, format: .currency(code: "USD"))
                }
                
                metricRow("Down Payment") { scenario in
                    Text(scenario.downPayment, format: .currency(code: "USD"))
                }
                
                metricRow("5-Year Equity") { scenario in
                    Text(calculateEquityAt5Years(scenario), format: .currency(code: "USD"))
                }
                
                metricRow("Risk Score") { scenario in
                    if let risk = scenario.riskAssessment {
                        Text("\(Int(risk.riskScore))/100")
                    } else {
                        Text("N/A")
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func tradeoffsCard(_ results: ComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trade-offs Analysis", systemImage: "scalemass")
                .font(.headline)
            
            ForEach(results.tradeoffs, id: \.description) { tradeoff in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tradeoff.scenario1.name)
                            .fontWeight(.medium)
                        Text("vs")
                            .foregroundStyle(.secondary)
                        Text(tradeoff.scenario2.name)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    Text(tradeoff.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func insightsCard(_ results: ComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Insights", systemImage: "lightbulb.fill")
                .font(.headline)
            
            ForEach(results.insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    
                    Text(insight)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    // Helper Views
    private func categoryWinner(title: String, scenario: SavedMortgageScenario, value: Double, format: FloatingPointFormatStyle<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(scenario.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(value, format: format)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func metricRow(_ metric: String, @ViewBuilder content: @escaping (SavedMortgageScenario) -> some View) -> some View {
        HStack {
            Text(metric)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(Array(selectedScenarios).prefix(3)) { scenario in
                content(scenario)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
    }
    
    // Helper Functions
    private func analyzeScenarios() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Simulate AI analysis
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        let scenariosArray = Array(selectedScenarios)
        
        comparisonResults = ComparisonResults(
            bestOverall: scenariosArray.min(by: { calculateTotalCost($0) < calculateTotalCost($1) }) ?? scenariosArray[0],
            lowestPayment: scenariosArray.min(by: { $0.monthlyPayment < $1.monthlyPayment }) ?? scenariosArray[0],
            lowestRisk: scenariosArray.min(by: { ($0.riskAssessment?.riskScore ?? 100) < ($1.riskAssessment?.riskScore ?? 100) }) ?? scenariosArray[0],
            bestEquity: scenariosArray.max(by: { calculateEquityAt5Years($0) < calculateEquityAt5Years($1) }) ?? scenariosArray[0],
            insights: generateInsights(),
            tradeoffs: generateTradeoffs(scenariosArray)
        )
    }
    
    private func calculateTotalCost(_ scenario: SavedMortgageScenario) -> Double {
        scenario.monthlyPayment * Double(scenario.loanTermYears * 12) + scenario.downPayment
    }
    
    private func calculateEquityAt5Years(_ scenario: SavedMortgageScenario) -> Double {
        let principal = scenario.principalAmount - scenario.downPayment
        let paid = scenario.monthlyPayment * 60 - (scenario.totalInterest * 5 / Double(scenario.loanTermYears))
        return scenario.downPayment + paid
    }
    
    private func calculateEquityAtYear(_ scenario: SavedMortgageScenario, year: Int) -> Double {
        let principal = scenario.principalAmount - scenario.downPayment
        let paid = scenario.monthlyPayment * Double(year * 12) - (scenario.totalInterest * Double(year) / Double(scenario.loanTermYears))
        return scenario.downPayment + max(0, paid)
    }
    
    private func generateInsights() -> [String] {
        [
            "Shorter loan terms save significantly on interest",
            "Higher down payments reduce overall cost and monthly payments",
            "Consider the trade-off between monthly affordability and total cost",
            "Factor in opportunity cost of larger down payments"
        ]
    }
    
    private func generateTradeoffs(_ scenarios: [SavedMortgageScenario]) -> [ComparisonResults.TradeOff] {
        guard scenarios.count >= 2 else { return [] }
        
        return [
            ComparisonResults.TradeOff(
                scenario1: scenarios[0],
                scenario2: scenarios[1],
                description: "Lower monthly payment but higher total interest over life of loan"
            )
        ]
    }
}