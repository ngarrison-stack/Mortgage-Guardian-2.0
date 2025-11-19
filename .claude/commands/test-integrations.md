Test all third-party API integrations for Mortgage Guardian:

**1. Anthropic Claude AI**:
- Verify ANTHROPIC_API_KEY is set
- Test API connectivity with a simple request
- Check API key validity and rate limits
- Test document analysis endpoint

**2. Plaid Banking Integration**:
- Verify PLAID_CLIENT_ID and PLAID_SECRET are set
- Test environment (sandbox/development/production)
- Create a link token (validates credentials)
- Test webhook configuration if set
- Verify PLAID_WEBHOOK_VERIFICATION_KEY if using webhooks

**3. Supabase Database**:
- Verify SUPABASE_URL and SUPABASE_ANON_KEY
- Test database connection
- Verify SUPABASE_SERVICE_KEY for admin operations
- Check authentication configuration

**4. Clerk Authentication** (if using Next.js frontend):
- Verify CLERK_SECRET_KEY and NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
- Test authentication endpoints
- Check JWT configuration

**5. Database Services** (Docker):
- PostgreSQL: Test connection on port 5432
- Redis: Test connection on port 6379
- MinIO: Test S3-compatible storage on ports 9000/9001

**Output Format**:
For each integration, report:
- ✅ Configured and working
- ⚠️ Configured but not tested
- ❌ Missing or failing
- 🔧 Configuration needed

Include specific error messages and troubleshooting steps for any failures.
