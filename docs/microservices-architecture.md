# Mortgage Guardian 2.0 - Microservices Architecture

## Architecture Overview

### Service Boundaries & Domain-Driven Design

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI + SwiftData)               │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────────┐ │
│  │ Document     │ │ Audit        │ │ AI Analysis  │ │ Banking │ │
│  │ Management   │ │ Engine       │ │ Service      │ │ Service │ │
│  └──────────────┘ └──────────────┘ └──────────────┘ └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                 │
                          ┌──────▼──────┐
                          │ API Gateway │
                          │ (Cognito)   │
                          └─────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌───▼───┐                   ┌────▼────┐                  ┌───▼───┐
│Document│                   │  Audit  │                  │Banking│
│Service │                   │Workflow │                  │Service│
│       │                   │ (Step   │                  │       │
│       │                   │Functions)│                  │       │
└───┬───┘                   └────┬────┘                  └───┬───┘
    │                            │                            │
┌───▼───────────────────────────▼────────────────────────────▼───┐
│                   Shared Data Layer                           │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│
│ │ Audit Data  │ │Transaction  │ │ User Data   │ │ Document    ││
│ │ (DynamoDB)  │ │   Data      │ │ (DynamoDB)  │ │ Storage     ││
│ │             │ │ (DynamoDB)  │ │             │ │ (S3+Meta)   ││
│ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘│
└───────────────────────────────────────────────────────────────┘
```

## Microservices Design

### 1. Document Intelligence Service
**Bounded Context**: Document processing, OCR, text extraction, classification

**Responsibilities:**
- AWS Textract integration for OCR
- Document classification and routing
- Metadata extraction and indexing
- S3 lifecycle management
- Document versioning and audit trails

**API Endpoints:**
- `POST /v1/documents/upload` - Upload and process documents
- `GET /v1/documents/{id}` - Retrieve document and metadata
- `POST /v1/documents/{id}/extract` - Extract specific data fields
- `DELETE /v1/documents/{id}` - Secure document deletion

### 2. Legal Entity Extraction Service (Comprehend)
**Bounded Context**: Legal entity recognition, compliance pattern matching

**Responsibilities:**
- AWS Comprehend custom entity recognition
- Legal term extraction (loan numbers, servicer names, dates)
- Regulatory compliance pattern detection
- Entity relationship mapping

**API Endpoints:**
- `POST /v1/entities/extract` - Extract entities from document text
- `GET /v1/entities/types` - List supported entity types
- `POST /v1/entities/validate` - Validate extracted entities

### 3. Audit Orchestration Service (Step Functions)
**Bounded Context**: Audit workflow coordination, rule orchestration

**Responsibilities:**
- Coordinate multi-step audit processes
- Manage audit rule execution order
- Handle error recovery and retries
- Progress tracking and notifications
- Audit result aggregation

**Step Function Workflow:**
```
Start → Document Validation → Entity Extraction → Rule-Based Audit →
AI Analysis → Cross-Reference Banking → Generate Report → Notify User
```

### 4. Compliance Validation Service
**Bounded Context**: RESPA/TILA compliance, regulatory rule enforcement

**Responsibilities:**
- 50+ servicer violation pattern matching
- RESPA compliance checking
- TILA accuracy verification
- Bankruptcy/loss mitigation rights validation
- Force-placed insurance auditing

**API Endpoints:**
- `POST /v1/compliance/validate` - Run compliance checks
- `GET /v1/compliance/rules` - List available compliance rules
- `POST /v1/compliance/custom-rules` - Add custom validation rules

### 5. Financial Analysis Service
**Bounded Context**: Payment calculations, interest validation, escrow analysis

**Responsibilities:**
- Payment allocation validation
- Interest rate accuracy checking
- Escrow account analysis
- Fee calculation verification
- Principal/interest breakdown validation

### 6. Banking Integration Service (Enhanced Plaid)
**Bounded Context**: Bank account connectivity, transaction analysis

**Responsibilities:**
- Plaid Link token management
- Transaction synchronization
- Payment matching algorithms
- Bank statement reconciliation
- ACH payment tracking

### 7. AI Analysis Service (Enhanced Claude)
**Bounded Context**: Advanced document analysis, pattern recognition

**Responsibilities:**
- Claude API integration with failover
- Advanced pattern recognition
- Contextual analysis beyond rule-based checks
- Confidence scoring and validation
- Multi-document cross-referencing

### 8. Notification Service (SNS)
**Bounded Context**: User notifications, audit status updates

**Responsibilities:**
- iOS push notifications via SNS
- Audit completion alerts
- Error detection notifications
- Compliance violation alerts
- Progress update messaging

### 9. Data Synchronization Service
**Bounded Context**: Hybrid local/cloud data management

**Responsibilities:**
- SwiftData to DynamoDB synchronization
- Conflict resolution strategies
- Offline capability management
- Data versioning and merging
- Encryption key management

## Data Architecture

### DynamoDB Table Design

#### 1. AuditResults Table
```
PK: userId#auditId
SK: timestamp
GSI1: userId#status
GSI2: documentId#auditType
Attributes: {
  auditType, status, confidence, violations,
  ruleResults, aiAnalysis, bankingCrossRef,
  createdAt, updatedAt, version
}
```

#### 2. DocumentMetadata Table (Enhanced)
```
PK: userId#documentId
SK: version
GSI1: userId#documentType
GSI2: uploadDate#status
Attributes: {
  fileName, s3Key, documentType, extractedEntities,
  ocrResults, classificationScore, processingStatus,
  auditHistory, securityHash
}
```

#### 3. TransactionData Table
```
PK: userId#accountId
SK: transactionDate#transactionId
GSI1: userId#paymentType
GSI2: plaidTransactionId
Attributes: {
  amount, description, category, paymentMethod,
  matchedAuditResults, reconciliationStatus
}
```

#### 4. ComplianceRules Table
```
PK: ruleCategory
SK: ruleId
GSI1: priority#severity
Attributes: {
  ruleName, description, pattern, regulation,
  validationLogic, errorMessage, lastUpdated
}
```

## Security Architecture

### Zero-Trust Security Model
- All service-to-service communication via IAM roles
- KMS encryption for all data at rest
- API Gateway with WAF protection
- Cognito-based authentication with MFA
- VPC endpoints for internal communication

### Data Protection
- Field-level encryption for PII
- Document encryption before S3 storage
- Audit trail for all data access
- GDPR compliance with data deletion
- SOC 2 Type II compliance ready

## Resilience Patterns

### Circuit Breaker Implementation
- AWS SDK built-in retry with exponential backoff
- Service-specific circuit breakers
- Graceful degradation strategies
- Health check endpoints

### Monitoring & Observability
- X-Ray distributed tracing
- CloudWatch custom metrics
- Structured logging with correlation IDs
- Real-time alerting for SLA violations

## Performance Requirements

### Service SLAs
- Document upload: < 5 seconds
- OCR processing: < 15 seconds
- Rule-based audit: < 30 seconds
- AI analysis: < 60 seconds
- Plaid sync: < 10 seconds
- Push notifications: < 2 seconds

### Scalability Targets
- 10,000 concurrent document uploads
- 50,000 audit executions per hour
- 99.9% availability
- Multi-region disaster recovery

## Development & Deployment

### CI/CD Pipeline
```
Code Commit → Unit Tests → Integration Tests →
Security Scan → SAM Build → Canary Deployment →
Production Rollout → Monitoring
```

### Environment Strategy
- **Dev**: Full feature parity, synthetic data
- **Staging**: Production-like, real Plaid sandbox
- **Production**: Blue/green deployment with rollback

This architecture enables autonomous team development while maintaining system coherence and operational excellence.