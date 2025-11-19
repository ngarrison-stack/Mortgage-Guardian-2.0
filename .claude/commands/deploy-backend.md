Deploy the Mortgage Guardian backend to Railway:

**Pre-deployment Checks**:
1. Verify backend code is ready:
   - All dependencies in package.json
   - server.js exists and is valid
   - Routes are properly configured
   - No console.log or debug code in production paths

2. Validate environment variables:
   - All required variables documented
   - No hardcoded secrets in code
   - .env.example is up to date

3. Test locally first:
   - Run `npm start` to test production mode
   - Verify health endpoint responds
   - Check for any startup errors

**Railway Deployment**:
1. Change to backend directory: `cd backend-express`
2. Check Railway connection: `railway status`
3. Verify Railway environment variables are set:
   - ANTHROPIC_API_KEY
   - PLAID_CLIENT_ID, PLAID_SECRET
   - SUPABASE credentials
   - DATABASE_URL (auto-injected)
   - REDIS_URL (auto-injected)

4. Deploy to Railway: `railway up`
5. Monitor deployment logs for errors

**Post-deployment Verification**:
1. Get deployment URL from Railway
2. Test health endpoint: `curl https://[url]/health`
3. Test API endpoints:
   - POST /v1/ai/claude/analyze
   - POST /v1/plaid/create_link_token
   - POST /v1/documents/process

4. Check Railway logs: `railway logs`

**Custom Domain Configuration** (if needed):
1. Configure DNS CNAME record:
   - Name: api
   - Value: [railway-url].up.railway.app
   - TTL: 600

2. Add custom domain in Railway dashboard
3. Wait for SSL certificate provisioning
4. Test custom domain: https://api.mortgageguardian.org

**Rollback Plan**:
If deployment fails, provide steps to rollback to previous version.

**Output**:
- Deployment status
- URLs (Railway URL and custom domain if configured)
- Health check results
- Any errors or warnings
- Performance metrics
