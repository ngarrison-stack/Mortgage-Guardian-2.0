# 🚂 Railway Backend Deployment - Step by Step

## Quick Start (10 minutes)

### Step 1: Open Railway Dashboard
1. Go to: **https://railway.app**
2. Click **"Start New Project"**
3. Sign in with GitHub (recommended) or Email

### Step 2: Deploy from GitHub
1. Click **"Deploy from GitHub repo"**
2. Select repository: **Mortgage-Guardian-2.0**
3. Choose directory: `/backend-express`
4. Railway will auto-detect Node.js and start building

### Step 3: Add Database & Redis
1. In your project, click **"New"** → **"Database"**
2. Select **PostgreSQL**
3. Click **"New"** again → **"Database"**
4. Select **Redis**

### Step 4: Configure Environment Variables
1. Click on your backend service
2. Go to **"Variables"** tab
3. Click **"Raw Editor"**
4. Paste this entire block:

```env
NODE_ENV=production
JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org,https://mortgage-guardian-app.netlify.app
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### Step 5: Add Your API Keys
Still in Variables, add your actual API keys:
```env
ANTHROPIC_API_KEY=your-actual-claude-api-key
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox
```

### Step 6: Generate Domain
1. Go to **"Settings"** tab
2. Under **"Domains"**, click **"Generate Domain"**
3. Copy your domain (e.g., `mortgage-guardian-backend-production.up.railway.app`)

## ✅ Verification Checklist

After deployment, verify these endpoints work:

```bash
# Check health endpoint
curl https://your-backend.railway.app/health

# Should return:
# {"status":"ok","service":"Mortgage Guardian Backend","timestamp":"..."}
```

## 🔗 Your Backend URLs

Once deployed, your endpoints will be:
- Health Check: `https://your-backend.railway.app/health`
- Claude AI: `https://your-backend.railway.app/v1/ai/claude/analyze`
- Plaid Link: `https://your-backend.railway.app/v1/plaid/link_token`
- Plaid Exchange: `https://your-backend.railway.app/v1/plaid/exchange_token`

## 📝 Important Secrets to Save

```
JWT_SECRET: KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
ENCRYPTION_KEY: MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
```

**⚠️ Save these securely - they cannot be recovered!**

## 🚀 Next Steps After Deployment

1. **Update Frontend** - Update `frontend/.env.production` with your Railway URL
2. **Test Integration** - Verify API endpoints from frontend
3. **Configure iOS App** - Update backend URL in iOS app
4. **Monitor Logs** - Check Railway logs for any errors

## 🆘 Troubleshooting

### If deployment fails:
- Check Railway build logs for errors
- Ensure all environment variables are set
- Verify PostgreSQL and Redis are connected

### If API calls fail:
- Check CORS settings include your frontend domain
- Verify JWT_SECRET matches between services
- Check Railway logs for specific errors

## 📊 Railway Dashboard Links

- **Your Projects**: https://railway.app/dashboard
- **Documentation**: https://docs.railway.app
- **Support**: https://railway.app/help

---

**Estimated Time**: 10 minutes to fully deployed backend

**Need help?** The backend is already configured with `railway.toml` and all dependencies are updated.