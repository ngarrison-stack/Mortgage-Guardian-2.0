# Copilot instructions for Mortgage Guardian (code agents)

These instructions orient automated coding agents to the repository structure, conventions, and developer workflows so they can be productive quickly.

- Big picture
  - iOS SwiftUI app using SwiftData for persistence. Key entry point: `MortgageGuardian/MortgageGuardianApp.swift` (injects `DataManager`).
  - Core data flow: SwiftUI views ↔ DataManager (SwiftData ModelContainer & ModelContext) ↔ @Model types in `Models/`.
  - AI subsystem is a first-class service layer under `Services/` and `ML/`:
    - Runtime prediction/analysis: `Services/MLPredictor.swift`, `Services/AIManager.swift`, `Services/MortgageAICoordinator.swift`.
    - Document OCR/analysis: `Services/DocumentAnalysisService.swift`.
    - Market data fetcher: `Services/MarketDataService.swift`.
    - Offline training pipeline and helper: `ML/MLModelTrainer.swift`, `ML/TrainingDataManager.swift`.
  - UI components for AI features live under `Views/` (e.g. `AIInsightsView.swift`, `AIAffordabilityAnalyzer.swift`, `AIMonitoringDashboard.swift`).

- Important files to inspect when making changes
  - `fastlane/Fastfile` — lanes used by CI and release automation; lanes: `beta`, `setup_app`, `setup_signing`, `increment_build_number`.
  - `.github/workflows/ci.yml` — macOS CI build and test steps (uses xcodebuild against `MortgageGuardian.xcodeproj` and iPhone 15 iOS 17.0 simulator). Use same xcodebuild flags for local reproductions.
  - `Core/DataManager.swift` — central SwiftData container creation and helper methods (fetch/save/delete scenarios).
  - `Models/` — SwiftData model definitions (SavedMortgageScenario, UserSettings, UserProfile). Update model schema carefully: SwiftData @Model changes may require migration.
  - `Services/` & `ML/` — where AI/ML logic and model training lives. Training code uses CreateML/MLDataTable; runtime code expects compiled `.mlmodelc` in app bundle.
  - `Resources/sample_property_data.json` — example training data used by `TrainingDataManager`.

- Developer workflows & concrete commands
  - Local build + tests (mirror CI):
    - xcodebuild clean build -project MortgageGuardian.xcodeproj -scheme MortgageGuardian -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15,OS=17.0" CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
    - xcodebuild test     -project MortgageGuardian.xcodeproj -scheme MortgageGuardian -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15,OS=17.0" CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
  - Fastlane lanes (release automation):
    - `bundle exec fastlane ios beta` — builds and uploads to TestFlight (expects APPLE_KEY_* env vars and PROVISIONING_PROFILE_SPECIFIER).
    - `bundle exec fastlane ios setup_signing` — uses `match` and requires `MATCH_GIT_URL` env var.
  - Training & ML
    - Training pipeline scaffolding lives in `ML/MLModelTrainer.swift` and `ML/TrainingDataManager.swift`.
    - To run training locally you will need macOS CreateML environment; trainer uses file paths set in code (`modelOutputPath` / trainingDataPath). Example: compile and run a small script that instantiates `MLModelTrainer` and calls `trainPropertyValueModel()` on macOS.
  - AI initialization on app launch: `Services/AISetupManager.swift` integrates with `MortgageGuardianApp` startup via `setupAI()` (app will attempt to prepare training data and train initial models).

- Conventions and patterns
  - Persistence: Use SwiftData `@Model` types and `ModelContainer(mainContext)` via `DataManager`. Fetch with `FetchDescriptor<T>` and `SortDescriptor`.
  - Observable pattern: `@Observable` classes are used for services (DataManager, MLPredictor, MarketDataService, MortgageAICoordinator) so views can observe state changes.
  - Async/Task: AI services use `async/await` and `Task {}` frequently. Prefer `async let` for parallelizable model calls (already used in `AIManager`).
  - UI theme: `AppTheme.*` helpers are used for styling; reuse existing tokens (corner radius, colors) when adding components.
  - Model files: runtime expects compiled Core ML models in the bundle (e.g. `PropertyValuePredictor.mlmodelc`). Training outputs are expected under configured `modelOutputPath` — update `MortgageAICoordinator.loadModels()` if adding new models.

- Integration & external dependencies
  - App Store & CI: Fastlane + GitHub Actions. CI uses macOS runners and `maxim-lobanov/setup-xcode@v1` to set Xcode.
  - Secrets: Fastlane expects env vars `APPLE_KEY_ID`, `APPLE_ISSUER_ID`, `APPLE_KEY_CONTENT`, `PROVISIONING_PROFILE_SPECIFIER`, `MATCH_GIT_URL`. Local dev must set these in env or use the project's scripts (if present) to inject secrets.
  - Market data / real estate APIs: MarketDataService has placeholders for API keys — keys are stored via `SecureKeyManager` (Keychain); replace placeholders and wire real endpoints.

- Safe change guidance (how to edit things without breaking builds)
  - When modifying `@Model` types in `Models/`, keep changes additive where possible to avoid SwiftData migration issues; run local app to allow container creation and inspect ModelContainer errors.
  - When editing Fastfile lanes, preserve existing lane names and option names — CI and release automation call these exact lanes.
  - Tests & CI reproducibility: use the exact simulator name and iOS version from `ci.yml` when reproducing CI jobs locally.

- Quick examples for agents (use these exact paths/snippets)
  - Add a new field to SavedMortgageScenario: edit `Models/PersistentModels.swift`, add a stored var and set in initializer; update any DataManager save calls.
  - To add a new AI endpoint: create a new method on `MLPredictor` and call it from `AIManager.analyzeScenario(...)` then persist result onto `SavedMortgageScenario`.
  - To add compiled CoreML model: put `.mlmodelc` into app bundle (`MortgageGuardian/Models/` or the app target resources) and update `MortgageAICoordinator.loadModels()` to load by resource name.

If anything above is unclear or you want examples for specific tasks (e.g., adding a new @Model field, wiring a new CoreML model, or updating Fastlane lanes), tell me which area and I will expand the instructions with a targeted example and automated edits.
