# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mortgage Guardian 2.0 is an iOS application for detecting errors in mortgage loan servicing through AI-powered document analysis and automated audit algorithms. It combines Claude AI analysis with manual verification to identify discrepancies and generate RESPA-compliant dispute letters.

## Architecture

### iOS App
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS**: 17.0
- **Project**: `MortgageGuardian.xcodeproj`
- **Core Services**: Located in `MortgageGuardian/Services/`
  - AIAnalysisService, DocumentProcessor, AuditEngine, PlaidService, SecurityService, LetterGenerationService

### Backend (AWS SAM)
- **Template**: `mortgage-guardian-backend/template.yaml`
- **Runtime**: Node.js 18.x
- **Functions**: `src/claude-analysis/`, `src/plaid/`
- **API Gateway**: `/v1/ai/claude/analyze`, `/v1/plaid/{proxy+}`

## Build Commands

### iOS Build & Test
```bash
# Quick build test (uses iPhone 17 Pro simulator)
./test-build.sh

# Full build
xcodebuild -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug build

# Run all tests
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Unit tests only
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MortgageGuardianTests/UnitTests

# Integration tests
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MortgageGuardianTests/IntegrationTests
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

## Code Architecture

### Service Layer Pattern
- Singleton pattern: `ServiceName.shared`
- Published properties for SwiftUI: `@Published var property`
- Combine framework for reactive updates
- MainActor for UI safety: `@MainActor`

### Document Processing Pipeline
1. **Capture**: Camera/file import → DocumentProcessor
2. **OCR**: Vision Framework text extraction
3. **Audit**: AuditEngine manual calculations
4. **AI**: AIAnalysisService Claude integration
5. **Verify**: Cross-reference bank data via PlaidService
6. **Output**: LetterGenerationService for RESPA letters

### Test Structure
- `Tests/UnitTests/`: Service-level tests (90% coverage required)
- `Tests/IntegrationTests/`: End-to-end workflows
- `Tests/UITests/`: UI automation tests
- `Tests/MockData/`: Mock services and test data
- `Tests/TestHelpers/`: Test utilities and base classes

### Security Patterns
- Keychain for API keys: `SecurityService.keychain`
- Biometric auth: `LocalAuthentication` framework
- AES-GCM encryption for data at rest
- Certificate pinning for network requests
- Never commit secrets - use environment variables

### Error Handling
- Custom error enums per service (e.g., `AIAnalysisError`)
- Exponential backoff for network retries
- User-friendly localized error messages
- Comprehensive logging via `os.log`

## Performance Requirements
- Document OCR: < 10 seconds
- AI analysis: < 30 seconds per document
- Plaid sync: < 5 seconds
- Memory: < 100MB peak usage
- Test coverage: 90% minimum, 95% for critical paths