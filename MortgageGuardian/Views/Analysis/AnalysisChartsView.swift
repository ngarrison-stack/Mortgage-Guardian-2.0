import SwiftUI
import Charts

/// Comprehensive data visualization view for mortgage analysis results
struct AnalysisChartsView: View {
    let viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedChart: ChartType = .severityDistribution
    @State private var selectedTimeframe: TimeFrame = .lastSixMonths
    @State private var showingExportOptions = false
    @State private var animateCharts = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with metrics summary
                    metricsHeaderSection

                    // Chart selection
                    chartSelectionSection

                    // Main chart content
                    if horizontalSizeClass == .regular {
                        // iPad: Grid layout for multiple charts
                        chartGridLayout
                    } else {
                        // iPhone: Single chart view
                        singleChartView
                    }

                    // Additional insights
                    insightsSection
                }
                .padding()
            }
            .navigationTitle("Analysis Charts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingExportOptions) {
                ChartExportView(viewModel: viewModel)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                    animateCharts = true
                }
            }
        }
    }

    // MARK: - Metrics Header
    @ViewBuilder
    private var metricsHeaderSection: some View {
        VStack(spacing: 16) {
            Text("Analysis Overview")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 20) {
                MetricCard(
                    title: "Total Issues",
                    value: "\(viewModel.analysisMetrics.totalIssues)",
                    subtitle: "\(viewModel.analysisMetrics.issuesThisMonth) this month",
                    color: .blue,
                    trend: .stable
                )

                MetricCard(
                    title: "Potential Savings",
                    value: formatCurrency(viewModel.analysisMetrics.totalPotentialSavings),
                    subtitle: "From identified errors",
                    color: .green,
                    trend: .positive
                )

                MetricCard(
                    title: "Avg Confidence",
                    value: "\(Int(viewModel.analysisMetrics.averageConfidence * 100))%",
                    subtitle: "Detection accuracy",
                    color: .orange,
                    trend: .positive
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Chart Selection
    @ViewBuilder
    private var chartSelectionSection: some View {
        VStack(spacing: 12) {
            // Chart Type Selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChartType.allCases, id: \.self) { chartType in
                        ChartTypeButton(
                            type: chartType,
                            isSelected: selectedChart == chartType
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedChart = chartType
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Timeframe Selection (for time-based charts)
            if selectedChart.isTimeBased {
                timeframeSelectionView
            }
        }
    }

    // MARK: - Timeframe Selection
    @ViewBuilder
    private var timeframeSelectionView: some View {
        HStack {
            Text("Timeframe:")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 300)
        }
        .padding(.horizontal)
    }

    // MARK: - Chart Grid Layout (iPad)
    @ViewBuilder
    private var chartGridLayout: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(ChartType.allCases, id: \.self) { chartType in
                chartCardView(for: chartType)
                    .frame(height: 300)
            }
        }
    }

    // MARK: - Single Chart View (iPhone)
    @ViewBuilder
    private var singleChartView: some View {
        chartCardView(for: selectedChart)
            .frame(height: 400)
    }

    // MARK: - Chart Card View
    @ViewBuilder
    private func chartCardView(for chartType: ChartType) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chartType.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(chartType.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: chartType.icon)
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            // Chart Content
            switch chartType {
            case .severityDistribution:
                severityDistributionChart
            case .issueTypesBreakdown:
                issueTypesChart
            case .monthlyTrends:
                monthlyTrendsChart
            case .financialImpact:
                financialImpactChart
            case .confidenceAnalysis:
                confidenceAnalysisChart
            case .detectionMethods:
                detectionMethodsChart
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Individual Charts

    @ViewBuilder
    private var severityDistributionChart: some View {
        Chart(viewModel.chartData.severityDistribution, id: \.name) { dataPoint in
            SectorMark(
                angle: .value("Count", animateCharts ? dataPoint.value : 0),
                innerRadius: .ratio(0.4),
                angularInset: 2
            )
            .foregroundStyle(dataPoint.color)
            .opacity(animateCharts ? 1.0 : 0.3)
        }
        .chartLegend(position: .bottom, alignment: .center)
        .animation(.easeInOut(duration: 1.0), value: animateCharts)
    }

    @ViewBuilder
    private var issueTypesChart: some View {
        Chart(viewModel.chartData.issueTypeDistribution.prefix(5), id: \.name) { dataPoint in
            BarMark(
                x: .value("Count", animateCharts ? dataPoint.value : 0)
            )
            .foregroundStyle(.blue.gradient)
            .opacity(animateCharts ? 1.0 : 0.3)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .animation(.easeInOut(duration: 1.0).delay(0.2), value: animateCharts)
    }

    @ViewBuilder
    private var monthlyTrendsChart: some View {
        let filteredData = filterDataByTimeframe(viewModel.chartData.monthlyTrend)

        Chart(filteredData, id: \.date) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Count", animateCharts ? dataPoint.count : 0)
            )
            .foregroundStyle(.blue.gradient)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", dataPoint.date),
                y: .value("Count", animateCharts ? dataPoint.count : 0)
            )
            .foregroundStyle(.blue.gradient.opacity(0.3))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .animation(.easeInOut(duration: 1.0).delay(0.4), value: animateCharts)
    }

    @ViewBuilder
    private var financialImpactChart: some View {
        let filteredData = filterFinancialDataByTimeframe(viewModel.chartData.financialImpact)

        Chart(filteredData, id: \.date) { dataPoint in
            BarMark(
                x: .value("Date", dataPoint.date),
                y: .value("Amount", animateCharts ? dataPoint.amount : 0)
            )
            .foregroundStyle(dataPoint.severity.color.gradient)
            .opacity(animateCharts ? 1.0 : 0.3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel(format: .currency(code: "USD"))
            }
        }
        .animation(.easeInOut(duration: 1.0).delay(0.6), value: animateCharts)
    }

    @ViewBuilder
    private var confidenceAnalysisChart: some View {
        let confidenceBuckets = calculateConfidenceBuckets()

        Chart(confidenceBuckets, id: \.range) { bucket in
            BarMark(
                x: .value("Range", bucket.range),
                y: .value("Count", animateCharts ? bucket.count : 0)
            )
            .foregroundStyle(bucket.color.gradient)
            .opacity(animateCharts ? 1.0 : 0.3)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .animation(.easeInOut(duration: 1.0).delay(0.8), value: animateCharts)
    }

    @ViewBuilder
    private var detectionMethodsChart: some View {
        let methodData = viewModel.analysisMetrics.detectionMethodDistribution.map { method, count in
            ChartDataPoint(name: method.displayName, value: Double(count), color: methodColor(for: method))
        }

        Chart(methodData, id: \.name) { dataPoint in
            SectorMark(
                angle: .value("Count", animateCharts ? dataPoint.value : 0),
                innerRadius: .ratio(0.3)
            )
            .foregroundStyle(dataPoint.color)
            .opacity(animateCharts ? 1.0 : 0.3)
        }
        .chartLegend(position: .bottom, alignment: .center)
        .animation(.easeInOut(duration: 1.0).delay(1.0), value: animateCharts)
    }

    // MARK: - Insights Section
    @ViewBuilder
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InsightCard(
                    title: "Most Common Issue",
                    value: mostCommonIssueType,
                    icon: "exclamationmark.triangle",
                    color: .orange
                )

                InsightCard(
                    title: "Highest Impact",
                    value: formatCurrency(highestSingleImpact),
                    icon: "dollarsign.circle",
                    color: .green
                )

                InsightCard(
                    title: "Detection Success",
                    value: "\(Int(viewModel.analysisMetrics.averageConfidence * 100))%",
                    icon: "checkmark.shield",
                    color: .blue
                )

                InsightCard(
                    title: "Critical Issues",
                    value: "\(viewModel.analysisMetrics.criticalIssues)",
                    icon: "exclamationmark.circle",
                    color: .red
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingExportOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Helper Functions
    private func filterDataByTimeframe(_ data: [AnalysisViewModel.TrendDataPoint]) -> [AnalysisViewModel.TrendDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch selectedTimeframe {
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastThreeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .lastSixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .lastYear:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return data
        }

        return data.filter { $0.date >= startDate }
    }

    private func filterFinancialDataByTimeframe(_ data: [AnalysisViewModel.FinancialDataPoint]) -> [AnalysisViewModel.FinancialDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch selectedTimeframe {
        case .lastMonth:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastThreeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .lastSixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .lastYear:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return data
        }

        return data.filter { $0.date >= startDate }
    }

    private func calculateConfidenceBuckets() -> [ConfidenceBucket] {
        let results = viewModel.auditResults
        let buckets = [
            ("90-100%", 0.9...1.0, Color.green),
            ("80-89%", 0.8...0.9, Color.blue),
            ("70-79%", 0.7...0.8, Color.orange),
            ("Below 70%", 0.0...0.7, Color.red)
        ]

        return buckets.map { range, confidenceRange, color in
            let count = results.filter { confidenceRange.contains($0.confidence) }.count
            return ConfidenceBucket(range: range, count: count, color: color)
        }
    }

    private func methodColor(for method: AuditResult.DetectionMethod) -> Color {
        switch method {
        case .aiAnalysis: return .purple
        case .manualCalculation: return .blue
        case .plaidVerification: return .green
        case .combinedAnalysis: return .orange
        }
    }

    private var mostCommonIssueType: String {
        let distribution = viewModel.analysisMetrics.issueTypeDistribution
        let mostCommon = distribution.max(by: { $0.value < $1.value })
        return mostCommon?.key.displayName ?? "None"
    }

    private var highestSingleImpact: Double {
        viewModel.auditResults.compactMap { $0.affectedAmount }.max() ?? 0
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types

enum ChartType: String, CaseIterable {
    case severityDistribution = "Severity Distribution"
    case issueTypesBreakdown = "Issue Types"
    case monthlyTrends = "Monthly Trends"
    case financialImpact = "Financial Impact"
    case confidenceAnalysis = "Confidence Analysis"
    case detectionMethods = "Detection Methods"

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .severityDistribution: return "Issues by severity level"
        case .issueTypesBreakdown: return "Most common issue types"
        case .monthlyTrends: return "Issues detected over time"
        case .financialImpact: return "Financial impact over time"
        case .confidenceAnalysis: return "Detection confidence levels"
        case .detectionMethods: return "Methods used for detection"
        }
    }

    var icon: String {
        switch self {
        case .severityDistribution: return "chart.pie"
        case .issueTypesBreakdown: return "chart.bar"
        case .monthlyTrends: return "chart.line.uptrend.xyaxis"
        case .financialImpact: return "dollarsign.chart"
        case .confidenceAnalysis: return "gauge.medium"
        case .detectionMethods: return "gearshape.2"
        }
    }

    var isTimeBased: Bool {
        switch self {
        case .monthlyTrends, .financialImpact: return true
        default: return false
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case lastMonth = "1M"
    case lastThreeMonths = "3M"
    case lastSixMonths = "6M"
    case lastYear = "1Y"
    case allTime = "All"

    var displayName: String { rawValue }
}

struct ConfidenceBucket {
    let range: String
    let count: Int
    let color: Color
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let trend: TrendDirection

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(trend.color)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct ChartTypeButton: View {
    let type: ChartType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.caption)

                Text(type.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

enum TrendDirection {
    case positive, negative, stable

    var icon: String {
        switch self {
        case .positive: return "arrow.up"
        case .negative: return "arrow.down"
        case .stable: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .negative: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Chart Export View
struct ChartExportView: View {
    let viewModel: AnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Charts")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Choose export format and options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    ExportOptionButton(
                        title: "Export as PDF",
                        subtitle: "High-quality charts in PDF format",
                        icon: "doc.fill",
                        action: { exportAsPDF() }
                    )

                    ExportOptionButton(
                        title: "Export as Images",
                        subtitle: "Individual chart images",
                        icon: "photo.fill",
                        action: { exportAsImages() }
                    )

                    ExportOptionButton(
                        title: "Export Data",
                        subtitle: "Raw data in CSV format",
                        icon: "tablecells.fill",
                        action: { exportData() }
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportAsPDF() {
        // TODO: Implement PDF export
        print("Exporting as PDF")
        dismiss()
    }

    private func exportAsImages() {
        // TODO: Implement image export
        print("Exporting as images")
        dismiss()
    }

    private func exportData() {
        // TODO: Implement data export
        print("Exporting data")
        dismiss()
    }
}

struct ExportOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AnalysisChartsView(viewModel: AnalysisViewModel(userStore: UserStore()))
}