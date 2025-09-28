import SwiftUI
import Charts

struct AIMarketTimingAnalyzer: View {
    @StateObject private var marketDataService = MarketDataService()
    @State private var selectedTimeframe: TimeFrame = .threeMonths
    @State private var marketPrediction: MarketPrediction?
    @State private var isAnalyzing = false
    
    enum TimeFrame: String, CaseIterable {
        case oneMonth = "1 Month"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
        
        var days: Int {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            }
        }
    }
    
    struct MarketPrediction {
        let buySignal: BuySignal
        let predictedPriceChange: Double
        let marketMomentum: Double // -1 to 1
        let bestTimeFrame: String
        let confidence: Double
        let risks: [String]
        let opportunities: [String]
        
        enum BuySignal {
            case strongBuy
            case buy
            case hold
            case wait
            
            var color: Color {
                switch self {
                case .strongBuy: return .green
                case .buy: return .mint
                case .hold: return .orange
                case .wait: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .strongBuy: return "arrow.up.circle.fill"
                case .buy: return "arrow.up.circle"
                case .hold: return "pause.circle"
                case .wait: return "clock.arrow.circlepath"
                }
            }
            
            var description: String {
                switch self {
                case .strongBuy: return "Strong Buy Signal"
                case .buy: return "Good Time to Buy"
                case .hold: return "Neutral Market"
                case .wait: return "Consider Waiting"
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Market Signal Card
                if let prediction = marketPrediction {
                    marketSignalCard(prediction)
                }
                
                // Time Frame Selector
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(TimeFrame.allCases, id: \.self) { frame in
                        Text(frame.rawValue).tag(frame)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTimeframe) { _ in
                    Task {
                        await analyzeMarket()
                    }
                }
                
                // Market Trends Chart
                marketTrendsChart
                
                // Market Indicators
                marketIndicatorsGrid
                
                if let prediction = marketPrediction {
                    // Risks and Opportunities
                    risksAndOpportunitiesCard(prediction)
                    
                    // AI Timing Recommendations
                    timingRecommendationsCard(prediction)
                }
                
                // Refresh Button
                Button(action: {
                    Task {
                        await refreshMarketData()
                    }
                }) {
                    Label("Refresh Market Data", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzing)
            }
            .padding()
        }
        .navigationTitle("Market Timing Analysis")
        .task {
            await analyzeMarket()
        }
        .overlay {
            if isAnalyzing {
                ProgressView("Analyzing market conditions...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private func marketSignalCard(_ prediction: MarketPrediction) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: prediction.buySignal.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(prediction.buySignal.color)
                
                VStack(alignment: .leading) {
                    Text(prediction.buySignal.description)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("AI Confidence: \(Int(prediction.confidence * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Market Momentum Gauge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Market Momentum")
                        .font(.subheadline)
                    Spacer()
                    Text(momentumDescription(prediction.marketMomentum))
                        .fontWeight(.medium)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background gradient
                        LinearGradient(
                            colors: [.red, .orange, .yellow, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 10)
                        .cornerRadius(5)
                        
                        // Momentum indicator
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(.black, lineWidth: 2))
                            .offset(x: (geometry.size.width - 20) * ((prediction.marketMomentum + 1) / 2))
                    }
                }
                .frame(height: 20)
            }
            
            // Predicted Price Change
            HStack {
                Text("Expected Price Change")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: prediction.predictedPriceChange >= 0 ? "arrow.up" : "arrow.down")
                    Text("\(abs(prediction.predictedPriceChange), format: .percent)")
                }
                .fontWeight(.bold)
                .foregroundStyle(prediction.predictedPriceChange >= 0 ? .green : .red)
            }
            
            Text("Best time to act: \(prediction.bestTimeFrame)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var marketTrendsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Trends")
                .font(.headline)
            
            if let marketData = marketDataService.currentMarketData {
                Chart {
                    // Home Value Index line
                    LineMark(
                        x: .value("Time", Date()),
                        y: .value("Index", marketData.marketTrends.homeValueIndex)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    // Add historical data if available
                    ForEach(marketDataService.historicalData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Time", marketDataService.historicalData[index].timestamp),
                            y: .value("Index", marketDataService.historicalData[index].marketTrends.homeValueIndex)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                
                // Trend indicators
                HStack(spacing: 20) {
                    trendIndicator(
                        title: "MoM Change",
                        value: marketData.marketTrends.monthOverMonthChange,
                        format: .percent
                    )
                    
                    trendIndicator(
                        title: "YoY Change",
                        value: marketData.marketTrends.yearOverYearChange,
                        format: .percent
                    )
                    
                    trendIndicator(
                        title: "Forecast",
                        value: marketData.marketTrends.forecastedChange,
                        format: .percent
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var marketIndicatorsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Indicators")
                .font(.headline)
            
            if let marketData = marketDataService.currentMarketData {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    indicatorCard(
                        title: "Median Price",
                        value: marketData.regionalData.medianHomePrice,
                        format: .currency(code: "USD"),
                        trend: .up
                    )
                    
                    indicatorCard(
                        title: "Days on Market",
                        value: Double(marketData.regionalData.averageDaysOnMarket),
                        format: .number,
                        trend: .down
                    )
                    
                    indicatorCard(
                        title: "Inventory",
                        value: marketData.regionalData.inventoryLevel,
                        format: .percent,
                        trend: marketData.regionalData.inventoryLevel > 0.5 ? .up : .down
                    )
                    
                    indicatorCard(
                        title: "Interest Rate",
                        value: marketData.averageMortgageRate,
                        format: .percent,
                        trend: .neutral
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func risksAndOpportunitiesCard(_ prediction: MarketPrediction) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Risks & Opportunities")
                .font(.headline)
            
            // Opportunities
            VStack(alignment: .leading, spacing: 8) {
                Label("Opportunities", systemImage: "sparkle")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                
                ForEach(prediction.opportunities, id: \.self) { opportunity in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .offset(y: 6)
                        Text(opportunity)
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Risks
            VStack(alignment: .leading, spacing: 8) {
                Label("Risks to Consider", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                
                ForEach(prediction.risks, id: \.self) { risk in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                            .offset(y: 6)
                        Text(risk)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func timingRecommendationsCard(_ prediction: MarketPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Timing Recommendations", systemImage: "calendar.badge.clock")
                .font(.headline)
            
            // Timeline visualization
            VStack(alignment: .leading, spacing: 16) {
                timelineItem(
                    period: "Now - 1 Month",
                    action: prediction.buySignal == .strongBuy ? "Act quickly" : "Monitor closely",
                    isOptimal: prediction.buySignal == .strongBuy
                )
                
                timelineItem(
                    period: "1-3 Months",
                    action: "Good window for negotiation",
                    isOptimal: prediction.buySignal == .buy
                )
                
                timelineItem(
                    period: "3-6 Months",
                    action: prediction.marketMomentum < 0 ? "Better opportunities may arise" : "Market may heat up",
                    isOptimal: false
                )
            }
            
            // Specific recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("• Lock in rates if favorable")
                Text("• Get pre-approved now to act fast")
                Text("• Set price alerts for target properties")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    // Helper Views
    private func trendIndicator(title: String, value: Double, format: FloatingPointFormatStyle<Double>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 2) {
                Image(systemName: value >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption)
                Text(abs(value), format: format)
            }
            .foregroundStyle(value >= 0 ? .green : .red)
            .fontWeight(.medium)
        }
    }
    
    private func indicatorCard(title: String, value: Double, format: FloatingPointFormatStyle<Double>, trend: TrendDirection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundStyle(trend.color)
            }
            
            Text(value, format: format)
                .font(.title3)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timelineItem(period: String, action: String, isOptimal: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .stroke(isOptimal ? Color.green : Color.gray, lineWidth: 2)
                .fill(isOptimal ? Color.green : Color.clear)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(period)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(action)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // Helper Functions
    private func analyzeMarket() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        await marketDataService.refreshMarketData()
        
        // Simulate AI market analysis
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        marketPrediction = MarketPrediction(
            buySignal: determineSignal(),
            predictedPriceChange: Double.random(in: -0.05...0.10),
            marketMomentum: Double.random(in: -1...1),
            bestTimeFrame: "Next 2-3 months",
            confidence: Double.random(in: 0.7...0.95),
            risks: [
                "Interest rates may rise further",
                "Limited inventory in desired areas",
                "Economic uncertainty ahead"
            ],
            opportunities: [
                "Sellers becoming more negotiable",
                "New construction entering market",
                "Seasonal buying advantage"
            ]
        )
    }
    
    private func refreshMarketData() async {
        await marketDataService.refreshMarketData()
        await analyzeMarket()
    }
    
    private func determineSignal() -> MarketPrediction.BuySignal {
        guard let marketData = marketDataService.currentMarketData else { return .hold }
        
        if marketData.marketTrends.marketHeatIndex > 0.8 {
            return .wait
        } else if marketData.marketTrends.marketHeatIndex > 0.6 {
            return .hold
        } else if marketData.marketTrends.marketHeatIndex > 0.4 {
            return .buy
        } else {
            return .strongBuy
        }
    }
    
    private func momentumDescription(_ momentum: Double) -> String {
        switch momentum {
        case 0.5...: return "Strong Buyer's Market"
        case 0.2..<0.5: return "Buyer's Market"
        case -0.2..<0.2: return "Balanced"
        case -0.5..<(-0.2): return "Seller's Market"
        default: return "Strong Seller's Market"
        }
    }
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .orange
            }
        }
    }
}