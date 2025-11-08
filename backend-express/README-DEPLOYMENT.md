# Railway Deployment - Complete Setup

## Overview

Your Mortgage Guardian backend is now fully configured for automated deployment to Railway using token-based authentication. This document provides a quick reference to all the deployment resources.

## Files Created

### Deployment Scripts

| File | Purpose | Status |
|------|---------|--------|
| `deploy-railway.sh` | Main automated deployment script | ✓ Ready |
| `setup-env.sh` | Generate secure keys and environment | ✓ Executed |
| `test-deployment.sh` | Test deployed endpoints | ✓ Ready |
| `set-railway-vars.sh` | Set Railway environment variables | ✓ Ready |
| `DEPLOY-NOW.sh` | Interactive deployment wizard | ✓ Ready |

### Configuration Files (Generated)

| File | Purpose | Status |
|------|---------|--------|
| `.env.railway.local` | Production environment variables | ✓ Generated |
| `export-env.sh` | Export script for deployment | ✓ Generated |

### Documentation

| File | Purpose |
|------|---------|
| `RAILWAY-DEPLOYMENT.md` | Complete deployment guide (5000+ words) |
| `QUICK-START.md` | 5-minute quick start guide |
| `README-DEPLOYMENT.md` | This file - quick reference |

## Three Ways to Deploy

### Option 1: Interactive Wizard (Recommended for First Time)

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
./DEPLOY-NOW.sh
```

The wizard will:
- Check prerequisites
- Prompt for Railway token
- Configure API keys
- Deploy to Railway
- Run tests
- Show you the deployment URL

### Option 2: Quick Automated Deployment

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express

# 1. Export Railway token
export RAILWAY_TOKEN='your-token-from-railway'

# 2. Add API keys to .env.railway.local
nano .env.railway.local
# Update ANTHROPIC_API_KEY

# 3. Deploy
source export-env.sh
./deploy-railway.sh
```

### Option 3: Manual Step-by-Step

```bash
# 1. Authenticate
export RAILWAY_TOKEN='your-token'
railway whoami

# 2. Create project
railway init --name mortgage-guardian-backend

# 3. Add databases
railway add --database postgres
railway add --database redis

# 4. Set variables
./set-railway-vars.sh

# 5. Deploy
railway up

# 6. Test
./test-deployment.sh
```

## What You Need

### Required

1. **Railway Token**
   - Get from: https://railway.app/account/tokens
   - Export: `export RAILWAY_TOKEN='your-token'`

2. **Anthropic API Key**
   - Get from: https://console.anthropic.com
   - Add to `.env.railway.local`

### Optional

3. **Plaid Credentials**
   - Get from: https://dashboard.plaid.com
   - Add to `.env.railway.local` (optional)

## Generated Secure Keys

The following were automatically generated:

- **JWT_SECRET**: 64-character hex string (256-bit)
- **ENCRYPTION_KEY**: 64-character hex string (256-bit)
- **REFRESH_TOKEN_SECRET**: 64-character hex string (256-bit)

These are stored in `.env.railway.local` (not committed to git).

## Quick Commands Reference

```bash
# Deploy
./DEPLOY-NOW.sh                    # Interactive wizard
./deploy-railway.sh                # Automated deployment

# Test
./test-deployment.sh               # Test all endpoints

# Railway CLI
railway logs                       # View logs
railway logs --follow              # Stream logs
railway status                     # Check status
railway variables                  # List variables
railway domain                     # Configure domain
railway open                       # Open dashboard
railway rollback                   # Rollback deployment

# Environment
source export-env.sh               # Load variables
./set-railway-vars.sh             # Set Railway variables
```

## After Deployment

### 1. Get Your URL

```bash
railway status
```

You'll get a URL like: `https://mortgage-guardian-backend-production.up.railway.app`

### 2. Test Endpoints

```bash
export API_URL="https://your-railway-url.up.railway.app"

# Health check
curl $API_URL/health

# Claude AI
curl -X POST $API_URL/v1/ai/claude/analyze \
  -H "Content-Type: application/json" \
  -d '{"documentText": "test", "documentType": "statement"}'
```

### 3. Update Frontend

Update your frontend configuration to use the Railway URL:

```javascript
const API_URL = 'https://your-railway-url.up.railway.app'
```

### 4. Add Custom Domain (Optional)

In Railway dashboard or via CLI:

```bash
railway domain
# Add: api.mortgageguardian.org
```

Then update DNS:
```
Type: CNAME
Name: api
Value: your-app.up.railway.app
TTL: 3600
```

## Available Endpoints

After deployment, these endpoints will be live:

- `GET /health` - Health check
- `POST /v1/ai/claude/analyze` - Claude AI document analysis
- `POST /v1/plaid/link_token` - Create Plaid Link token
- `POST /v1/plaid/exchange_token` - Exchange public token
- `POST /v1/plaid/accounts` - Get accounts
- `POST /v1/plaid/transactions` - Get transactions
- `POST /v1/documents/upload` - Upload document
- `GET /v1/documents` - List documents
- `GET /v1/documents/:id` - Get document
- `DELETE /v1/documents/:id` - Delete document

## CORS Configuration

Pre-configured for these domains:
- `https://mortgageguardian.org`
- `https://www.mortgageguardian.org`
- `https://app.mortgageguardian.org`
- `https://mortgage-guardian-app.netlify.app`

To add more domains:
```bash
railway variables set ALLOWED_ORIGINS="https://domain1.com,https://domain2.com"
```

## Services Deployed

1. **Backend API**
   - Node.js 20 + Express
   - Port 3000
   - Auto-restart enabled
   - Health checks configured

2. **PostgreSQL**
   - Managed by Railway
   - Auto-injected: `DATABASE_URL`

3. **Redis**
   - Managed by Railway
   - Auto-injected: `REDIS_URL`

## Environment Variables

### Auto-Set by Railway
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection
- `PORT` - Service port

### You Set (in .env.railway.local)
- `NODE_ENV=production` ✓
- `JWT_SECRET` ✓ (generated)
- `ENCRYPTION_KEY` ✓ (generated)
- `REFRESH_TOKEN_SECRET` ✓ (generated)
- `ALLOWED_ORIGINS` ✓ (configured)
- `ANTHROPIC_API_KEY` ⚠ (you add)
- `PLAID_CLIENT_ID` (optional)
- `PLAID_SECRET` (optional)

## Troubleshooting

### Deployment Fails

```bash
# Check logs
railway logs

# Check build logs
railway logs --build

# Verify token
railway whoami

# Check variables
railway variables
```

### Health Check Fails

```bash
# Wait for startup (60 seconds)
sleep 60
curl https://your-url/health

# Check logs
railway logs --follow
```

### API Key Issues

```bash
# Set Anthropic key
railway variables set ANTHROPIC_API_KEY="sk-ant-..."

# Verify it's set
railway variables | grep ANTHROPIC
```

### CORS Errors

```bash
# Update allowed origins
railway variables set ALLOWED_ORIGINS="https://your-frontend.com,https://other-domain.com"
```

## Cost Estimate

Railway Pricing:
- **Starter**: $5/month (500 hours)
- **Developer**: $20/month (2000 hours)

Expected cost: **$5-10/month** on Starter plan

## Security Notes

### Generated Keys
All keys are 256-bit cryptographic strength, generated with OpenSSL.

### Files Not Committed
- `.env.railway.local` ✓
- `export-env.sh` ✓
- `set-railway-vars.sh` ✓

### Best Practices Applied
- HTTPS enforced automatically
- Environment variables encrypted at rest
- Rate limiting enabled
- CORS configured for specific domains
- Secure key generation

## Documentation

- **Quick Start**: `QUICK-START.md` - Deploy in 5 minutes
- **Full Guide**: `RAILWAY-DEPLOYMENT.md` - Complete documentation
- **This File**: Quick reference and cheat sheet

## Support

### Railway
- Docs: https://docs.railway.app
- Discord: https://discord.gg/railway
- Status: https://railway.app/status

### View Your Deployment
```bash
railway open        # Open dashboard
railway logs        # View logs
railway status      # Check status
```

## Quick Start (Right Now)

Want to deploy immediately? Run:

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
./DEPLOY-NOW.sh
```

The interactive wizard will guide you through everything!

## Success Checklist

After deployment, verify:
- [ ] Health endpoint returns 200 OK
- [ ] CORS headers present
- [ ] Claude AI endpoint accessible
- [ ] Plaid endpoint accessible (if configured)
- [ ] Logs visible in Railway dashboard
- [ ] Environment variables correct
- [ ] Frontend can connect
- [ ] SSL certificate active

## Next Steps After Success

1. Update frontend API URL
2. Test all integrations
3. Set up monitoring/alerts
4. Configure custom domain (optional)
5. Document recovery procedures
6. Set up backups

---

**Ready to Deploy?**

Run: `./DEPLOY-NOW.sh`

**Questions?**

Check: `RAILWAY-DEPLOYMENT.md` (complete guide)

**Status**: ✓ All systems ready for deployment
