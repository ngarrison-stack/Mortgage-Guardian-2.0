# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mortgage Guardian 2.0 is a multi-platform mortgage servicing audit platform combining an iOS mobile app with a Node.js/Express backend. The system uses AI-powered document analysis (Claude AI) to detect errors in mortgage loan servicing, cross-references with bank data via Plaid, and generates RESPA-compliant dispute letters.

## Architecture

### System Components

1. **Backend API** (`backend-express/`): Node.js/Express server deployable to Vercel, Railway, or other platforms
   - Claude AI integration for document analysis
   - Plaid integration for bank account verification
   - Supabase for database and authentication
   - Redis for caching and rate limiting

2. **Frontend** (`frontend/`): Next.js 15 with Turbopack
   - Clerk authentication
   - React 19 with TypeScript
   - Tailwind CSS v4

3. **iOS App** (referenced in README): Swift/SwiftUI application
   - Document OCR using Vision Framework
   - Bank integration via Plaid SDK
   - RESPA-compliant letter generation

## Development Commands

### Backend Development (`backend-express/`)
```bash
cd backend-express
npm install              # Install dependencies
npm run dev              # Start development server with nodemon (port 3000)
npm start                # Start production server
npm test                 # Run tests (placeholder)
```

### Frontend Development (`frontend/`)
```bash
cd frontend
npm install              # Install dependencies
npm run dev              # Start Next.js dev server with Turbopack
npm run build            # Build production bundle with Turbopack
npm run start            # Start production server
npm run lint             # Run ESLint
```

### Docker Development (Root Level)
```bash
# Start all services (PostgreSQL, Redis, Mailhog, MinIO)
docker-compose up -d

# Stop all services
docker-compose down

# Production deployment
docker-compose -f docker-compose.production.yml up -d
```

### Environment Setup
```bash
# Backend configuration
cp backend-express/.env.example backend-express/.env
# Configure: ANTHROPIC_API_KEY, PLAID_CLIENT_ID, PLAID_SECRET, SUPABASE_URL, etc.

# Frontend configuration
cp frontend/.env.example frontend/.env
# Configure Clerk authentication keys
```

## Key API Endpoints

### Backend Express API (`backend-express/`)
- **Health Check**: `GET /health`
- **Claude Analysis**: `POST /v1/ai/claude/analyze`
- **Plaid Operations**:
  - `POST /v1/plaid/create_link_token`
  - `POST /v1/plaid/exchange_public_token`
  - `GET /v1/plaid/accounts/:accessToken`
  - `GET /v1/plaid/transactions/:accessToken`
- **Document Processing**: `POST /v1/documents/process`

## Service Configuration

### Required API Keys
1. **Anthropic Claude**: `ANTHROPIC_API_KEY` - Document analysis
2. **Plaid**: `PLAID_CLIENT_ID`, `PLAID_SECRET` - Bank integration
3. **Supabase**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY` - Database/Auth
4. **Clerk** (Frontend): Authentication service

### Database Services
- **PostgreSQL**: Primary database (port 5432)
- **Redis**: Caching and rate limiting (port 6379)
- **MinIO**: S3-compatible document storage (ports 9000/9001)
- **Supabase**: Cloud database alternative

## Deployment

### Railway Deployment
```bash
cd backend-express
railway login
railway init
railway up
# Configure environment variables in Railway dashboard
```

### Vercel Deployment
```bash
# Backend deployment handled via vercel.json configuration
vercel --prod

# Frontend deployment
cd frontend
vercel --prod
```

### Docker Production
```bash
docker-compose -f docker-compose.production.yml up -d
```

## Core Services Implementation

### Document Processing Flow
1. **Upload**: Document received via `/v1/documents/process`
2. **OCR**: Text extraction using Vision Framework (iOS) or server-side OCR
3. **Analysis**: Claude AI analyzes extracted text for servicing errors
4. **Verification**: Cross-reference with Plaid bank transaction data
5. **Report**: Generate findings with confidence scores

### Security Features
- **Rate Limiting**: Configured via `RATE_LIMIT_WINDOW_MS` and `RATE_LIMIT_MAX_REQUESTS`
- **CORS**: Configurable origins via `ALLOWED_ORIGINS`
- **Authentication**: JWT tokens with Supabase/Clerk
- **Data Encryption**: AES-GCM for sensitive data
- **API Security**: Helmet.js for security headers

### Service Architecture Patterns
- **Modular Services**: Separate service files for Claude, Plaid, documents
- **Error Handling**: Centralized error handling with proper HTTP status codes
- **Async Operations**: All I/O operations use async/await
- **Caching Strategy**: Redis for API response caching
- **Rate Limiting**: Per-IP rate limiting with Redis backend

## Testing Strategy

### Backend Testing
```bash
cd backend-express
npm test                 # Run test suite
```

### Frontend Testing
```bash
cd frontend
npm test                 # Run React component tests
```

## Important Implementation Notes

### Plaid Integration
- Supports sandbox, development, and production environments
- Webhook support for real-time transaction updates
- Access token management for persistent bank connections

### Claude AI Analysis
- Specialized prompts for mortgage document analysis
- Confidence scoring for detected issues
- Context-aware processing based on document type

### Document Storage
- MinIO for local S3-compatible storage
- Supabase storage for cloud deployment
- Secure document lifecycle management

### Performance Targets
- Document processing: < 10 seconds
- AI analysis: < 30 seconds per document
- Plaid sync: < 5 seconds
- Memory: < 100MB peak usage
- Test coverage: 90% minimum, 95% for critical paths
