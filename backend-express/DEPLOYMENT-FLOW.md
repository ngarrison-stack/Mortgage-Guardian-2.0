# Railway Deployment Flow

Visual guide to the automated deployment process.

## Quick Start Command

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
./DEPLOY-NOW.sh
```

## Deployment Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT PROCESS                           │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   STEP 1     │  Setup Environment
│ setup-env.sh │  - Generate JWT_SECRET (256-bit)
└──────┬───────┘  - Generate ENCRYPTION_KEY (256-bit)
       │          - Generate REFRESH_TOKEN_SECRET
       │          - Create .env.railway.local
       │          - Create export-env.sh
       ↓          - Create set-railway-vars.sh
┌──────────────┐
│   STEP 2     │  Configure API Keys
│ User Action  │  - Add ANTHROPIC_API_KEY
└──────┬───────┘  - Add PLAID credentials (optional)
       │          - Review environment variables
       │
       ↓
┌──────────────┐
│   STEP 3     │  Authenticate with Railway
│ Railway CLI  │  - Export RAILWAY_TOKEN
└──────┬───────┘  - Verify with: railway whoami
       │
       │
       ↓
┌──────────────┐
│   STEP 4     │  Deploy to Railway
│deploy-railway│  ┌─────────────────────────────────┐
│    .sh       │──┤ 1. Pre-flight Checks           │
└──────┬───────┘  │    - Verify Railway CLI         │
       │          │    - Check required files       │
       │          │    - Validate dependencies      │
       │          ├─────────────────────────────────┤
       │          │ 2. Railway Authentication       │
       │          │    - Verify token               │
       │          │    - Check user access          │
       │          ├─────────────────────────────────┤
       │          │ 3. Project Setup                │
       │          │    - Create/link project        │
       │          │    - Configure region           │
       │          ├─────────────────────────────────┤
       │          │ 4. Add Databases                │
       │          │    - Provision PostgreSQL       │
       │          │    - Provision Redis            │
       │          │    - Configure connections      │
       │          ├─────────────────────────────────┤
       │          │ 5. Environment Variables        │
       │          │    - Set production vars        │
       │          │    - Set secure keys            │
       │          │    - Set API credentials        │
       │          ├─────────────────────────────────┤
       │          │ 6. Deploy Application           │
       │          │    - Upload code                │
       │          │    - Build with Nixpacks        │
       │          │    - Start service              │
       │          ├─────────────────────────────────┤
       │          │ 7. Health Checks                │
       │          │    - Wait for startup           │
       │          │    - Test /health endpoint      │
       │          │    - Verify service running     │
       │          ├─────────────────────────────────┤
       │          │ 8. Generate Domain              │
       │          │    - Create Railway domain      │
       │          │    - Configure HTTPS            │
       │          │    - Return deployment URL      │
       │          └─────────────────────────────────┘
       │
       ↓
┌──────────────┐
│   STEP 5     │  Test Deployment
│test-deploy   │  ┌─────────────────────────────────┐
│    .sh       │──┤ 1. Health Endpoint              │
└──────┬───────┘  │    GET /health                  │
       │          │    Expected: 200 OK             │
       │          ├─────────────────────────────────┤
       │          │ 2. CORS Headers                 │
       │          │    Check access-control headers │
       │          │    Verify allowed origins       │
       │          ├─────────────────────────────────┤
       │          │ 3. Claude AI Endpoint           │
       │          │    POST /v1/ai/claude/analyze   │
       │          │    Verify connectivity          │
       │          ├─────────────────────────────────┤
       │          │ 4. Plaid Endpoint               │
       │          │    POST /v1/plaid/link_token    │
       │          │    Check integration            │
       │          ├─────────────────────────────────┤
       │          │ 5. 404 Handler                  │
       │          │    GET /nonexistent             │
       │          │    Expected: 404                │
       │          └─────────────────────────────────┘
       │
       ↓
┌──────────────┐
│   SUCCESS    │  Deployment Complete!
│   🎉         │  - URL: https://your-app.up.railway.app
└──────────────┘  - PostgreSQL: Connected
                  - Redis: Connected
                  - HTTPS: Enabled
                  - Health: Passing
```

## Services Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    RAILWAY INFRASTRUCTURE                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────┐
│   Internet/Users    │
│  (Your Frontend)    │
└──────────┬──────────┘
           │
           │ HTTPS (Port 443)
           │ SSL/TLS Auto-provisioned
           │
           ↓
┌─────────────────────┐
│  Railway Platform   │
│  Load Balancer      │
└──────────┬──────────┘
           │
           │ Forwards to
           │
           ↓
┌──────────────────────────────────────────┐
│        Backend API Service               │
│  ┌────────────────────────────────────┐  │
│  │  Node.js 20 + Express              │  │
│  │  Port: 3000                        │  │
│  │  Health Check: /health             │  │
│  │  Auto-restart: Enabled             │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Environment Variables:                  │
│  - NODE_ENV=production                  │
│  - JWT_SECRET=***                       │
│  - ENCRYPTION_KEY=***                   │
│  - ANTHROPIC_API_KEY=***                │
│  - DATABASE_URL=*** (auto-injected)     │
│  - REDIS_URL=*** (auto-injected)        │
│  - ALLOWED_ORIGINS=mortgageguardian.org │
└──────────┬───────────────┬───────────────┘
           │               │
           │               │
┌──────────↓─────────┐     │
│   PostgreSQL DB    │     │
│  ┌──────────────┐  │     │
│  │ Transactions │  │     │
│  │ User Data    │  │     │
│  │ Documents    │  │     │
│  │ Audit Logs   │  │     │
│  └──────────────┘  │     │
│                    │     │
│  Auto-backups      │     │
│  SSL/TLS enabled   │     │
└────────────────────┘     │
                           │
                  ┌────────↓─────────┐
                  │    Redis Cache   │
                  │  ┌────────────┐  │
                  │  │ Sessions   │  │
                  │  │ Rate Limit │  │
                  │  │ Job Queue  │  │
                  │  └────────────┘  │
                  │                  │
                  │  Persistent      │
                  │  TLS enabled     │
                  └──────────────────┘
```

## API Endpoints Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     API ENDPOINT ROUTING                        │
└─────────────────────────────────────────────────────────────────┘

Frontend Request
       │
       ↓
[HTTPS] https://your-app.up.railway.app/endpoint
       │
       ↓
┌──────────────┐
│ Middleware   │
│   Pipeline   │
├──────────────┤
│ 1. CORS      │──→ Check Origin: mortgageguardian.org ✓
├──────────────┤
│ 2. Helmet    │──→ Security Headers Applied
├──────────────┤
│ 3. Rate      │──→ Check Redis: Request Count ✓
│   Limiter    │    (100 req/15min)
├──────────────┤
│ 4. Body      │──→ Parse JSON (50MB limit)
│   Parser     │
└──────┬───────┘
       │
       ↓
┌──────────────────────────────────────────┐
│          Route Handler                   │
├──────────────────────────────────────────┤
│ GET  /health                             │──→ Health Check
│                                          │    ✓ Status, DB, Redis
│                                          │
│ POST /v1/ai/claude/analyze               │──→ Claude AI
│                                          │    ✓ Document Analysis
│                                          │    ✓ Error Detection
│                                          │
│ POST /v1/plaid/link_token                │──→ Plaid Integration
│ POST /v1/plaid/exchange_token            │    ✓ Bank Connection
│ POST /v1/plaid/accounts                  │    ✓ Account Data
│ POST /v1/plaid/transactions              │    ✓ Transaction History
│                                          │
│ POST /v1/documents/upload                │──→ Document Management
│ GET  /v1/documents                       │    ✓ Upload/Store
│ GET  /v1/documents/:id                   │    ✓ Retrieve
│ DELETE /v1/documents/:id                 │    ✓ Delete
└──────────────────────────────────────────┘
       │
       ↓
┌──────────────┐
│   Response   │
│   Pipeline   │
├──────────────┤
│ 1. JSON      │──→ Serialize Response
│   Format     │
├──────────────┤
│ 2. Error     │──→ Handle Errors
│   Handler    │
├──────────────┤
│ 3. CORS      │──→ Add CORS Headers
│   Headers    │
└──────┬───────┘
       │
       ↓
[HTTPS] Response to Frontend
```

## Environment Variables Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              ENVIRONMENT VARIABLE MANAGEMENT                    │
└─────────────────────────────────────────────────────────────────┘

Local Setup                Railway Platform
─────────────             ──────────────────

setup-env.sh  ──→  .env.railway.local
                   │
                   │ Contains:
                   │ - JWT_SECRET
                   │ - ENCRYPTION_KEY
                   │ - REFRESH_TOKEN_SECRET
                   │ - ANTHROPIC_API_KEY
                   │ - PLAID_CLIENT_ID
                   │ - PLAID_SECRET
                   │
                   ↓
              export-env.sh
                   │
                   │ Exports to shell
                   │
                   ↓
              deploy-railway.sh
                   │
                   │ Sets in Railway:
                   │
                   ├──→ railway variables set NODE_ENV=production
                   ├──→ railway variables set JWT_SECRET=***
                   ├──→ railway variables set ENCRYPTION_KEY=***
                   ├──→ railway variables set ANTHROPIC_API_KEY=***
                   ├──→ railway variables set ALLOWED_ORIGINS=***
                   │
                   ↓
              ┌─────────────────────────┐
              │   Railway Platform      │
              │   Encrypted Storage     │
              ├─────────────────────────┤
              │ USER VARIABLES:         │
              │ - NODE_ENV              │
              │ - JWT_SECRET            │
              │ - ENCRYPTION_KEY        │
              │ - ANTHROPIC_API_KEY     │
              │ - ALLOWED_ORIGINS       │
              │                         │
              │ AUTO-INJECTED:          │
              │ - DATABASE_URL          │
              │ - REDIS_URL             │
              │ - PORT                  │
              └─────────┬───────────────┘
                        │
                        │ Injected at runtime
                        │
                        ↓
              ┌─────────────────────────┐
              │   Backend Service       │
              │   process.env.*         │
              └─────────────────────────┘
```

## Testing Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT TESTING                           │
└─────────────────────────────────────────────────────────────────┘

test-deployment.sh
       │
       ├──→ Test 1: Health Check
       │    │
       │    ├─→ GET https://your-app.up.railway.app/health
       │    ├─→ Expected: HTTP 200
       │    ├─→ Response: { status: "healthy", ... }
       │    └─→ ✓ PASS
       │
       ├──→ Test 2: CORS Headers
       │    │
       │    ├─→ OPTIONS /v1/ai/claude/analyze
       │    ├─→ Origin: mortgageguardian.org
       │    ├─→ Check: access-control-allow-origin
       │    └─→ ✓ PASS
       │
       ├──→ Test 3: Claude AI Endpoint
       │    │
       │    ├─→ POST /v1/ai/claude/analyze
       │    ├─→ Body: { documentText: "test", ... }
       │    ├─→ Expected: HTTP 200 or 401 (if no API key)
       │    └─→ ✓ PASS (endpoint accessible)
       │
       ├──→ Test 4: Plaid Endpoint
       │    │
       │    ├─→ POST /v1/plaid/link_token
       │    ├─→ Body: { userId: "test-user" }
       │    ├─→ Expected: HTTP 200 or 400/500
       │    └─→ ✓ PASS (endpoint accessible)
       │
       └──→ Test 5: 404 Handler
            │
            ├─→ GET /nonexistent
            ├─→ Expected: HTTP 404
            ├─→ Response: { error: "Not Found", ... }
            └─→ ✓ PASS

All Tests: ✓ PASSED
Deployment URL: https://your-app.up.railway.app
Status: READY FOR PRODUCTION
```

## Deployment Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│                   TYPICAL DEPLOYMENT TIMELINE                   │
└─────────────────────────────────────────────────────────────────┘

00:00  │ Start: ./DEPLOY-NOW.sh
       │
00:30  │ ✓ Prerequisites checked
       │ ✓ Environment setup verified
       │
01:00  │ ✓ Railway token validated
       │ ✓ API keys configured
       │
01:30  │ → Deploying to Railway...
       │
02:00  │ → Building with Nixpacks...
       │   - Installing dependencies
       │   - Compiling application
       │
03:00  │ → Starting services...
       │   - Backend API starting
       │   - PostgreSQL connecting
       │   - Redis connecting
       │
03:30  │ → Running health checks...
       │
04:00  │ ✓ Health check passed
       │ ✓ Service running
       │
04:30  │ → Running deployment tests...
       │   - Testing endpoints
       │   - Verifying CORS
       │   - Checking integrations
       │
05:00  │ ✓ All tests passed
       │ ✓ DEPLOYMENT COMPLETE
       │
       │ URL: https://your-app.up.railway.app
       │ Status: LIVE
       │ Health: PASSING

Total Time: ~5 minutes
```

## File Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                    FILE DEPENDENCY GRAPH                        │
└─────────────────────────────────────────────────────────────────┘

DEPLOY-NOW.sh (Interactive Wizard)
    │
    ├──→ setup-env.sh
    │    │
    │    └──→ Generates:
    │         - .env.railway.local
    │         - export-env.sh
    │         - set-railway-vars.sh
    │
    ├──→ deploy-railway.sh
    │    │
    │    ├──→ Requires:
    │    │    - RAILWAY_TOKEN
    │    │    - export-env.sh
    │    │
    │    └──→ Uses:
    │         - railway.toml
    │         - railway.json
    │         - package.json
    │         - server.js
    │
    └──→ test-deployment.sh
         │
         └──→ Tests deployment URL

Documentation:
    ├── RAILWAY-DEPLOYMENT.md (Complete guide)
    ├── QUICK-START.md (5-minute guide)
    ├── README-DEPLOYMENT.md (Quick reference)
    └── DEPLOYMENT-FLOW.md (This file)

Configuration:
    ├── railway.toml (Railway config)
    ├── railway.json (Build config)
    ├── package.json (Dependencies)
    ├── .gitignore (Security)
    └── .env.railway.local (Variables)
```

## Security Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY LAYERS                            │
└─────────────────────────────────────────────────────────────────┘

Request Flow with Security:

Internet
   │
   ↓
[Layer 1] Railway Network Security
   │      - DDoS Protection
   │      - Network Firewall
   │      - IP Filtering
   ↓
[Layer 2] HTTPS/SSL (Automatic)
   │      - TLS 1.3
   │      - Auto-renewing certificates
   │      - Perfect Forward Secrecy
   ↓
[Layer 3] Application Security (Helmet)
   │      - Content Security Policy
   │      - XSS Protection
   │      - Frame Options
   │      - HSTS
   ↓
[Layer 4] CORS
   │      - Origin: mortgageguardian.org ✓
   │      - Methods: POST, GET, PUT, DELETE
   │      - Credentials: true
   ↓
[Layer 5] Rate Limiting (Redis)
   │      - 100 requests / 15 minutes
   │      - Per-IP tracking
   │      - Exponential backoff
   ↓
[Layer 6] Authentication (JWT)
   │      - Token validation
   │      - Signature verification
   │      - Expiry checking
   ↓
[Layer 7] Authorization
   │      - Role-based access
   │      - Resource permissions
   │      - API key validation
   ↓
[Layer 8] Data Encryption
   │      - AES-256-GCM
   │      - Field-level encryption
   │      - At-rest encryption
   ↓
Application Logic
```

## Summary

This visual guide shows the complete deployment flow from setup to production. The entire process is automated and takes approximately 5 minutes.

**To start deployment:**

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
./DEPLOY-NOW.sh
```

Follow the interactive wizard to deploy your backend to Railway!
