# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mortgage Guardian 2.0 is a comprehensive iOS application that helps homeowners detect errors in mortgage loan servicing through AI-powered document analysis and automated audit algorithms. The app combines Claude AI's document analysis with manual verification algorithms to identify discrepancies and generate RESPA-compliant dispute letters.

## Architecture

### Frontend (iOS App)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS Version**: 17.0
- **Project File**: `MortgageGuardian.xcodeproj`

### Backend (AWS Serverless)
- **Infrastructure**: AWS SAM (Serverless Application Model)
- **Runtime**: Node.js 18.x
- **Template**: `mortgage-guardian-backend/template.yaml`
- **Functions**: Claude Analysis, Plaid Integration

## Core Services

### iOS Services (in MortgageGuardian/)
- **AIAnalysisService**: Claude AI integration for document analysis
- **DocumentProcessor**: OCR and text extraction using Vision Framework
- **AuditEngine**: Manual verification algorithms and calculations
- **PlaidService**: Bank account linking and transaction correlation
- **SecurityService**: Biometric auth, encryption, secure storage
- **LetterGenerationService**: RESPA-compliant letter creation

## Build and Test Commands

### iOS Development

Build for simulator:
```bash
xcodebuild -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug build
```

Run all tests:
```bash
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Run specific test categories:
```bash
# Unit tests only
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MortgageGuardianTests/UnitTests

# Integration tests only
xcodebuild test -scheme MortgageGuardian \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MortgageGuardianTests/IntegrationTests
```

Quick test build:
```bash
./test-build.sh
```

### Backend Development

Deploy backend (requires AWS CLI and SAM CLI):
```bash
cd mortgage-guardian-backend
sam build
sam deploy --guided
```

Install backend dependencies:
```bash
cd mortgage-guardian-backend/src/plaid && npm install
cd ../claude-analysis && npm install
```

### Developer Setup

Configure Xcode project for development:
```bash
./scripts/setup-developer.sh
```

Quick setup for new developers:
```bash
./scripts/quick-setup.sh
```

## Key Implementation Details

### Service Integration Pattern
All services follow a singleton pattern with published properties for SwiftUI integration:
```swift
@StateObject private var service = ServiceName.shared
```

### Security Requirements
- All sensitive data must be encrypted using SecurityService
- API keys stored in Keychain, never in code
- Biometric authentication required for sensitive operations
- Use AES-GCM encryption for data at rest

### Document Processing Flow
1. Document capture/import → DocumentProcessor
2. OCR text extraction → Vision Framework
3. Manual audit → AuditEngine
4. AI analysis → AIAnalysisService
5. Results correlation → Cross-verification
6. Letter generation → LetterGenerationService

### Testing Standards
- Minimum 90% code coverage for all services
- Critical paths require 95% coverage
- Security code requires 100% coverage
- Use MockData and MockServices from Tests/MockData/

### Error Handling Pattern
All services implement comprehensive error handling with recovery:
- Network errors: Exponential backoff retry
- Data errors: Graceful degradation
- Security errors: User re-authentication
- Business logic errors: User-friendly messages

### API Integration
- Plaid: Bank account linking and transactions
- Claude: Document analysis via AWS Lambda
- All API calls through secure backend proxy
- Never expose API keys in iOS app

## Environment Configuration

### Required Environment Variables (Backend)
- `CLAUDE_API_KEY`: Claude API key for analysis
- `PLAID_CLIENT_ID`: Plaid client ID
- `PLAID_SECRET`: Plaid secret key

### Xcode Configuration
- Bundle ID: Must be unique (e.g., com.yourcompany.mortgageguardian)
- Development Team: Set in project settings
- Signing: Automatic signing recommended for development

## Performance Benchmarks
- Document processing: < 10 seconds
- AI analysis: < 30 seconds
- Plaid sync: < 5 seconds
- Memory usage: < 100MB peak during processing