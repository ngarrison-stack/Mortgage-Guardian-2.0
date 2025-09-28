import SwiftUI
import Charts

struct AIMonitoringDashboard: View {
    @ObservedObject private var aiCoordinator: MortgageAICoordinator
    @State private var selectedMetric: MetricType = .modelAccuracy
    @State private var timeRange: TimeRange = .week
    @State private var isRefreshing = false
    
    enum MetricType: String, CaseIterable {
        case modelAccuracy = "Model Accuracy"
        case predictionConfidence = "Prediction Confidence"
        case marketDataFreshness = "Market Data Freshness"
        case processingTime = "Processing Time"
    }
    
    enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"
    }
    
    init(aiCoordinator: MortgageAICoordinator) {
        self.aiCoordinator = aiCoordinator
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Model Status Card
                    modelStatusCard
                    
                    // Metrics Selection
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(MetricType.allCases, id: \.self) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Time Range Selection
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Metrics Chart
                    metricsChart
                    
                    // Recent Activities
                    recentActivitiesCard
                    
                    // System Health
                    systemHealthCard
                }
                .padding()
            }
            .navigationTitle("AI Monitor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await refreshData()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
        }
    }
    
    private var modelStatusCard: some View {
        VStack(spacing: 12) {
            Label("Model Status", systemImage: "brain")
                .font(.headline)
            
            HStack(spacing: 20) {
                statusItem(
                    title: "Property Value",
                    value: "\(Int(aiCoordinator.modelAccuracy ?? 0 * 100))%",
                    trend: .up
                )
                
                statusItem(
                    title: "Risk Assessment",
                    value: "\(Int(aiCoordinator.modelAccuracy ?? 0 * 100))%",
                    trend: .neutral
                )
                
                statusItem(
                    title: "Recommendations",
                    value: "\(Int(aiCoordinator.modelAccuracy ?? 0 * 100))%",
                    trend: .up
                )
            }
            
            if let lastUpdate = aiCoordinator.lastModelUpdate {
                Text("Last updated: \(lastUpdate.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var metricsChart: some View {
        Chart {
            // Simulated data - replace with real metrics from aiCoordinator
            ForEach(0..<10, id: \.self) { index in
                LineMark(
                    x: .value("Time", Date().addingTimeInterval(Double(index) * 3600)),
                    y: .value("Value", Double.random(in: 0.7...0.95))
                )
            }
        }
        .frame(height: 200)
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var recentActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Activities", systemImage: "clock")
                .font(.headline)
            
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Model training completed")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("2h ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Health", systemImage: "gauge")
                .font(.headline)
            
            HStack(spacing: 20) {
                healthItem(
                    title: "API Status",
                    status: .good
                )
                
                healthItem(
                    title: "Data Pipeline",
                    status: .good
                )
                
                healthItem(
                    title: "Model Training",
                    status: .warning
                )
            }
        }
        .padding()
        .background(AppTheme.Colors.light.surface)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
    
    private func statusItem(title: String, value: String, trend: TrendDirection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Image(systemName: trend.icon)
                    .foregroundStyle(trend.color)
                    .font(.caption)
            }
        }
    }
    
    private func healthItem(title: String, status: HealthStatus) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.circle.fill"
            case .down: return "arrow.down.circle.fill"
            case .neutral: return "equal.circle.fill"
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
    
    enum HealthStatus {
        case good, warning, error
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Refresh metrics from aiCoordinator
        await aiCoordinator.updateModelsIfNeeded()
    }
}