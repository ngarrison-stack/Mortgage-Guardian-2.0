# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mortgage Guardian 2.0 is an iOS application for detecting errors in mortgage loan servicing through AI-powered document analysis and automated audit algorithms. It combines Claude AI analysis with manual verification to identify discrepancies and generate RESPA-compliant dispute letters.

## Architecture

### iOS App
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with SwiftData for persistence
- **Minimum iOS**: 17.0
- **Project**: `MortgageGuardian.xcodeproj`
- **Entry Point**: `MortgageGuardian/MortgageGuardianApp.swift` (injects DataManager)
- **Data Flow**: SwiftUI views ↔ DataManager (SwiftData ModelContainer & ModelContext) ↔ @Model types in `Models/`

### Core Services (Services/ directory)
- **AI System**: AIManager, MortgageAICoordinator, MLPredictor, AISetupManager
- **Document Processing**: DocumentAnalysisService, DocumentProcessor, AWSTextractService, GoogleCloudOCRService
- **Financial Integration**: PlaidService, SimplePlaidService, PlaidLinkService, AuditEngine
- **Security**: SecurityService, SecureKeyManager, PermissionsManager
- **Document Generation**: LetterGenerationService, PDFGenerator
- **Market Data**: MarketDataService

### Backend (AWS SAM)
- **Template**: `mortgage-guardian-backend/template.yaml`
- **Runtime**: Node.js 20.x (upgraded from 18.x)
- **Functions**: `src/claude-analysis/`, `src/plaid/`
- **API Gateway**: `/v1/ai/claude/analyze`, `/v1/plaid/{proxy+}`
- **Authentication**: Cognito User Pool with MFA support

## Build Commands

### iOS Build & Test
```bash
# Quick build test (uses iPhone 17 Pro simulator)
./test-build.sh

# CI-compatible build (mirrors GitHub Actions)
xcodebuild clean build -project MortgageGuardian.xcodeproj \
  -scheme MortgageGuardian -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=17.0" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run all tests (CI-compatible)
xcodebuild test -project MortgageGuardian.xcodeproj \
  -scheme MortgageGuardian -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=17.0" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Unit tests only
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:MortgageGuardianTests/UnitTests

# Integration tests
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
  -only-testing:MortgageGuardianTests/IntegrationTests
```

### Fastlane Release Automation
```bash
# TestFlight beta deployment (requires APPLE_KEY_* env vars)
bundle exec fastlane ios beta

# Setup code signing (requires MATCH_GIT_URL env var)
bundle exec fastlane ios setup_signing
```

### Backend Deployment
```bash
cd mortgage-guardian-backend
sam build
sam deploy --guided

# Install dependencies
cd src/plaid && npm install
cd ../claude-analysis && npm install
```

### Developer Setup
```bash
# Interactive setup with bundle ID configuration
./scripts/setup-developer.sh

# Quick setup with defaults
./scripts/quick-setup.sh
```

### Machine Learning Training
```bash
# Training pipeline requires macOS CreateML environment
# Compile and run script that instantiates MLModelTrainer
# and calls trainPropertyValueModel() on macOS
# Training outputs go to configured modelOutputPath
```

## Code Architecture

### Data Persistence & State Management
- **SwiftData**: Primary persistence layer using `@Model` types in `Models/`
- **DataManager**: Central ModelContainer creation in `Core/DataManager.swift`
- **Observable Pattern**: `@Observable` classes for services (DataManager, MLPredictor, MarketDataService, MortgageAICoordinator)
- **Async Operations**: Extensive use of `async/await` and `Task {}` for AI services; prefer `async let` for parallel model calls

### Document Processing Pipeline
1. **Capture**: Camera/file import → DocumentProcessor
2. **OCR**: Vision Framework, AWS Textract, or Google Cloud OCR
3. **Audit**: AuditEngine manual calculations
4. **AI**: AIAnalysisService Claude integration via AWS Lambda
5. **Verify**: Cross-reference bank data via PlaidService
6. **Output**: LetterGenerationService for RESPA letters

### Machine Learning Integration
- **Training Pipeline**: `ML/MLModelTrainer.swift` and `ML/TrainingDataManager.swift`
- **Runtime Models**: Compiled `.mlmodelc` files in app bundle
- **Model Loading**: `MortgageAICoordinator.loadModels()` handles model initialization
- **Training Data**: `Resources/sample_property_data.json` provides example training data
- **AI Initialization**: `AISetupManager.setupAI()` runs during app startup

### Test Structure
- `Tests/UnitTests/`: Service-level tests (90% coverage required)
- `Tests/IntegrationTests/`: End-to-end workflows
- `Tests/UITests/`: UI automation tests
- `Tests/MockData/`: Mock services and test data
- `Tests/TestHelpers/`: Test utilities and base classes

### Security Patterns
- **Keychain Storage**: `SecurityService.keychain` and `SecureKeyManager` for API keys
- **Biometric Auth**: `LocalAuthentication` framework
- **Data Encryption**: AES-GCM encryption for data at rest
- **Network Security**: Certificate pinning for network requests
- **Secret Management**: Market data API keys stored via `SecureKeyManager` (Keychain)

### Error Handling
- Custom error enums per service (e.g., `AIAnalysisError`)
- Exponential backoff for network retries
- User-friendly localized error messages
- Comprehensive logging via `os.log`

## Development Patterns & Conventions

### SwiftData Model Management
- Use `@Model` types and `ModelContainer(mainContext)` via `DataManager`
- Fetch with `FetchDescriptor<T>` and `SortDescriptor`
- Keep model changes additive to avoid migration issues
- Key models: `SavedMortgageScenario`, `UserSettings`, `UserProfile` in `Models/PersistentModels.swift`

### UI & Theming
- Use `AppTheme.*` helpers for consistent styling
- Reuse existing design tokens (corner radius, colors)
- UI components for AI features: `AIInsightsView.swift`, `AIAffordabilityAnalyzer.swift`, `AIMonitoringDashboard.swift`

### Adding New Features
- **New AI Endpoint**: Create method on `MLPredictor`, call from `AIManager.analyzeScenario()`, persist to `SavedMortgageScenario`
- **New SwiftData Field**: Edit `Models/PersistentModels.swift`, add stored var and update initializer
- **New CoreML Model**: Place `.mlmodelc` in app bundle, update `MortgageAICoordinator.loadModels()`

## CI/CD & Release
- **GitHub Actions**: `.github/workflows/ci.yml` uses macOS runners and iPhone 15 iOS 17.0 simulator
- **Fastlane**: `fastlane/Fastfile` provides `beta`, `setup_app`, `setup_signing`, `increment_build_number` lanes
- **Required Environment Variables**: `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_KEY_CONTENT`, `PROVISIONING_PROFILE_SPECIFIER`, `MATCH_GIT_URL`

## Performance Requirements
- Document OCR: < 10 seconds
- AI analysis: < 30 seconds per document
- Plaid sync: < 5 seconds
- Memory: < 100MB peak usage
- Test coverage: 90% minimum, 95% for critical paths
- Initialize git
git init
git add .
git commit -m "Initial backend setup"

# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up

# Add environment variables in Railway dashboard
# Visit: railway.app/dashboard
# Click your project → Variables → Add all .env variables

# Add Redis addon
railway add redis

# Deploy worker as separate service
railway service create worker
# Edit Procfile or railway.json to run worker

# Get your Railway URL
railway domain
# Example: https://mortgage-analyzer-production.up.railway.app