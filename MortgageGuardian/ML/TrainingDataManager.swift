import Foundation
import CoreML
import CreateML

// Training data structure for property value prediction
struct PropertyTrainingData: Codable {
    let salePrice: Double
    let propertyDetails: PropertyDetails
    let locationData: LocationData
    let marketConditions: MarketConditions
    let timestamp: Date
    
    struct PropertyDetails: Codable {
        let squareFootage: Double
        let bedrooms: Int
        let bathrooms: Double
        let lotSize: Double
        let yearBuilt: Int
        let propertyType: String
        let condition: Int // 1-5 scale
    }
    
    struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
        let zipCode: String
        let neighborhood: String
        let schoolRating: Double
        let crimeRate: Double
        let medianIncome: Double
    }
    
    struct MarketConditions: Codable {
        let medianHomePrice: Double
        let daysOnMarket: Int
        let inventoryLevel: Double
        let mortgageRate: Double
        let unemploymentRate: Double
        let gdpGrowth: Double
    }
}

class TrainingDataManager {
    private let fileManager = FileManager.default
    private let trainingDataURL: URL
    private let validationDataURL: URL
    
    init() throws {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mlDataPath = documentsPath.appendingPathComponent("MLData", isDirectory: true)
        
        // Create ML data directory if it doesn't exist
        try? fileManager.createDirectory(at: mlDataPath, withIntermediateDirectories: true)
        
        trainingDataURL = mlDataPath.appendingPathComponent("training_data.json")
        validationDataURL = mlDataPath.appendingPathComponent("validation_data.json")
    }
    
    func prepareTrainingData() async throws -> (MLDataTable, MLDataTable) {
        // Fetch real estate data
        let propertyData = try await fetchRealEstateData()
        
        // Split data into training and validation sets (80/20)
        let splitIndex = Int(Double(propertyData.count) * 0.8)
        let trainingData = Array(propertyData[..<splitIndex])
        let validationData = Array(propertyData[splitIndex...])
        
        // Save data for future use
        try saveData(trainingData, to: trainingDataURL)
        try saveData(validationData, to: validationDataURL)
        
        // Convert to MLDataTable format
        return (
            try createMLDataTable(from: trainingData),
            try createMLDataTable(from: validationData)
        )
    }
    
    private func fetchRealEstateData() async throws -> [PropertyTrainingData] {
        // TODO: Implement real API calls
        // For now, return sample data
        return try loadSampleData()
    }
    
    private func loadSampleData() throws -> [PropertyTrainingData] {
        // Load sample data from bundle
        guard let sampleDataURL = Bundle.main.url(forResource: "sample_property_data", withExtension: "json") else {
            return []
        }
        
        let data = try Data(contentsOf: sampleDataURL)
        return try JSONDecoder().decode([PropertyTrainingData].self, from: data)
    }
    
    private func saveData(_ data: [PropertyTrainingData], to url: URL) throws {
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: url)
    }
    
    private func createMLDataTable(from data: [PropertyTrainingData]) throws -> MLDataTable {
        // Convert PropertyTrainingData to format suitable for MLDataTable
        let rows: [[String: Any]] = data.map { property in
            [
                "salePrice": property.salePrice,
                "squareFootage": property.propertyDetails.squareFootage,
                "bedrooms": property.propertyDetails.bedrooms,
                "bathrooms": property.propertyDetails.bathrooms,
                "lotSize": property.propertyDetails.lotSize,
                "propertyAge": Date().timeIntervalSince1970 - Double(property.propertyDetails.yearBuilt),
                "latitude": property.locationData.latitude,
                "longitude": property.locationData.longitude,
                "schoolRating": property.locationData.schoolRating,
                "medianIncome": property.locationData.medianIncome,
                "marketMedianPrice": property.marketConditions.medianHomePrice,
                "daysOnMarket": property.marketConditions.daysOnMarket,
                "mortgageRate": property.marketConditions.mortgageRate,
                "unemploymentRate": property.marketConditions.unemploymentRate,
                "gdpGrowth": property.marketConditions.gdpGrowth
            ]
        }
        
        return try MLDataTable(dictionary: rows)
    }
}