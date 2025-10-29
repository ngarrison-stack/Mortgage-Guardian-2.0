# Plaid API Security Best Practices

## Overview

This document outlines security best practices for the Plaid API implementation in Mortgage Guardian. Following these practices is critical for protecting user financial data and maintaining compliance with banking regulations.

---

## Critical Security Issues Identified & Fixed

### 1. Access Token Exposure (FIXED)

**Previous Issue:**
- Access tokens were returned directly to iOS client without warning
- No encryption guidance for storage
- Tokens could be logged or exposed

**Solution Implemented:**
- Added security warnings in API responses
- Documented Keychain storage requirement for iOS
- Never log tokens in production
- Implement token validation before use

### 2. Missing Input Validation (FIXED)

**Previous Issue:**
- No validation of token formats
- No date range validation
- No sanitization of user input

**Solution Implemented:**
- Token format validation (must start with `access-` or `public-`)
- Date format validation (YYYY-MM-DD)
- Date range limits (max 2 years for transactions)
- Input sanitization middleware to prevent XSS

### 3. No Webhook Security (FIXED)

**Previous Issue:**
- Webhook endpoint accepted all requests
- No signature verification
- Vulnerable to spoofing attacks

**Solution Implemented:**
- HMAC-SHA256 signature verification
- Constant-time comparison to prevent timing attacks
- Webhook verification key configuration
- Reject invalid signatures with 401 Unauthorized

### 4. Error Information Leakage (FIXED)

**Previous Issue:**
- Stack traces exposed in production
- Detailed error messages could reveal system internals

**Solution Implemented:**
- Generic error messages in production
- Detailed errors only in development
- Structured error logging without sensitive data
- User-friendly error messages

### 5. Missing Rate Limiting (FIXED)

**Previous Issue:**
- No protection against brute force attacks
- Could exhaust Plaid API quota

**Solution Implemented:**
- Express rate limiting middleware
- 100 requests per 15 minutes per IP (configurable)
- Rate limit applied to all `/v1/` routes

---

## Access Token Security

### Storage Requirements

**Backend (Node.js):**
```javascript
// DO: Store encrypted in database
const encryptedToken = encrypt(accessToken, encryptionKey);
await db.query(
  'INSERT INTO plaid_tokens (user_id, encrypted_token, item_id) VALUES (?, ?, ?)',
  [userId, encryptedToken, itemId]
);

// DON'T: Store in plain text
await db.query(
  'INSERT INTO plaid_tokens (user_id, token) VALUES (?, ?)',
  [userId, accessToken] // INSECURE!
);
```

**iOS (Swift):**
```swift
// DO: Use Keychain
import Security

class KeychainHelper {
    static func save(_ token: String, for key: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}

// DON'T: Use UserDefaults
UserDefaults.standard.set(accessToken, forKey: "token") // INSECURE!
```

### Token Lifecycle

1. **Creation**: Obtain via `/exchange_token`
2. **Storage**: Encrypt immediately
3. **Usage**: Decrypt only when needed
4. **Rotation**: Implement if compromised
5. **Deletion**: Remove when user disconnects

### Token Validation

Always validate tokens before use:

```javascript
function validateAccessToken(token) {
  if (!token) {
    throw new Error('Access token is required');
  }
  if (typeof token !== 'string') {
    throw new Error('Access token must be a string');
  }
  if (!token.startsWith('access-') && !token.startsWith('access_sandbox-')) {
    throw new Error('Invalid access token format');
  }
  if (token.length < 20 || token.length > 1000) {
    throw new Error('Access token has invalid length');
  }
  return true;
}
```

---

## Webhook Security

### Signature Verification

Plaid signs all webhooks with HMAC-SHA256. Always verify:

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(rawBody, headers, verificationKey) {
  const signature = headers['plaid-verification'];

  if (!signature) {
    return false;
  }

  // Compute expected signature
  const hmac = crypto.createHmac('sha256', verificationKey);
  hmac.update(rawBody);
  const expectedSignature = hmac.digest('hex');

  // Constant-time comparison (prevents timing attacks)
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    );
  } catch (e) {
    return false;
  }
}
```

### Webhook Configuration

```bash
# In production, ALWAYS configure webhook verification
PLAID_WEBHOOK_URL=https://yourdomain.com/v1/plaid/webhook
PLAID_WEBHOOK_VERIFICATION_KEY=your-verification-key-from-plaid-dashboard
```

### Webhook Endpoint Security

1. **Use HTTPS**: Required in production
2. **Verify signatures**: Reject invalid signatures
3. **Rate limiting**: Prevent webhook flooding
4. **Idempotency**: Handle duplicate webhooks gracefully
5. **Async processing**: Don't block webhook response
6. **Logging**: Log webhook events for audit

---

## Input Validation

### Request Body Validation

All user inputs must be validated:

```javascript
// Validate required fields
function validateFields(requiredFields) {
  return (req, res, next) => {
    const missing = requiredFields.filter(field => !req.body[field]);
    if (missing.length > 0) {
      return res.status(400).json({
        error: 'Missing required fields',
        fields: missing
      });
    }
    next();
  };
}

// Validate field types and formats
function validateTransactionRequest(req, res, next) {
  const { start_date, end_date, count, offset } = req.body;

  // Date format: YYYY-MM-DD
  if (!/^\d{4}-\d{2}-\d{2}$/.test(start_date) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(end_date)) {
    return res.status(400).json({
      error: 'Invalid date format. Use YYYY-MM-DD'
    });
  }

  // Count range: 1-500
  if (count < 1 || count > 500) {
    return res.status(400).json({
      error: 'count must be between 1 and 500'
    });
  }

  // Offset: non-negative
  if (offset < 0) {
    return res.status(400).json({
      error: 'offset must be non-negative'
    });
  }

  next();
}
```

### Sanitization

Remove potentially malicious content:

```javascript
function sanitizeInput(req, res, next) {
  const sanitize = (obj) => {
    if (typeof obj === 'string') {
      // Remove script tags
      return obj.trim().replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    }
    if (typeof obj === 'object' && obj !== null) {
      for (const key in obj) {
        obj[key] = sanitize(obj[key]);
      }
    }
    return obj;
  };

  req.body = sanitize(req.body);
  next();
}
```

---

## Rate Limiting

### Implementation

```javascript
const rateLimit = require('express-rate-limit');

// Global rate limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per window
  message: 'Too many requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  // Skip successful requests to allow higher throughput
  skipSuccessfulRequests: false,
  // Custom key generator (e.g., by user ID instead of IP)
  keyGenerator: (req) => {
    return req.body.user_id || req.ip;
  }
});

app.use('/v1/', limiter);
```

### Plaid-Specific Limits

**Development Environment:**
- 100 requests per second
- No daily limit

**Production Environment:**
- Custom limits based on agreement with Plaid
- Typical: 2-4 requests per second
- Monitor usage in Plaid Dashboard

### Best Practices

1. **Cache aggressively**: Cache account info, don't refetch constantly
2. **Use webhooks**: Don't poll for updates
3. **Batch operations**: Fetch multiple accounts at once
4. **Implement backoff**: Exponential backoff on rate limit errors

---

## HTTPS and Transport Security

### Requirements

1. **Always use HTTPS** in production
2. **TLS 1.2 or higher** required
3. **Certificate validation** enabled
4. **No mixed content** (HTTP/HTTPS)

### iOS Certificate Pinning

Implement certificate pinning to prevent MITM attacks:

```swift
import Alamofire

class NetworkSecurityManager {
    static let shared = NetworkSecurityManager()

    private let session: Session = {
        let evaluators = [
            "api.yourdomain.com": PinnedCertificatesTrustEvaluator()
        ]
        let manager = ServerTrustManager(evaluators: evaluators)
        let configuration = URLSessionConfiguration.af.default
        return Session(
            configuration: configuration,
            serverTrustManager: manager
        )
    }()

    func request(_ url: String, method: HTTPMethod, parameters: Parameters) -> DataRequest {
        return session.request(url, method: method, parameters: parameters)
    }
}
```

---

## Logging and Monitoring

### What to Log

**DO Log:**
- Request timestamps
- Plaid request IDs
- Error types and codes
- Webhook events
- User actions (connect, disconnect)
- Rate limit violations

**DON'T Log:**
- Access tokens
- Public tokens
- Account numbers
- Transaction details with PII
- User passwords or credentials

### Example Logging

```javascript
// Good logging
logger.info('Plaid token exchange', {
  userId: user_id,
  itemId: result.itemId,
  requestId: result.requestId,
  timestamp: new Date().toISOString()
});

// Bad logging - exposes sensitive data
logger.info('Token exchange', {
  accessToken: result.accessToken, // NEVER LOG THIS!
  publicToken: public_token // NEVER LOG THIS!
});
```

### Monitoring Alerts

Set up alerts for:
- High error rates (>5% of requests)
- Rate limit exceeded events
- Webhook signature failures
- Item login required errors
- API connectivity issues

---

## Error Handling

### User-Facing Errors

Always use `displayMessage` for user-facing errors:

```javascript
try {
  const result = await plaidService.getAccounts(accessToken);
  return res.json(result);
} catch (error) {
  // Log technical details
  logger.error('Failed to fetch accounts', {
    error: error.message,
    type: error.type,
    code: error.code,
    requestId: error.requestId
  });

  // Return user-friendly message
  return res.status(400).json({
    error: 'Unable to fetch accounts',
    message: error.displayMessage || 'Please try reconnecting your bank account',
    code: error.code
  });
}
```

### Error Recovery

**For ITEM_LOGIN_REQUIRED:**
```javascript
async function handleLoginRequired(itemId, userId) {
  // 1. Notify user
  await notifyUser(userId, {
    title: 'Reconnect Your Bank',
    message: 'Your bank connection needs to be refreshed',
    action: 'reconnect'
  });

  // 2. Create update mode Link token
  const linkToken = await plaidService.createLinkToken({
    userId: userId,
    accessToken: getStoredAccessToken(itemId) // Update mode
  });

  // 3. Return link token to client
  return linkToken;
}
```

---

## Compliance and Privacy

### Data Retention

Define and implement data retention policy:

```javascript
// Example: Delete transactions older than 2 years
async function cleanupOldTransactions() {
  const twoYearsAgo = new Date();
  twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);

  await db.query(
    'DELETE FROM transactions WHERE date < ?',
    [twoYearsAgo]
  );
}

// Run monthly
cron.schedule('0 0 1 * *', cleanupOldTransactions);
```

### User Consent

Always obtain explicit consent before:
- Connecting bank accounts
- Accessing transaction data
- Sharing data with third parties
- Storing data long-term

### Privacy Requirements

1. **Privacy Policy**: Document data usage
2. **User Controls**: Allow users to disconnect/delete data
3. **Data Minimization**: Only collect necessary data
4. **Encryption**: Encrypt data at rest and in transit
5. **Access Controls**: Limit who can access financial data
6. **Audit Logs**: Track all access to sensitive data

---

## Incident Response

### Security Incident Checklist

If you suspect a security breach:

1. **Immediate Actions**
   - [ ] Identify affected users
   - [ ] Revoke compromised access tokens
   - [ ] Block suspicious IP addresses
   - [ ] Enable additional logging

2. **Investigation**
   - [ ] Review access logs
   - [ ] Check for unauthorized API calls
   - [ ] Identify root cause
   - [ ] Document timeline

3. **Remediation**
   - [ ] Patch vulnerabilities
   - [ ] Reset affected user credentials
   - [ ] Update security controls
   - [ ] Notify affected users

4. **Post-Incident**
   - [ ] Conduct post-mortem
   - [ ] Update security documentation
   - [ ] Implement preventive measures
   - [ ] Review with security team

### Contact Information

**Plaid Security Team:**
- Email: security@plaid.com
- For urgent issues: support@plaid.com

---

## Security Checklist

### Pre-Production

- [ ] Access tokens stored encrypted
- [ ] Webhook signature verification enabled
- [ ] HTTPS enforced for all endpoints
- [ ] Rate limiting configured
- [ ] Input validation on all endpoints
- [ ] Error messages sanitized
- [ ] Logging configured (no sensitive data)
- [ ] CORS configured appropriately
- [ ] Certificate pinning implemented (iOS)
- [ ] Security testing completed
- [ ] Privacy policy updated
- [ ] User consent flows implemented
- [ ] Incident response plan documented

### Production Monitoring

- [ ] Error rates monitored
- [ ] Rate limit violations tracked
- [ ] Webhook failures alerted
- [ ] Item errors monitored
- [ ] API latency tracked
- [ ] Security logs reviewed weekly
- [ ] Access patterns analyzed
- [ ] Compliance audits scheduled

### Regular Reviews

- [ ] Monthly: Review access logs
- [ ] Quarterly: Security audit
- [ ] Quarterly: Update dependencies
- [ ] Annually: Penetration testing
- [ ] Annually: Compliance review

---

## Additional Resources

**Plaid Security:**
- https://plaid.com/security/

**Plaid Compliance:**
- https://plaid.com/safety/

**OWASP Top 10:**
- https://owasp.org/www-project-top-ten/

**Node.js Security Best Practices:**
- https://nodejs.org/en/docs/guides/security/

---

## Support

For security concerns:
- Email: security@plaid.com
- Plaid Support: support@plaid.com
- Report vulnerabilities responsibly to Plaid security team

