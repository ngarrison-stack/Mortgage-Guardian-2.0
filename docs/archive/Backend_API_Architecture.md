# Backend API Architecture for AIAnalysisService

## Overview

This document outlines the backend API architecture required to support the AIAnalysisService in the Mortgage Guardian mobile application. The backend serves as a secure proxy between the mobile app and Claude AI API, ensuring proper authentication, rate limiting, and compliance with financial data regulations.

## Architecture Principles

- **Security First**: All API communications are encrypted and authenticated
- **Scalability**: Designed to handle concurrent analysis requests
- **Reliability**: Implements retry logic, circuit breakers, and graceful degradation
- **Compliance**: Adheres to financial data protection regulations (SOX, GLBA, etc.)
- **Auditability**: Comprehensive logging and monitoring of all AI interactions

## API Endpoints

### 1. AI Document Analysis

#### POST /v1/ai/claude/analyze

Performs comprehensive document analysis using Claude AI.

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
X-Request-ID: <unique_request_id>
X-Client-Version: <app_version>
X-Timestamp: <unix_timestamp>
X-Signature: <hmac_signature>
```

**Request Body:**
```json
{
  "documentId": "string (UUID)",
  "documentType": "mortgage_statement|escrow_statement|payment_history|loan_documents",
  "documentContent": "string (preprocessed text)",
  "userContext": {
    "userId": "string (UUID)",
    "borrowerName": "string",
    "mortgageAccounts": [
      {
        "loanNumber": "string",
        "servicerName": "string",
        "originalAmount": "number",
        "currentBalance": "number",
        "interestRate": "number",
        "monthlyPayment": "number"
      }
    ]
  },
  "analysisConfiguration": {
    "model": "claude-3-5-sonnet-20241022",
    "maxTokens": 4096,
    "temperature": 0.1,
    "analysisType": "comprehensive|focused|validation"
  },
  "bankTransactions": [
    {
      "date": "string (ISO 8601)",
      "amount": "number",
      "description": "string",
      "category": "mortgage_payment"
    }
  ]
}
```

**Response:**
```json
{
  "requestId": "string (UUID)",
  "status": "success|error|partial",
  "analysisResult": {
    "findings": [
      {
        "issueType": "string",
        "severity": "low|medium|high|critical",
        "title": "string",
        "description": "string",
        "detailedExplanation": "string",
        "suggestedAction": "string",
        "affectedAmount": "number|null",
        "confidence": "number (0-1)",
        "evidenceText": "string",
        "detectionMethod": "ai_analysis"
      }
    ],
    "confidence": "number (0-1)",
    "metadata": {
      "modelUsed": "string",
      "tokensUsed": {
        "input": "number",
        "output": "number",
        "total": "number"
      },
      "processingTime": "number (seconds)",
      "analysisDate": "string (ISO 8601)"
    }
  },
  "errors": [
    {
      "code": "string",
      "message": "string",
      "details": "object"
    }
  ]
}
```

**Error Codes:**
- `INVALID_DOCUMENT_TYPE`: Unsupported document type
- `DOCUMENT_TOO_LARGE`: Document exceeds size limits
- `RATE_LIMIT_EXCEEDED`: API rate limit exceeded
- `QUOTA_EXCEEDED`: Daily/monthly quota exceeded
- `INVALID_CONFIGURATION`: Invalid analysis configuration
- `CLAUDE_API_ERROR`: Error from Claude API
- `INSUFFICIENT_CONTEXT`: Insufficient information for analysis
- `SECURITY_VALIDATION_FAILED`: Security checks failed

### 2. Letter Generation

#### POST /v1/ai/claude/generate-letter

Generates RESPA-compliant letters using Claude AI.

**Request Body:**
```json
{
  "letterType": "notice_of_error|qualified_written_request|escalation_letter|consumer_complaint",
  "userInfo": {
    "fullName": "string",
    "email": "string",
    "address": {
      "street": "string",
      "city": "string",
      "state": "string",
      "zipCode": "string"
    },
    "phoneNumber": "string"
  },
  "mortgageAccount": {
    "loanNumber": "string",
    "servicerName": "string",
    "servicerAddress": "string",
    "propertyAddress": "string",
    "originalLoanAmount": "number",
    "monthlyPayment": "number"
  },
  "issues": [
    {
      "issueType": "string",
      "title": "string",
      "description": "string",
      "affectedAmount": "number|null",
      "severity": "string"
    }
  ],
  "generatePDF": "boolean"
}
```

**Response:**
```json
{
  "requestId": "string (UUID)",
  "letterContent": "string",
  "letterType": "string",
  "metadata": {
    "generatedDate": "string (ISO 8601)",
    "urgencyLevel": "routine|urgent|critical",
    "totalAffectedAmount": "number",
    "expectedResponseTimeframe": "string"
  },
  "pdfData": "string (base64)|null"
}
```

### 3. Analysis Status and History

#### GET /v1/ai/analysis/{analysisId}

Retrieves the status and results of a specific analysis.

#### GET /v1/ai/analysis/history

Retrieves analysis history for the authenticated user.

**Query Parameters:**
- `limit`: Number of results (default: 50, max: 100)
- `offset`: Pagination offset
- `documentType`: Filter by document type
- `startDate`: Filter by start date (ISO 8601)
- `endDate`: Filter by end date (ISO 8601)

### 4. Configuration and Limits

#### GET /v1/ai/config

Returns current AI service configuration and usage limits.

**Response:**
```json
{
  "availableModels": [
    {
      "id": "claude-3-5-sonnet-20241022",
      "name": "Claude 3.5 Sonnet",
      "contextWindow": 200000,
      "costPerToken": 0.000003
    }
  ],
  "rateLimits": {
    "requestsPerMinute": 50,
    "tokensPerMinute": 40000,
    "requestsPerDay": 1000
  },
  "currentUsage": {
    "requestsToday": 123,
    "tokensToday": 25000,
    "quotaRemaining": 877
  }
}
```

## Security Architecture

### Authentication and Authorization

1. **JWT Authentication**: All requests must include a valid JWT token
2. **Request Signing**: HMAC-SHA256 signature for request integrity
3. **API Key Management**: Secure storage and rotation of Claude API keys
4. **User Context Validation**: Verify user access to requested documents

### Security Headers

```http
Authorization: Bearer <jwt_token>
X-Request-ID: <uuid>
X-Timestamp: <unix_timestamp>
X-Signature: <hmac_sha256_signature>
X-Client-Version: <version>
Content-Type: application/json
```

### Signature Generation

```
string_to_sign = HTTP_METHOD + "\n" +
                 REQUEST_PATH + "\n" +
                 TIMESTAMP + "\n" +
                 BASE64(REQUEST_BODY)

signature = HMAC_SHA256(string_to_sign, API_SECRET)
```

### Data Sanitization

Before sending to Claude API:
1. Remove or mask SSN patterns
2. Redact account numbers
3. Remove sensitive personal information
4. Validate document content for malicious patterns

## Rate Limiting Strategy

### Tier-Based Limits

**Free Tier:**
- 10 analyses per day
- 5,000 tokens per day
- Basic model only (Claude 3 Haiku)

**Premium Tier:**
- 100 analyses per day
- 50,000 tokens per day
- All models available

**Enterprise Tier:**
- Custom limits
- Priority processing
- Dedicated resources

### Implementation

```javascript
// Redis-based rate limiting
const rateLimiter = {
  requests: {
    window: '1m',
    limit: 50,
    key: `rate_limit:requests:${userId}`
  },
  tokens: {
    window: '1m',
    limit: 40000,
    key: `rate_limit:tokens:${userId}`
  },
  daily: {
    window: '1d',
    limit: 1000,
    key: `rate_limit:daily:${userId}`
  }
}
```

## Error Handling

### Circuit Breaker Pattern

```javascript
const circuitBreaker = {
  failureThreshold: 5,
  resetTimeout: 30000,
  monitoringPeriod: 60000,
  fallbackResponse: {
    status: 'service_unavailable',
    message: 'AI analysis temporarily unavailable',
    retryAfter: 30
  }
}
```

### Retry Strategy

```javascript
const retryConfig = {
  maxRetries: 3,
  baseDelay: 1000,
  maxDelay: 10000,
  backoffMultiplier: 2,
  retryableErrors: [
    'NETWORK_ERROR',
    'TIMEOUT_ERROR',
    'RATE_LIMIT_EXCEEDED',
    'INTERNAL_SERVER_ERROR'
  ]
}
```

## Performance Optimization

### Caching Strategy

1. **Response Caching**: Cache identical analysis requests for 1 hour
2. **Context Caching**: Cache user/account context for 15 minutes
3. **Model Response Caching**: Cache Claude responses with document hash

### Load Balancing

- Round-robin distribution across multiple backend instances
- Health checks every 30 seconds
- Automatic failover to healthy instances
- Circuit breaker integration

### Database Optimization

```sql
-- Indexes for analysis history queries
CREATE INDEX idx_analysis_user_date ON analysis_results (user_id, created_at DESC);
CREATE INDEX idx_analysis_document_type ON analysis_results (document_type, created_at DESC);
CREATE INDEX idx_analysis_status ON analysis_results (status, created_at DESC);

-- Partitioning by date for large datasets
CREATE TABLE analysis_results_2024_01 PARTITION OF analysis_results
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## Monitoring and Observability

### Metrics to Track

1. **Request Metrics**:
   - Request rate (RPM)
   - Response time (P50, P95, P99)
   - Error rate by endpoint
   - Token usage per request

2. **Business Metrics**:
   - Analysis success rate
   - Average confidence scores
   - Issue detection accuracy
   - User satisfaction ratings

3. **Infrastructure Metrics**:
   - CPU and memory usage
   - Database connection pool utilization
   - Claude API response times
   - Cache hit rates

### Logging Strategy

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "ai-analysis-api",
  "requestId": "req_123456",
  "userId": "user_789",
  "endpoint": "/v1/ai/claude/analyze",
  "method": "POST",
  "statusCode": 200,
  "responseTime": 2340,
  "tokensUsed": 1234,
  "documentType": "mortgage_statement",
  "aiModel": "claude-3-5-sonnet",
  "confidence": 0.92,
  "findingsCount": 3
}
```

### Alerting Rules

1. **Error Rate > 5%** for 5 minutes
2. **Response Time > 10s** for P95 over 5 minutes
3. **Claude API Errors > 10** in 1 minute
4. **Daily Token Usage > 80%** of quota
5. **Circuit Breaker Open** for any Claude API calls

## Compliance and Auditing

### Data Governance

1. **Data Retention**: Analysis results retained for 7 years
2. **Data Encryption**: All data encrypted at rest and in transit
3. **Access Logging**: All data access logged and monitored
4. **Right to Deletion**: User data deletion capabilities

### Audit Trail

```json
{
  "auditId": "audit_123456",
  "timestamp": "2024-01-15T10:30:00Z",
  "action": "AI_ANALYSIS_PERFORMED",
  "userId": "user_789",
  "documentId": "doc_456",
  "aiModel": "claude-3-5-sonnet",
  "inputTokens": 2000,
  "outputTokens": 500,
  "confidence": 0.92,
  "findingsGenerated": 3,
  "piiDetected": false,
  "dataClassification": "CONFIDENTIAL"
}
```

### Regulatory Compliance

1. **SOX Compliance**: Audit trails for financial data processing
2. **GLBA Compliance**: Financial privacy protection measures
3. **RESPA Compliance**: Accurate mortgage servicing analysis
4. **GDPR Compliance**: Data protection and privacy rights

## Deployment Architecture

### Infrastructure Components

1. **Load Balancer**: AWS ALB with SSL termination
2. **API Gateway**: AWS API Gateway for rate limiting and monitoring
3. **Compute**: ECS Fargate containers for auto-scaling
4. **Database**: RDS PostgreSQL with read replicas
5. **Cache**: Redis ElastiCache cluster
6. **Storage**: S3 for document storage with encryption

### Environment Configuration

**Production:**
- Multi-AZ deployment
- Auto-scaling groups
- Blue-green deployments
- Comprehensive monitoring

**Staging:**
- Single AZ deployment
- Manual scaling
- Subset of production data
- Full monitoring stack

**Development:**
- Local or single instance
- Mock Claude API responses
- Sample test data
- Basic monitoring

## Cost Optimization

### Token Usage Optimization

1. **Prompt Optimization**: Minimize token usage while maintaining accuracy
2. **Response Caching**: Avoid duplicate API calls
3. **Model Selection**: Use appropriate model for task complexity
4. **Request Batching**: Combine multiple documents when possible

### Infrastructure Costs

1. **Auto-scaling**: Scale down during low usage periods
2. **Reserved Instances**: Use RIs for predictable workloads
3. **Spot Instances**: Use spot instances for non-critical processing
4. **Storage Optimization**: Compress and archive old data

### Estimated Costs (Monthly)

- **Claude API**: $500-2000 (based on usage)
- **AWS Infrastructure**: $800-1500
- **Monitoring/Logging**: $200-400
- **Total**: $1500-3900 per month

## Implementation Timeline

### Phase 1 (4 weeks): Core Infrastructure
- [ ] Basic API endpoints
- [ ] Authentication and security
- [ ] Claude API integration
- [ ] Basic rate limiting

### Phase 2 (3 weeks): Advanced Features
- [ ] Response caching
- [ ] Circuit breakers
- [ ] Comprehensive monitoring
- [ ] Error handling

### Phase 3 (2 weeks): Optimization
- [ ] Performance tuning
- [ ] Advanced caching
- [ ] Load testing
- [ ] Documentation

### Phase 4 (2 weeks): Production Ready
- [ ] Security audit
- [ ] Compliance validation
- [ ] Deployment automation
- [ ] Monitoring dashboards

## API Testing Strategy

### Unit Tests
- Input validation
- Business logic
- Error handling
- Security functions

### Integration Tests
- Claude API integration
- Database operations
- Cache operations
- External service calls

### Load Tests
- Concurrent user simulation
- Rate limiting validation
- Performance benchmarks
- Scalability testing

### Security Tests
- Authentication bypass attempts
- SQL injection tests
- XSS vulnerability tests
- Rate limiting bypass tests

This comprehensive backend API architecture provides the foundation for secure, scalable, and compliant AI-powered mortgage document analysis while ensuring optimal performance and cost-effectiveness.