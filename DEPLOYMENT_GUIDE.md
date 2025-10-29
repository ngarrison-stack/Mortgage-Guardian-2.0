# 🚀 Deployment Guide - Mortgage Guardian 2.0

## Overview

Deploying Mortgage Guardian requires setting up both the iOS app and backend infrastructure. This guide covers development testing, TestFlight beta distribution, and App Store production deployment.

## 📋 Prerequisites

### Required Accounts & Services
- **Apple Developer Account** ($99/year) - Required for device testing and App Store
- **Anthropic Claude API** - For AI document analysis
- **Plaid Developer Account** - For bank integration
- **Cloud Provider** (AWS/Google Cloud/Azure) - For backend infrastructure
- **Optional**: Firebase/Analytics for monitoring

### Development Environment
- macOS with Xcode 15.0+
- iOS 17.0+ device for testing
- Valid provisioning profiles and certificates

## 🏗️ Backend Infrastructure Setup

### Option 1: Serverless (Recommended for MVP)

#### AWS Lambda + API Gateway
```bash
# 1. Install AWS CLI and SAM
brew install aws-cli aws-sam-cli

# 2. Create backend infrastructure
mkdir mortgage-guardian-backend
cd mortgage-guardian-backend

# 3. Create SAM template
cat > template.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Parameters:
  ClaudeAPIKey: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
    Type: String
    NoEcho: true
  PlaidClientID:68bdabb75b00b300221d6a6f
    Type: String
  PlaidSecret:6280b4bbf54a1e7c04f8c13fc60939
    Type: String
    NoEcho: true

Resources:
  # API Gateway
  MortgageGuardianAPI:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"
        AllowHeaders: "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
        AllowOrigin: "'*'"

  # Claude Analysis Function
  ClaudeAnalysisFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/claude-analysis/
      Handler: index.handler
      Runtime: nodejs18.x
      Environment:
        Variables:
          CLAUDE_API_KEY: !Ref ClaudeAPIKey
      Events:
        AnalyzeDocument:
          Type: Api
          Properties:
            RestApiId: !Ref MortgageGuardianAPI
            Path: /v1/ai/claude/analyze
            Method: post

  # Plaid Integration Function
  PlaidFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/plaid/
      Handler: index.handler
      Runtime: nodejs18.x
      Environment:
        Variables:
          PLAID_CLIENT_ID: !Ref PlaidClientID
          PLAID_SECRET: !Ref PlaidSecret
      Events:
        PlaidLink:
          Type: Api
          Properties:
            RestApiId: !Ref MortgageGuardianAPI
            Path: /v1/plaid/{proxy+}
            Method: ANY

  # DynamoDB for user data
  UserDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: MortgageGuardianUsers
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH

Outputs:
  ApiUrl:
    Description: "API Gateway endpoint URL"
    Value: !Sub "https://${MortgageGuardianAPI}.execute-api.${AWS::Region}.amazonaws.com/prod/"
EOF

# 4. Deploy infrastructure
sam build
sam deploy --guided --parameter-overrides \
  ClaudeAPIKey=your-claude-api-key \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
  PlaidClientID=your-plaid-client-id \68bdabb75b00b300221d6a6f
  PlaidSecret=your-plaid-secret 6280b4bbf54a1e7c04f8c13fc60939
```

#### Backend Function Examples

**Claude Analysis Function** (`src/claude-analysis/index.js`):
```javascript
const https = require('https');

exports.handler = async (event) => {
    try {
        const { documentText, documentType, userContext } = JSON.parse(event.body);

        const claudeResponse = await callClaudeAPI({
            prompt: generatePrompt(documentText, documentType),
            max_tokens: 4000
        });

        const auditResults = parseClaudeResponse(claudeResponse);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: true,
                results: auditResults,
                confidence: calculateConfidence(auditResults)
            })
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};

async function callClaudeAPI(payload) {
    // Implementation for Claude API calls
    const options = {
        hostname: 'api.anthropic.com',
        path: '/v1/messages',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-API-Key': process.env.CLAUDE_API_KEY,
            'anthropic-version': '2023-06-01'
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(JSON.parse(data)));
        });
        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}
```

### Option 2: Container Deployment (Scalable)

#### Docker + Kubernetes
```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

```yaml
# kubernetes-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mortgage-guardian-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mortgage-guardian-api
  template:
    metadata:
      labels:
        app: mortgage-guardian-api
    spec:
      containers:
      - name: api
        image: your-registry/mortgage-guardian-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: CLAUDE_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: claude-api-key
        - name: PLAID_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: plaid-client-id
---
apiVersion: v1
kind: Service
metadata:
  name: mortgage-guardian-service
spec:
  selector:
    app: mortgage-guardian-api
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

## 📱 iOS App Configuration

### 1. Update Configuration Files

**Update Info.plist with production settings**:
```xml
<!-- Add to Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-api-domain.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Configure API Endpoints** in `Utils/Constants.swift`:
```swift
struct APIConfiguration {
    #if DEBUG
    static let baseURL = "https://dev-api.mortgageguardian.com"
    #else
    static let baseURL = "https://api.mortgageguardian.com"
    #endif

    static let claudeEndpoint = "\(baseURL)/v1/ai/claude"
    static let plaidEndpoint = "\(baseURL)/v1/plaid"
}
```

### 2. Code Signing & Provisioning

```bash
# 1. Create App ID in Apple Developer Portal
# 2. Create provisioning profiles
# 3. Configure in Xcode

# Update bundle identifier and team
sed -i '' 's/com.mortgageguardian.app/com.yourcompany.mortgageguardian/g' \
    MortgageGuardian.xcodeproj/project.pbxproj
```

### 3. Build Configurations

Create build scripts for different environments:

**scripts/build-development.sh**:
```bash
#!/bin/bash
xcodebuild -scheme MortgageGuardian \
           -configuration Debug \
           -destination 'generic/platform=iOS' \
           -archivePath ./build/MortgageGuardian-Dev.xcarchive \
           archive
```

**scripts/build-production.sh**:
```bash
#!/bin/bash
xcodebuild -scheme MortgageGuardian \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath ./build/MortgageGuardian-Prod.xcarchive \
           archive
```

## 🧪 Testing Deployment

### 1. Local Testing
```bash
# Run on simulator
xcodebuild -scheme MortgageGuardian \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           test

# Run on device
xcodebuild -scheme MortgageGuardian \
           -destination 'platform=iOS,id=YOUR_DEVICE_ID' \
           test
```

### 2. TestFlight Beta Deployment

```bash
# 1. Archive the app
./scripts/build-production.sh

# 2. Export for App Store distribution
xcodebuild -exportArchive \
           -archivePath ./build/MortgageGuardian-Prod.xcarchive \
           -exportPath ./build/export \
           -exportOptionsPlist ExportOptions.plist

# 3. Upload to App Store Connect
xcrun altool --upload-app \
             --type ios \
             --file "./build/export/MortgageGuardian.ipa" \
             --username "your@email.com" \
             --password "app-specific-password"
```

**ExportOptions.plist**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

## 🌐 Production Deployment

### 1. Domain & SSL Setup
```bash
# 1. Purchase domain (e.g., mortgageguardian.com)
# 2. Setup SSL certificate
# 3. Configure DNS records

# AWS Route 53 example
aws route53 create-hosted-zone --name mortgageguardian.com
```

### 2. Security Configuration

**Environment Variables** (use AWS Secrets Manager):
```bash
# Store sensitive data securely
aws secretsmanager create-secret \
    --name "mortgage-guardian/prod/claude-api-key" \
    --secret-string "your-claude-api-key"

aws secretsmanager create-secret \
    --name "mortgage-guardian/prod/plaid-credentials" \
    --secret-string '{"client_id":"xxx","secret":"yyy"}'
```

### 3. Monitoring & Analytics

**CloudWatch Setup**:
```yaml
# cloudwatch-config.yaml
Resources:
  ApiLogsGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/mortgage-guardian-api
      RetentionInDays: 30

  ErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: MortgageGuardian-Errors
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
```

## 📊 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy Mortgage Guardian

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    - name: Run Tests
      run: xcodebuild test -scheme MortgageGuardian -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

  deploy-backend:
    runs-on: ubuntu-latest
    needs: test
    steps:
    - uses: actions/checkout@v3
    - name: Configure AWS
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    - name: Deploy Backend
      run: |
        cd backend
        sam build
        sam deploy --no-confirm-changeset

  deploy-ios:
    runs-on: macos-latest
    needs: [test, deploy-backend]
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Build and Upload to TestFlight
      env:
        FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
      run: |
        bundle install
        bundle exec fastlane beta
```

## 📱 App Store Submission

### 1. App Store Connect Setup
1. **Create App Record** in App Store Connect
2. **Upload Screenshots** (required sizes for all devices)
3. **Write App Description** and keywords
4. **Set Pricing** and availability
5. **Configure App Review Information**

### 2. Privacy & Compliance

**Privacy Policy** (required for financial apps):
```markdown
# Privacy Policy - Mortgage Guardian

## Data Collection
- Document text for analysis
- Bank transaction data (via Plaid)
- User profile information

## Data Usage
- Mortgage servicing error detection
- Letter generation for disputes
- App functionality improvement

## Data Protection
- AES-256 encryption for all data
- Secure transmission using TLS 1.3
- No data sharing with third parties
- User control over data deletion

## Compliance
- RESPA regulation compliance
- SOX financial data handling
- GDPR user rights support
```

**App Review Notes**:
```
Test Account Credentials:
- Email: reviewer@mortgageguardian.com
- Password: TestAccount2024!

Demo Instructions:
1. Use provided test documents in app bundle
2. Skip Plaid linking for demo (use "Skip" button)
3. AI analysis uses demo responses for review
4. All generated letters are clearly marked as "DEMO"

Key Features to Test:
- Document camera scanning
- AI-powered error detection
- Professional letter generation
- Security features (Face ID demo mode)
```

### 3. Final Checklist

**Before Submission**:
- [ ] All APIs working in production
- [ ] Test with real mortgage documents
- [ ] Verify bank integration (Plaid)
- [ ] Security review completed
- [ ] Performance testing passed
- [ ] Accessibility compliance verified
- [ ] Privacy policy published
- [ ] App Store screenshots ready
- [ ] TestFlight beta testing completed
- [ ] Legal review for RESPA compliance

## 🚨 Security Considerations

### Production Security Checklist
- [ ] API keys stored in secure environment variables
- [ ] HTTPS everywhere with certificate pinning
- [ ] Input validation on all API endpoints
- [ ] Rate limiting implemented
- [ ] Logging configured (without sensitive data)
- [ ] Backup and disaster recovery plan
- [ ] Security monitoring and alerting
- [ ] Regular security audits scheduled

### Compliance Requirements
- **RESPA Compliance**: Letter generation follows regulation
- **SOX Compliance**: Financial data handling procedures
- **Data Retention**: 7-year retention for audit records
- **User Consent**: Clear opt-in for all data collection
- **Right to Delete**: User data deletion capabilities

## 💰 Cost Estimation

### Monthly Operating Costs (estimated)
- **AWS Infrastructure**: $100-500/month (depending on usage)
- **Claude API**: $0.10-1.00 per document analysis
- **Plaid API**: $0.25 per connected account per month
- **Apple Developer**: $99/year
- **Domain & SSL**: $50/year

### Scaling Considerations
- **10,000 users**: ~$1,000/month
- **100,000 users**: ~$5,000/month
- **1M users**: ~$25,000/month

## 📞 Support & Maintenance

### Post-Deployment Tasks
1. **Monitor Performance**: CloudWatch dashboards
2. **User Feedback**: In-app feedback collection
3. **Bug Tracking**: Issue management system
4. **Updates**: Regular iOS and backend updates
5. **Compliance**: Stay current with regulations

### Update Strategy
- **iOS App**: Monthly feature updates, weekly bug fixes
- **Backend**: Continuous deployment for API improvements
- **Security**: Immediate patches for vulnerabilities
- **Compliance**: Quarterly regulatory review

---

## 🎉 Quick Start Deployment

For immediate testing, use this simplified deployment:

```bash
# 1. Clone and setup
git clone https://github.com/yourusername/mortgage-guardian
cd mortgage-guardian

# 2. Configure Xcode project
open MortgageGuardian.xcodeproj

# 3. Update team and bundle ID
# 4. Build and run on device

# 5. Deploy simple backend (optional for initial testing)
# The app includes mock services for development
```

The app includes comprehensive mock data and services, so you can test all features without a backend initially. This allows for immediate demonstration and development while you set up production infrastructure.

Remember: This is a financial application handling sensitive data. Always prioritize security, compliance, and thorough testing before any production deployment.
