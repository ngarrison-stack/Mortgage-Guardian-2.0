# ENV-GUIDE.md

Unified environment variable reference for Mortgage Guardian 2.0.

> **Never commit actual secret values.** This document uses placeholder format only.

---

## 1. Quick Start

Minimum variables needed to run locally. Copy into the respective `.env` files.

### Backend (`backend-express/.env`)

```bash
NODE_ENV=development
PORT=3000
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-role-key
DOCUMENT_ENCRYPTION_KEY=<64-hex-chars>  # openssl rand -hex 32
```

### Frontend (`frontend/.env`)

```bash
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_your-key-here
CLERK_SECRET_KEY=sk_test_your-key-here
NEXT_PUBLIC_API_URL=http://localhost:3000
```

---

## 2. Backend Variables

| Variable | Required | Default | Description | Source / Dashboard | Rotation |
|---|---|---|---|---|---|
| `NODE_ENV` | No | `development` | Runtime environment (`development`, `production`, `test`, `staging`) | N/A | N/A |
| `PORT` | No | `3000` | HTTP listen port | N/A | N/A |
| `LOG_LEVEL` | No | `debug` (dev) / `info` (prod) | Winston log level | N/A | N/A |
| `SUPABASE_URL` | **Yes** | -- | Supabase project URL (must be `https://`) | [Supabase Dashboard](https://app.supabase.com/project/_/settings/api) | On project recreation |
| `SUPABASE_ANON_KEY` | **Yes** | -- | Supabase anonymous/public key | Supabase Dashboard > API | On key rotation in dashboard |
| `SUPABASE_SERVICE_KEY` | **Yes** | -- | Supabase service role key (admin) | Supabase Dashboard > API | On key rotation in dashboard |
| `DOCUMENT_ENCRYPTION_KEY` | **Yes** | -- | 64-char hex string for AES-256-GCM document encryption | Generate: `openssl rand -hex 32` | Annually or on compromise |
| `ANTHROPIC_API_KEY` | Feature | -- | Claude AI API key for document analysis | [Anthropic Console](https://console.anthropic.com/) | Annually or on compromise |
| `PLAID_CLIENT_ID` | Feature | -- | Plaid API client identifier | [Plaid Dashboard](https://dashboard.plaid.com/team/keys) | On regeneration |
| `PLAID_SECRET` | Feature | -- | Plaid API secret | Plaid Dashboard | On regeneration |
| `PLAID_ENV` | Feature | -- | Plaid environment: `sandbox`, `development`, `production` | N/A | N/A |
| `PLAID_WEBHOOK_URL` | No | -- | Public HTTPS endpoint for Plaid webhooks | Your domain | N/A |
| `PLAID_WEBHOOK_VERIFICATION_KEY` | Prod only | -- | Webhook signature verification key | Plaid Dashboard | On regeneration |
| `RATE_LIMIT_WINDOW_MS` | No | `900000` | Rate limit window in milliseconds (15 min) | N/A | N/A |
| `RATE_LIMIT_MAX_REQUESTS` | No | `100` | Max requests per IP per window | N/A | N/A |
| `ALLOWED_ORIGINS` | No | `*` | CORS allowed origins (comma-separated). Must not be `*` in production | N/A | N/A |
| `REDIS_HOST` | No | -- | Redis server hostname | Infrastructure | N/A |
| `REDIS_PORT` | No | -- | Redis server port | Infrastructure | N/A |
| `REDIS_PASSWORD` | No | -- | Redis authentication password | Infrastructure | On rotation |
| `JWT_SECRET` | No | -- | JWT signing secret | Generate: `openssl rand -base64 48` | Annually |
| `AWS_REGION` | No | -- | AWS region for cloud services | AWS Console | N/A |
| `USE_CLOUD_HSM` | No | -- | Enable AWS CloudHSM for key management | N/A | N/A |
| `VAULT_TOKEN` | No | -- | HashiCorp Vault access token | Vault admin | Per policy |
| `KMS_KEY_ID` | No | -- | AWS KMS encryption key ID | AWS Console > KMS | Per rotation policy |
| `KMS_SIGNING_KEY_ID` | No | -- | AWS KMS signing key ID | AWS Console > KMS | Per rotation policy |
| `ELASTICSEARCH_URL` | No | -- | Elasticsearch cluster URL | Infrastructure | N/A |
| `ELASTICSEARCH_USER` | No | -- | Elasticsearch username | Infrastructure | On rotation |
| `ELASTICSEARCH_PASSWORD` | No | -- | Elasticsearch password | Infrastructure | On rotation |
| `SENTRY_DSN` | Prod only | -- | Sentry DSN for error tracking and performance monitoring. App runs fine without it | [Sentry Dashboard](https://sentry.io) > Project Settings > Client Keys | On project recreation |

---

## 3. Frontend Variables

| Variable | Required | Default | Description | Source / Dashboard | Rotation |
|---|---|---|---|---|---|
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | **Yes** | -- | Clerk publishable key (must start with `pk_`) | [Clerk Dashboard](https://dashboard.clerk.com/) | On key regeneration |
| `CLERK_SECRET_KEY` | **Yes** | -- | Clerk secret key (must start with `sk_`). Server-side only | Clerk Dashboard | On key regeneration |
| `NEXT_PUBLIC_API_URL` | **Yes** | -- | Backend API base URL (must be valid URL) | Your deployment | N/A |
| `NEXT_PUBLIC_APP_URL` | No | `http://localhost:3001` | Frontend application URL | Your deployment | N/A |
| `NEXT_PUBLIC_APP_NAME` | No | `Mortgage Guardian` | Application display name | N/A | N/A |
| `NEXT_PUBLIC_ENABLE_PLAID` | No | `false` | Enable Plaid banking integration UI | N/A | N/A |
| `NEXT_PUBLIC_ENABLE_AI_ANALYSIS` | No | `false` | Enable AI document analysis UI | N/A | N/A |
| `NEXT_PUBLIC_SENTRY_DSN` | No | -- | Sentry DSN for frontend error tracking. App runs fine without it | [Sentry Dashboard](https://sentry.io) > Project Settings > Client Keys | On project recreation |

---

## 4. Environment Matrix

Which variables are needed per environment. Legend: **R** = Required, **O** = Optional, **--** = Not needed.

| Variable | Local Dev | CI | Staging | Production |
|---|---|---|---|---|
| **Backend** | | | | |
| `SUPABASE_URL` | R | R (test value) | R | R |
| `SUPABASE_ANON_KEY` | R | R (test value) | R | R |
| `SUPABASE_SERVICE_KEY` | R | R (test value) | R | R |
| `DOCUMENT_ENCRYPTION_KEY` | R | R (test value) | R | R |
| `ANTHROPIC_API_KEY` | O | -- | R | R |
| `PLAID_CLIENT_ID` | O | -- | R | R |
| `PLAID_SECRET` | O | -- | R | R |
| `PLAID_ENV` | O | -- | R (`development`) | R (`production`) |
| `PLAID_WEBHOOK_URL` | -- | -- | O | R |
| `PLAID_WEBHOOK_VERIFICATION_KEY` | -- | -- | O | R |
| `ALLOWED_ORIGINS` | O (`*`) | -- | R (explicit) | R (explicit) |
| `REDIS_*` | O | -- | R | R |
| `SENTRY_DSN` | -- | -- | O | O |
| **Frontend** | | | | |
| `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` | R | R (synthetic `pk_test_*`) | R | R |
| `CLERK_SECRET_KEY` | R | R (synthetic `sk_test_*`) | R | R |
| `NEXT_PUBLIC_API_URL` | R | R | R | R |
| `NEXT_PUBLIC_APP_URL` | O | O | R | R |
| `NEXT_PUBLIC_ENABLE_PLAID` | O | O | R | R |
| `NEXT_PUBLIC_ENABLE_AI_ANALYSIS` | O | O | R | R |
| `NEXT_PUBLIC_SENTRY_DSN` | -- | -- | O | O |

> **CI note (Phase 23-02 decision):** Clerk keys in CI use synthetic format-valid values (`pk_test_ci_placeholder`, `sk_test_ci_placeholder`). They pass format validation but are not real keys.

---

## 5. Secrets Classification

### Critical (immediate rotation on compromise)

- `SUPABASE_SERVICE_KEY` -- full database admin access
- `DOCUMENT_ENCRYPTION_KEY` -- AES-256 key protecting all stored documents
- `CLERK_SECRET_KEY` -- server-side authentication secret
- `VAULT_TOKEN` -- HashiCorp Vault access

### High (rotate within 24 hours on compromise)

- `ANTHROPIC_API_KEY` -- AI API access with billing implications
- `PLAID_SECRET` -- banking data access
- `PLAID_WEBHOOK_VERIFICATION_KEY` -- webhook integrity
- `JWT_SECRET` -- token signing
- `KMS_KEY_ID` / `KMS_SIGNING_KEY_ID` -- cloud encryption keys

### Medium (rotate within 72 hours)

- `SUPABASE_ANON_KEY` -- public-facing but scoped by RLS
- `PLAID_CLIENT_ID` -- identifier, not a secret per se but paired with secret
- `REDIS_PASSWORD` -- internal infrastructure
- `ELASTICSEARCH_PASSWORD` -- internal infrastructure

### Low (informational, no direct security impact)

- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` -- designed to be public
- `NEXT_PUBLIC_API_URL` / `NEXT_PUBLIC_APP_URL` -- public URLs
- `NODE_ENV`, `PORT`, `LOG_LEVEL` -- configuration
- Feature flags (`NEXT_PUBLIC_ENABLE_PLAID`, `NEXT_PUBLIC_ENABLE_AI_ANALYSIS`)

---

## 6. Rotation Strategy

| Classification | Rotation Cadence | Procedure |
|---|---|---|
| **Critical** | Every 90 days or on compromise | 1. Generate new value. 2. Update in all deployment platforms (see section 7). 3. Restart all affected services. 4. Verify health checks pass. 5. Revoke old value. |
| **High** | Every 180 days or on compromise | 1. Generate new value in provider dashboard. 2. Update deployment platform secrets. 3. Deploy. 4. Verify integration health. |
| **Medium** | Annually or on compromise | 1. Rotate in provider dashboard. 2. Update secrets. 3. Deploy. |
| **Low** | No scheduled rotation | Update as needed during infrastructure changes. |

### Key-specific generation commands

```bash
# Document encryption key (64 hex chars = 256-bit AES key)
openssl rand -hex 32

# JWT secret (base64 encoded)
openssl rand -base64 48

# General-purpose secret
openssl rand -base64 32
```

---

## 7. Deployment Platform Reference

### Railway (Backend)

1. Open [Railway Dashboard](https://railway.app/dashboard)
2. Select the Mortgage Guardian backend service
3. Go to **Variables** tab
4. Add/update variables from the Backend table (section 2)
5. Railway auto-restarts on variable change

### Vercel (Frontend)

1. Open [Vercel Dashboard](https://vercel.com/dashboard)
2. Select the Mortgage Guardian frontend project
3. Go to **Settings > Environment Variables**
4. Add variables from the Frontend table (section 3)
5. Set scope: Production, Preview, Development as needed
6. Redeploy to pick up changes

### Supabase

1. Open [Supabase Dashboard](https://app.supabase.com/)
2. Select project > **Settings > API**
3. Copy `URL`, `anon key`, and `service_role key`
4. These values are set in Supabase and consumed by the backend
5. To rotate: use **Settings > API > Regenerate** (causes downtime until all consumers are updated)

### Clerk

1. Open [Clerk Dashboard](https://dashboard.clerk.com/)
2. Select application > **API Keys**
3. Copy Publishable Key (`pk_*`) and Secret Key (`sk_*`)
4. Update in both Vercel (frontend) and any server that validates tokens

### Plaid

1. Open [Plaid Dashboard](https://dashboard.plaid.com/team/keys)
2. Copy Client ID and Secret for the target environment
3. Update in Railway (backend)
4. For production: also configure webhook URL and verification key

### GitHub Actions (CI)

1. Go to repo **Settings > Secrets and variables > Actions**
2. Add repository secrets for CI-required variables
3. Use synthetic Clerk keys for CI (see Environment Matrix, section 4)

---

*Last updated: 2026-04-04 (Phase 27-02)*
