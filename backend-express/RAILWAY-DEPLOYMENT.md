# Railway Deployment Guide - Mortgage Guardian Backend

Complete guide for deploying the Mortgage Guardian backend to Railway using automated token-based authentication.

## Prerequisites

1. **Railway Account**
   - Sign up at https://railway.app
   - Get your API token from https://railway.app/account/tokens

2. **Required Tools**
   - Railway CLI (already installed: `npm install -g @railway/cli`)
   - Node.js 20+ (already installed)
   - OpenSSL (for key generation)

3. **API Keys Required**
   - Anthropic API Key (Claude AI) - Get from https://console.anthropic.com
   - Plaid API credentials (optional) - Get from https://dashboard.plaid.com

## Quick Deployment (5 minutes)

### Step 1: Generate Secure Keys

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
chmod +x setup-env.sh deploy-railway.sh
./setup-env.sh
```

This generates:
- `.env.railway.local` - Full environment configuration
- `export-env.sh` - Export script for deployment
- `set-railway-vars.sh` - Railway variable setter

### Step 2: Configure API Keys

Edit `.env.railway.local` and add your API keys:

```bash
# Open in your editor
code .env.railway.local
# or
nano .env.railway.local
```

Update these values:
```env
ANTHROPIC_API_KEY=sk-ant-api03-YOUR-ACTUAL-KEY
PLAID_CLIENT_ID=your-actual-client-id  # Optional
PLAID_SECRET=your-actual-secret         # Optional
```

### Step 3: Get Railway Token

```bash
# Visit https://railway.app/account/tokens
# Create a new token
# Copy and export it:
export RAILWAY_TOKEN='your-railway-token-here'
```

### Step 4: Deploy

```bash
# Load environment variables
source export-env.sh

# Deploy to Railway
./deploy-railway.sh
```

The script will:
1. Authenticate with Railway
2. Create/link to project
3. Add PostgreSQL and Redis databases
4. Configure all environment variables
5. Deploy the application
6. Run health checks
7. Display deployment URL

## Manual Deployment Steps

If you prefer manual control:

### 1. Authenticate

```bash
export RAILWAY_TOKEN='your-token-here'
railway whoami  # Verify authentication
```

### 2. Initialize Project

```bash
railway init --name mortgage-guardian-backend
```

### 3. Add Databases

```bash
railway add --database postgres
railway add --database redis
```

### 4. Set Environment Variables

```bash
# Option A: Use our script
./set-railway-vars.sh

# Option B: Set manually
railway variables set NODE_ENV=production
railway variables set PORT=3000
railway variables set JWT_SECRET="your-jwt-secret"
railway variables set ENCRYPTION_KEY="your-encryption-key"
railway variables set ANTHROPIC_API_KEY="sk-ant-..."
railway variables set ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org"
```

### 5. Deploy

```bash
railway up
```

### 6. Configure Domain

```bash
railway domain  # Generates Railway subdomain
```

## Post-Deployment

### Get Deployment URL

```bash
railway status
# or
railway domain
```

### View Logs

```bash
railway logs
railway logs --follow  # Stream logs
```

### Test Endpoints

```bash
# Replace <your-url> with your actual Railway URL
export API_URL="https://your-app.up.railway.app"

# Health check
curl $API_URL/health

# Claude AI endpoint
curl -X POST $API_URL/v1/ai/claude/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "documentText": "Sample mortgage statement...",
    "documentType": "statement"
  }'

# Plaid endpoints
curl -X POST $API_URL/v1/plaid/link_token \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user"}'
```

### Open Railway Dashboard

```bash
railway open
```

## Environment Variables Reference

### Auto-Injected by Railway

These are automatically set by Railway when you add services:

- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `PORT` - Service port (default: 3000)

### Required Variables

You must set these:

```env
NODE_ENV=production
ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org
JWT_SECRET=<64-char-hex-string>
ENCRYPTION_KEY=<64-char-hex-string>
ANTHROPIC_API_KEY=sk-ant-api03-...
```

### Optional Variables

```env
# Plaid Integration
PLAID_CLIENT_ID=your-client-id
PLAID_SECRET=your-secret
PLAID_ENV=sandbox  # or production

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Email (Optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Monitoring (Optional)
SENTRY_DSN=https://...
LOG_LEVEL=info
```

## Custom Domain Setup

### Add Your Domain

1. In Railway dashboard:
   - Go to your project
   - Click on Settings
   - Navigate to Domains
   - Add custom domain: `api.mortgageguardian.org`

2. Update DNS records at your domain registrar:

```
Type: CNAME
Name: api
Value: <your-railway-app>.up.railway.app
TTL: Auto/3600
```

3. Wait for DNS propagation (5-60 minutes)

4. Railway will auto-provision SSL certificate

## Troubleshooting

### Deployment Fails

```bash
# Check logs
railway logs

# Check build logs
railway logs --build

# Verify environment variables
railway variables
```

### Health Check Fails

```bash
# Wait longer (initial startup can take 60-90 seconds)
sleep 60
curl https://your-app.up.railway.app/health

# Check if service is running
railway status

# View real-time logs
railway logs --follow
```

### Database Connection Issues

```bash
# Verify DATABASE_URL is set
railway variables | grep DATABASE_URL

# Check database status in Railway dashboard
railway open
```

### CORS Errors

Ensure `ALLOWED_ORIGINS` includes your frontend domains:

```bash
railway variables set ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org"
```

## Updating the Deployment

### Update Environment Variables

```bash
railway variables set VARIABLE_NAME="new-value"
```

### Redeploy After Code Changes

```bash
# Commit your changes to git
git add .
git commit -m "Update backend"
git push

# Deploy to Railway
railway up
```

### Rollback Deployment

```bash
railway rollback
```

## Performance Optimization

### Scale Up

In Railway dashboard:
- Project Settings → Resources
- Increase memory/CPU allocation
- Enable horizontal scaling (Pro plan)

### Monitor Performance

```bash
# View metrics
railway open  # Go to Metrics tab

# Set up alerts in Railway dashboard
```

## Security Best Practices

1. **Rotate Keys Regularly**
   ```bash
   # Generate new keys
   openssl rand -hex 32  # New JWT_SECRET
   openssl rand -hex 32  # New ENCRYPTION_KEY

   # Update in Railway
   railway variables set JWT_SECRET="new-key"
   ```

2. **Enable Railway's Security Features**
   - Private networking for databases
   - Automatic SSL/TLS
   - Secret encryption at rest

3. **Monitor Logs**
   ```bash
   railway logs --follow | grep -i error
   ```

4. **Set Up Alerts**
   - Configure in Railway dashboard
   - Alert on error rates
   - Alert on high CPU/memory

## Cost Management

### Current Plan

- Starter: $5/month (500 execution hours)
- Developer: $20/month (2000 execution hours)

### Optimize Costs

1. **Reduce idle time**
   - Railway auto-sleeps inactive services on free tier

2. **Monitor usage**
   ```bash
   railway open  # Check usage metrics
   ```

3. **Use appropriate instance size**
   - Start small, scale up as needed

## CI/CD Integration

### GitHub Actions (Optional)

Create `.github/workflows/deploy-railway.yml`:

```yaml
name: Deploy to Railway

on:
  push:
    branches: [main]
    paths:
      - 'backend-express/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Railway CLI
        run: npm install -g @railway/cli

      - name: Deploy to Railway
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
        run: |
          cd backend-express
          railway up --detach
```

Add `RAILWAY_TOKEN` to GitHub Secrets:
- Repo Settings → Secrets and variables → Actions
- New repository secret: `RAILWAY_TOKEN`

## Support

### Railway Documentation
- https://docs.railway.app
- https://railway.app/help

### Railway Community
- Discord: https://discord.gg/railway
- GitHub: https://github.com/railwayapp

### Mortgage Guardian Support
- Check logs: `railway logs`
- View status: `railway status`
- Open dashboard: `railway open`

## Quick Reference

```bash
# Deploy
./deploy-railway.sh

# Logs
railway logs
railway logs --follow

# Status
railway status

# Variables
railway variables
railway variables set KEY=value

# Domain
railway domain

# Open dashboard
railway open

# Rollback
railway rollback

# Help
railway --help
```

## Success Checklist

- [ ] Railway token obtained and exported
- [ ] Secure keys generated (`./setup-env.sh`)
- [ ] API keys configured in `.env.railway.local`
- [ ] Deployment completed (`./deploy-railway.sh`)
- [ ] Health check passing (`/health` endpoint)
- [ ] Claude AI endpoint working (`/v1/ai/claude/analyze`)
- [ ] CORS configured for frontend domains
- [ ] Custom domain configured (optional)
- [ ] Monitoring set up
- [ ] Backup strategy defined

## Next Steps

After successful deployment:

1. **Update Frontend Configuration**
   - Update API URL in frontend to point to Railway
   - Test all API integrations

2. **Set Up Monitoring**
   - Configure Sentry (optional)
   - Set up Railway alerts
   - Monitor error logs

3. **Performance Testing**
   - Load test critical endpoints
   - Optimize database queries
   - Configure caching

4. **Documentation**
   - Document API endpoints
   - Update environment variables
   - Create runbooks for common issues

5. **Backup Strategy**
   - Set up database backups in Railway
   - Export environment variables to secure location
   - Document recovery procedures
