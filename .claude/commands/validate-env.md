Validate environment configuration for all Mortgage Guardian services:

**Backend Environment (backend-express/.env)**:

Required variables:
- NODE_ENV (development/production)
- PORT (default: 3000)
- ANTHROPIC_API_KEY (starts with sk-ant-)
- PLAID_CLIENT_ID
- PLAID_SECRET
- PLAID_ENV (sandbox/development/production)
- SUPABASE_URL (https://[project].supabase.co)
- SUPABASE_ANON_KEY
- SUPABASE_SERVICE_KEY
- RATE_LIMIT_WINDOW_MS (default: 900000)
- RATE_LIMIT_MAX_REQUESTS (default: 100)
- ALLOWED_ORIGINS (comma-separated or *)

Optional but recommended:
- PLAID_WEBHOOK_URL
- PLAID_WEBHOOK_VERIFICATION_KEY
- JWT_SECRET
- ENCRYPTION_KEY

**Frontend Environment (frontend/.env.local)**:

Required variables:
- NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY (starts with pk_)
- CLERK_SECRET_KEY (starts with sk_)
- NEXT_PUBLIC_API_URL (backend URL)

Optional:
- NEXT_PUBLIC_ENABLE_PLAID (true/false)
- NEXT_PUBLIC_ENABLE_AI_ANALYSIS (true/false)
- NEXT_PUBLIC_DEBUG_MODE (true/false)

**Validation Steps**:
1. Check if .env files exist
2. Parse and verify each required variable
3. Validate format (URLs, API key prefixes)
4. Check for placeholder values (e.g., "your-api-key-here")
5. Verify no sensitive data in .env.example files

**Output**:
- List of missing variables with instructions on how to obtain them
- List of invalid formats with correction guidance
- Security warnings (if secrets in wrong files)
- Links to get API keys:
  - Anthropic: https://console.anthropic.com/
  - Plaid: https://dashboard.plaid.com/team/keys
  - Supabase: https://app.supabase.com/project/_/settings/api
  - Clerk: https://dashboard.clerk.com/last-active?path=api-keys
