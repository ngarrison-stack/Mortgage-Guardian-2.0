import Foundation
import SwiftUI

@MainActor
@Observable
class MarketDataService: ObservableObject {
    private let secureKeyManager = SecureKeyManager.shared

    enum MarketDataError: LocalizedError {
        case apiKeyNotConfigured
        case networkError(Error)
        case invalidResponse
        case rateLimitExceeded

        var errorDescription: String? {
            switch self {
            case .apiKeyNotConfigured:
                return "Market data API key not configured. Please set up your API keys in Settings."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from market data API"
            case .rateLimitExceeded:
                return "API rate limit exceeded. Please try again later."
            }
        }
    }
    
    struct MarketData: Codable {
        let timestamp: Date
        let federalRate: Double
        let averageMortgageRate: Double
        let marketTrends: MarketTrends
        let regionalData: RegionalData
        
        struct MarketTrends: Codable {
            let homeValueIndex: Double
            let monthOverMonthChange: Double
            let yearOverYearChange: Double
            let forecastedChange: Double
            let marketHeatIndex: Double // 0-1, indicates market activity
        }
        
        struct RegionalData: Codable {
            let medianHomePrice: Double
            let averageDaysOnMarket: Int
            let inventoryLevel: Double
            let newListings: Int
            let priceReductions: Double // percentage of listings with price reductions
        }
    }
    
    @Published private(set) var currentMarketData: MarketData?
    @Published private(set) var historicalData: [MarketData] = []
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var isLoading = false
    
    private var updateTimer: Timer?
    private let cache = NSCache<NSString, NSData>()
    
    init() {
        setupUpdateTimer()
    }
    
    private func setupUpdateTimer() {
        // Update market data every 4 hours
        updateTimer = Timer.scheduledTimer(withTimeInterval: 4 * 60 * 60, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshMarketData()
            }
        }
    }
    
    func refreshMarketData() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Check if API keys are configured
            guard secureKeyManager.hasMarketDataKey else {
                throw MarketDataError.apiKeyNotConfigured
            }

            async let federalRateTask = fetchFederalRate()
            async let mortgageRateTask = fetchMortgageRates()
            async let marketTrendsTask = fetchMarketTrends()
            async let regionalDataTask = fetchRegionalData()

            let (federalRate, mortgageRate, marketTrends, regionalData) = await (
                try federalRateTask,
                try mortgageRateTask,
                try marketTrendsTask,
                try regionalDataTask
            )

            let newMarketData = MarketData(
                timestamp: Date(),
                federalRate: federalRate,
                averageMortgageRate: mortgageRate,
                marketTrends: marketTrends,
                regionalData: regionalData
            )

            currentMarketData = newMarketData
            historicalData.append(newMarketData)
            lastUpdateTime = Date()

            // Limit historical data to last 30 days
            if historicalData.count > 30 {
                historicalData.removeFirst(historicalData.count - 30)
            }

        } catch {
            print("Error refreshing market data: \(error)")
        }
    }
    
    // MARK: - Private API Methods

    private func getAPIKey(for service: APIService) throws -> String {
        do {
            return try secureKeyManager.getAPIKey(forService: service)
        } catch {
            throw MarketDataError.apiKeyNotConfigured
        }
    }

    private func fetchFederalRate() async throws -> Double {
        // Use Federal Reserve API if available, otherwise fallback to mock data
        if secureKeyManager.hasMarketDataKey {
            do {
                let apiKey = try getAPIKey(for: .federalReserve)
                return try await fetchFederalRateFromAPI(apiKey: apiKey)
            } catch {
                // Fallback to mock data if API fails
                return 0.0525
            }
        } else {
            return 0.0525 // Mock data
        }
    }

    private func fetchMortgageRates() async throws -> Double {
        if secureKeyManager.hasMarketDataKey {
            do {
                let apiKey = try getAPIKey(for: .marketData)
                return try await fetchMortgageRatesFromAPI(apiKey: apiKey)
            } catch {
                return 0.0675 // Fallback
            }
        } else {
            return 0.0675 // Mock data
        }
    }

    private func fetchMarketTrends() async throws -> MarketData.MarketTrends {
        if secureKeyManager.hasMarketDataKey {
            do {
                let apiKey = try getAPIKey(for: .realEstate)
                return try await fetchMarketTrendsFromAPI(apiKey: apiKey)
            } catch {
                // Fallback to mock data
                return createMockMarketTrends()
            }
        } else {
            return createMockMarketTrends()
        }
    }

    private func fetchRegionalData() async throws -> MarketData.RegionalData {
        if secureKeyManager.hasMarketDataKey {
            do {
                let apiKey = try getAPIKey(for: .realEstate)
                return try await fetchRegionalDataFromAPI(apiKey: apiKey)
            } catch {
                return createMockRegionalData()
            }
        } else {
            return createMockRegionalData()
        }
    }

    // MARK: - Actual API Calls

    private func fetchFederalRateFromAPI(apiKey: String) async throws -> Double {
        guard let url = URL(string: "\(APIService.baseURLs[.federalReserve]!)/rates/federal") else {
            throw MarketDataError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError(URLError(.badServerResponse))
        }

        // Parse federal rate response
        // This would depend on the actual API response format
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let rate = responseDict?["rate"] as? Double else {
            throw MarketDataError.invalidResponse
        }

        return rate
    }

    private func fetchMortgageRatesFromAPI(apiKey: String) async throws -> Double {
        // Simulate API call with delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // For now, return mock data until real API is integrated
        return 0.0675
    }

    private func fetchMarketTrendsFromAPI(apiKey: String) async throws -> MarketData.MarketTrends {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return createMockMarketTrends()
    }

    private func fetchRegionalDataFromAPI(apiKey: String) async throws -> MarketData.RegionalData {
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return createMockRegionalData()
    }

    // MARK: - Mock Data Helpers

    private func createMockMarketTrends() -> MarketData.MarketTrends {
        return MarketData.MarketTrends(
            homeValueIndex: 200.0 + Double.random(in: -5...5),
            monthOverMonthChange: Double.random(in: -0.01...0.015),
            yearOverYearChange: Double.random(in: 0.02...0.06),
            forecastedChange: Double.random(in: 0.015...0.045),
            marketHeatIndex: Double.random(in: 0.6...0.9)
        )
    }

    private func createMockRegionalData() -> MarketData.RegionalData {
        return MarketData.RegionalData(
            medianHomePrice: Double.random(in: 400000...500000),
            averageDaysOnMarket: Int.random(in: 20...35),
            inventoryLevel: Double.random(in: 0.7...1.2),
            newListings: Int.random(in: 100...200),
            priceReductions: Double.random(in: 0.1...0.25)
        )
    }
}