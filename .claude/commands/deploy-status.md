Check the deployment status of all Mortgage Guardian services:

**Backend API (Railway)**:
1. Run `railway status` in backend-express/
2. Get deployment URL
3. Test health endpoint: GET /health
4. Check environment variables are set:
   - ANTHROPIC_API_KEY
   - PLAID_CLIENT_ID, PLAID_SECRET
   - SUPABASE_URL, SUPABASE_ANON_KEY
   - DATABASE_URL (auto-injected)
   - REDIS_URL (auto-injected)

**Frontend/Website (Netlify)**:
1. Check Netlify deployment status
2. Test URL: https://mortgage-guardian-app.netlify.app
3. Verify HTTP 200 response (not 500 error)
4. Check if it's the marketing site or Next.js app

**API Connectivity**:
1. Test Claude AI endpoint: POST /v1/ai/claude/analyze
2. Test Plaid endpoints: POST /v1/plaid/create_link_token
3. Test document processing: POST /v1/documents/process

**Summary Report**:
- Deployment URLs
- Health status (✅/❌)
- Any errors or warnings
- API response times
- Recommended actions

Display results in a clear table format.
