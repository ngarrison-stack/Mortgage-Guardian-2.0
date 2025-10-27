# Mortgage Guardian 2.0 - AWS Amplify Rebuild Plan

## Architecture Overview

### Frontend
- **iOS SwiftUI App** with AWS Amplify iOS SDK
- **Authentication**: AWS Cognito User Pools + Identity Pools
- **API Integration**: AWS AppSync (GraphQL) + REST API Gateway
- **File Storage**: Amazon S3 with Amplify Storage
- **Analytics**: Amazon Pinpoint

### Backend Services
- **Authentication**: AWS Cognito
- **API Layer**: AWS AppSync + API Gateway
- **Compute**: AWS Lambda functions
- **Storage**: Amazon S3 + DynamoDB
- **AI Services**: Amazon Bedrock (Claude), Amazon Textract
- **Banking**: Plaid API through Lambda + Secrets Manager
- **Security**: AWS Secrets Manager, KMS encryption

## Migration Plan

### Phase 1: Amplify Setup
1. Initialize Amplify project
2. Configure authentication with Cognito
3. Set up GraphQL API with AppSync
4. Configure storage with S3

### Phase 2: Authentication Migration
1. Replace SecurityService with Amplify Auth
2. Implement Cognito user pools
3. Add social sign-in (optional)
4. Set up multi-factor authentication

### Phase 3: API & Data Layer
1. Convert REST endpoints to GraphQL mutations/queries
2. Migrate DynamoDB schema to Amplify DataStore
3. Set up real-time subscriptions for document processing
4. Implement offline capability

### Phase 4: AI & Document Processing
1. Integrate Amazon Textract for OCR
2. Connect Amazon Bedrock for Claude AI analysis
3. Implement document analysis pipeline
4. Add audit engine Lambda functions

### Phase 5: Plaid Integration
1. Secure Plaid keys in AWS Secrets Manager
2. Create Lambda functions for Plaid operations
3. Implement encrypted access token storage
4. Add bank transaction sync

### Phase 6: iOS App Migration
1. Replace existing services with Amplify SDK
2. Implement GraphQL client for data operations
3. Add real-time updates with subscriptions
4. Integrate Amplify Storage for documents

## Detailed Implementation

### 1. Amplify Project Structure
```
amplify/
├── auth/
│   └── cognito-config.json
├── api/
│   ├── mortgageguardian/
│   │   ├── schema.graphql
│   │   └── resolvers/
├── storage/
│   └── s3-config.json
├── function/
│   ├── claudeAnalysis/
│   ├── plaidIntegration/
│   ├── textractProcessor/
│   └── auditEngine/
└── hosting/
```

### 2. Authentication with Cognito
- User pools for authentication
- Identity pools for AWS resource access
- Custom attributes for mortgage account info
- Password policies and MFA

### 3. GraphQL Schema Design
```graphql
type User @model @auth(rules: [{allow: owner}]) {
  id: ID!
  email: String!
  fullName: String!
  phoneNumber: String
  address: Address
  mortgageAccounts: [MortgageAccount] @hasMany
  documents: [Document] @hasMany
}

type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  fileName: String!
  documentType: DocumentType!
  s3Key: String!
  uploadDate: AWSDateTime!
  isAnalyzed: Boolean!
  analysisResults: [AuditResult] @hasMany
  owner: User @belongsTo
}

type AuditResult @model @auth(rules: [{allow: owner}]) {
  id: ID!
  issueType: IssueType!
  severity: Severity!
  title: String!
  description: String!
  affectedAmount: Float
  confidence: Float!
  detectionMethod: DetectionMethod!
  document: Document @belongsTo
}
```

### 4. Lambda Functions

#### Claude Analysis Function
```javascript
// Enhanced with Amplify integration
exports.handler = async (event) => {
  const { documentId, s3Key } = JSON.parse(event.body);

  // Get document from S3
  const document = await getDocumentFromS3(s3Key);

  // Process with Textract
  const extractedText = await processWithTextract(document);

  // Analyze with Claude via Bedrock
  const analysis = await analyzeWithClaude(extractedText);

  // Save results to DynamoDB via AppSync
  await saveAnalysisResults(documentId, analysis);

  return {
    statusCode: 200,
    body: JSON.stringify({ success: true, analysis })
  };
};
```

#### Plaid Integration Function
```javascript
exports.handler = async (event) => {
  const { action, payload } = JSON.parse(event.body);

  // Get Plaid credentials from Secrets Manager
  const plaidSecrets = await getSecret('plaid-credentials');

  switch (action) {
    case 'createLinkToken':
      return await createLinkToken(plaidSecrets, payload);
    case 'exchangeToken':
      return await exchangePublicToken(plaidSecrets, payload);
    case 'getAccounts':
      return await getAccounts(plaidSecrets, payload);
    case 'getTransactions':
      return await getTransactions(plaidSecrets, payload);
  }
};
```

### 5. iOS Amplify Integration

#### Amplify Configuration
```swift
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSS3StoragePlugin
import AWSDataStorePlugin

class AmplifyService {
    static let shared = AmplifyService()

    func configure() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            try Amplify.add(plugin: AWSDataStorePlugin(modelRegistration: AmplifyModels()))

            try Amplify.configure()
            print("Amplify configured successfully")
        } catch {
            print("Failed to configure Amplify: \(error)")
        }
    }
}
```

#### Authentication Service
```swift
import Amplify

@MainActor
class AuthService: ObservableObject {
    @Published var isSignedIn = false
    @Published var user: AuthUser?

    func signUp(email: String, password: String, fullName: String) async throws {
        let userAttributes = [
            AuthUserAttribute(.email, value: email),
            AuthUserAttribute(.name, value: fullName)
        ]

        _ = try await Amplify.Auth.signUp(
            username: email,
            password: password,
            options: .init(userAttributes: userAttributes)
        )
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Amplify.Auth.signIn(username: email, password: password)
        await fetchCurrentUser()
    }

    func fetchCurrentUser() async {
        do {
            let user = try await Amplify.Auth.getCurrentUser()
            await MainActor.run {
                self.user = user
                self.isSignedIn = true
            }
        } catch {
            await MainActor.run {
                self.isSignedIn = false
            }
        }
    }
}
```

#### Document Service
```swift
import Amplify

@MainActor
class DocumentService: ObservableObject {
    @Published var documents: [Document] = []

    func uploadDocument(data: Data, fileName: String, documentType: DocumentType) async throws -> Document {
        // Upload to S3
        let key = "documents/\(UUID().uuidString)/\(fileName)"
        _ = try await Amplify.Storage.uploadData(key: key, data: data)

        // Create document record
        let document = Document(
            fileName: fileName,
            documentType: documentType,
            s3Key: key,
            uploadDate: .now(),
            isAnalyzed: false
        )

        // Save to DataStore
        try await Amplify.DataStore.save(document)
        return document
    }

    func analyzeDocument(_ document: Document) async throws {
        // Call analysis API
        let request = RESTRequest(
            path: "/analyze",
            body: [
                "documentId": document.id,
                "s3Key": document.s3Key
            ].data(using: .utf8)
        )

        _ = try await Amplify.API.post(request: request)
    }

    func observeDocuments() {
        Amplify.DataStore.publisher(for: Document.self)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                // Handle completion
            } receiveValue: { mutationEvent in
                // Update documents array
                self.updateDocuments(from: mutationEvent)
            }
            .store(in: &cancellables)
    }
}
```

### 6. Security Enhancements
- Client-side encryption before S3 upload
- AWS KMS for encryption keys
- VPC endpoints for secure communication
- IAM roles with least privilege
- API rate limiting and authentication

### 7. Performance Optimizations
- GraphQL subscriptions for real-time updates
- DataStore for offline capability
- S3 Transfer Acceleration
- CloudFront for global distribution
- Optimized Lambda cold starts

### 8. Monitoring & Analytics
- CloudWatch for Lambda monitoring
- X-Ray for distributed tracing
- Pinpoint for user analytics
- Custom metrics for business insights

## Migration Timeline

### Week 1-2: Infrastructure Setup
- Initialize Amplify project
- Configure Cognito authentication
- Set up basic GraphQL schema
- Deploy initial Lambda functions

### Week 3-4: Core Services Migration
- Migrate authentication system
- Implement document upload/storage
- Set up Plaid integration
- Configure Textract processing

### Week 5-6: AI Integration
- Integrate Amazon Bedrock for Claude
- Migrate analysis algorithms
- Implement audit engine
- Set up real-time processing

### Week 7-8: iOS App Migration
- Replace existing services with Amplify
- Implement new authentication flow
- Update UI for real-time features
- Add offline capabilities

### Week 9-10: Testing & Deployment
- End-to-end testing
- Performance optimization
- Security audit
- Production deployment

## Benefits of Amplify Architecture

1. **Scalability**: Auto-scaling infrastructure
2. **Security**: Built-in security best practices
3. **Cost**: Pay-per-use pricing model
4. **Development Speed**: Pre-built components
5. **Real-time**: GraphQL subscriptions
6. **Offline**: DataStore sync capabilities
7. **Monitoring**: Integrated observability

## Next Steps

1. Run `amplify init` to create new project
2. Add authentication: `amplify add auth`
3. Add API: `amplify add api`
4. Add storage: `amplify add storage`
5. Add functions: `amplify add function`
6. Deploy: `amplify push`