import Foundation

class AISetupManager {
    static let shared = AISetupManager()
    private let secureKeyManager = SecureKeyManager.shared
    private var trainingDataManager: TrainingDataManager?
    
    private init() {}
    
    func performInitialSetup() async throws {
        print("Starting AI system initialization...")
        
        // 1. Set up API keys
        try await setupAPIKeys()
        
        // 2. Initialize training data
        try await setupTrainingData()
        
        // 3. Train initial models
        try await trainInitialModels()
        
        print("AI system initialization complete!")
    }
    
    private func setupAPIKeys() async throws {
        // In a production app, these would be fetched securely from your backend
        let apiKeys = [
            APIService.realEstate: "your_real_estate_api_key",
            APIService.marketData: "your_market_data_api_key",
            APIService.federalReserve: "your_federal_reserve_api_key"
        ]
        
        for (service, key) in apiKeys {
            try secureKeyManager.saveAPIKey(key, forService: service.rawValue)
        }
    }
    
    private func setupTrainingData() async throws {
        trainingDataManager = try TrainingDataManager()
        let (trainingData, validationData) = try await trainingDataManager?.prepareTrainingData() ?? (MLDataTable(), MLDataTable())
        
        print("Training data prepared:")
        print("- Training samples: \(trainingData.rows.count)")
        print("- Validation samples: \(validationData.rows.count)")
    }
    
    private func trainInitialModels() async throws {
        let trainer = MLModelTrainer(
            trainingDataPath: trainingDataManager?.trainingDataURL.path ?? "",
            validationDataPath: trainingDataManager?.validationDataURL.path ?? "",
            modelOutputPath: Bundle.main.bundlePath + "/PropertyValuePredictor.mlmodel"
        )
        
        print("Training property value model...")
        try await trainer.trainPropertyValueModel()
        
        print("Training risk assessment model...")
        try await trainer.trainRiskAssessmentModel()
        
        print("Training recommendation model...")
        try await trainer.trainRecommendationModel()
    }
}

// Extension to add this to your app's startup routine
extension MortgageGuardianApp {
    func setupAI() async {
        do {
            try await AISetupManager.shared.performInitialSetup()
        } catch {
            print("Error setting up AI system: \(error)")
        }
    }
}