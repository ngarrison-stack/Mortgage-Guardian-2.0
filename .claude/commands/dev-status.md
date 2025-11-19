Check the complete status of the Mortgage Guardian development environment including:

1. **Backend API** (backend-express/):
   - Dependencies installed (node_modules exists)
   - Environment file configured (.env exists and has required keys)
   - Server running status (port 3000)
   - Required API keys present: ANTHROPIC_API_KEY, PLAID_CLIENT_ID, PLAID_SECRET, SUPABASE_URL

2. **Frontend** (frontend/):
   - Dependencies installed (node_modules exists)
   - Environment file configured (.env.local exists)
   - Dev server running status (port 3001)
   - Required keys present: CLERK_SECRET_KEY, NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY

3. **Website** (website/):
   - Static files present
   - Netlify deployment status

4. **Docker Services**:
   - Docker daemon running
   - PostgreSQL (port 5432)
   - Redis (port 6379)
   - MinIO (ports 9000/9001)

5. **Deployments**:
   - Railway backend status and URL
   - Netlify website status and URL
   - Health endpoint responses

Provide a clear summary with ✅ for working items and ❌ for issues, with actionable next steps.
