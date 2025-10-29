# 🚀 Deploy to Vercel - Complete Guide

## Why Vercel?

✅ **Auto-scales to millions** - Handles any traffic spike automatically
✅ **Global CDN** - 100+ edge locations worldwide
✅ **Zero configuration** - Deploy with one command
✅ **Free tier** - Generous free plan for getting started
✅ **Instant deployments** - Live in seconds with git push
✅ **Automatic HTTPS** - SSL certificates included

---

## 📋 Prerequisites (5 minutes)

1. **Vercel Account** (Free)
   - Sign up: https://vercel.com/signup
   - Connect your GitHub account

2. **Anthropic API Key** (Required)
   - Get it: https://console.anthropic.com/settings/keys
   - Copy your API key (starts with `sk-ant-`)

3. **Plaid Credentials** (Optional - has mock fallback)
   - Client ID: `68bdabb75b00b300221d6a6f`
   - Get sandbox secret: https://dashboard.plaid.com/developers/keys

4. **Supabase** (Optional - has mock fallback)
   - Sign up: https://supabase.com
   - Create project (takes 2 min)
   - Get URL and service key from Settings → API

---

## 🎯 Option 1: Deploy via Vercel Dashboard (Easiest)

### Step 1: Import Project

1. Go to https://vercel.com/new
2. Click **"Import Project"**
3. Select **"Import Git Repository"**
4. Choose your `Mortgage-Guardian-2.0` repository
5. **Root Directory**: Change to `backend-express`
6. **Framework Preset**: Leave as "Other"
7. Click **"Deploy"** (it will fail - that's OK!)

### Step 2: Add Environment Variables

1. Go to your project → **Settings** → **Environment Variables**
2. Add these variables:

```bash
# Required
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Optional (mock service used if not set)
PLAID_CLIENT_ID=68bdabb75b00b300221d6a6f
PLAID_SECRET=your-plaid-sandbox-secret
PLAID_ENV=sandbox

# Optional (in-memory storage used if not set)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key

# Optional configuration
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
ALLOWED_ORIGINS=*
```

### Step 3: Redeploy

1. Go to **Deployments** tab
2. Click the three dots (⋯) on the latest deployment
3. Click **"Redeploy"**
4. Wait ~30 seconds
5. ✅ Your backend is live!

### Step 4: Get Your URL

Your backend is now live at:
```
https://your-project-name.vercel.app
```

Example: `https://mortgage-guardian.vercel.app`

---

## 🎯 Option 2: Deploy via CLI (Faster for Developers)

### Step 1: Install Vercel CLI

```bash
npm install -g vercel
```

### Step 2: Login

```bash
vercel login
# Follow the prompts to authenticate
```

### Step 3: Deploy

```bash
cd backend-express
vercel --prod
```

You'll be asked:
- **Setup and deploy?** → Yes
- **Which scope?** → Your account
- **Link to existing project?** → No
- **Project name?** → mortgage-guardian-backend (or your choice)
- **Directory?** → `./` (current directory)
- **Override settings?** → No

### Step 4: Add Environment Variables

```bash
# Add variables via CLI
vercel env add ANTHROPIC_API_KEY production
# Paste your key when prompted

vercel env add PLAID_CLIENT_ID production
# Paste: 68bdabb75b00b300221d6a6f

vercel env add PLAID_SECRET production
# Paste your Plaid secret

vercel env add PLAID_ENV production
# Type: sandbox

# Optional: Supabase
vercel env add SUPABASE_URL production
vercel env add SUPABASE_SERVICE_KEY production
```

### Step 5: Redeploy with Variables

```bash
vercel --prod
```

✅ Done! Your backend is live with all environment variables.

---

## 🧪 Test Your Deployment

### Test Health Endpoint

```bash
# Replace with your Vercel URL
curl https://your-project.vercel.app/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-...",
  "uptime": 123.45,
  "environment": "production",
  "version": "2.0.0",
  "services": {
    "anthropic": true,
    "plaid": true,
    "supabase": true
  }
}
```

### Test Claude API

```bash
curl -X POST https://your-project.vercel.app/v1/ai/claude/test \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "success": true,
  "message": "Claude API is working!",
  "response": "Hello from Mortgage Guardian backend!",
  "timestamp": "..."
}
```

### Test Plaid (Mock Mode)

```bash
curl -X POST https://your-project.vercel.app/v1/plaid/link_token \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test123"}'
```

Should return a link token.

---

## 📱 Update iOS App

### Step 1: Update API Configuration

Replace `MortgageGuardian/Configuration/APIConfiguration.swift` with `APIConfiguration-NEW.swift`

Then update the baseURL:

```swift
struct APIConfiguration {
    // Replace with your Vercel URL
    static let baseURL = "https://your-project.vercel.app"

    // Rest of the file stays the same...
}
```

### Step 2: Build and Test

1. Open `MortgageGuardian.xcworkspace` in Xcode
2. Select iPhone simulator
3. Press ⌘R to run
4. Test document analysis feature
5. Check that it connects to your Vercel backend

---

## 🔥 Automatic Deployments (Git Push = Deploy)

Once set up, Vercel automatically deploys when you push to GitHub:

```bash
# Make changes to backend
cd backend-express
# Edit files...

# Commit and push
git add .
git commit -m "Update backend"
git push

# Vercel automatically deploys! ✨
# Check deployment: https://vercel.com/your-account/your-project
```

Every push to `main` (or your default branch) triggers a deployment.

**Preview Deployments**: Pushes to other branches create preview URLs for testing!

---

## 📊 Vercel Dashboard Features

### 1. Real-Time Logs
- Go to your project → **Logs**
- See all requests in real-time
- Filter by status code, endpoint, etc.

### 2. Analytics
- Go to **Analytics** tab
- See requests/second, response times
- Track error rates
- Monitor bandwidth usage

### 3. Environment Variables
- Go to **Settings** → **Environment Variables**
- Add/edit variables anytime
- Redeploy to apply changes

### 4. Domains
- Go to **Settings** → **Domains**
- Add custom domain: `api.yourdomain.com`
- Automatic HTTPS included

---

## 💰 Vercel Pricing & Scaling

### Hobby Plan (FREE)
- **Perfect for**: Development, testing, small projects
- **Limits**:
  - 100 GB bandwidth/month
  - 100 hours serverless execution/month
  - 1 GB storage
- **Good for**: Up to ~10K requests/day

### Pro Plan ($20/month)
- **Perfect for**: Production apps, startups
- **Limits**:
  - 1 TB bandwidth/month
  - 1000 hours execution/month
  - 100 GB storage
- **Good for**: Up to 1M requests/day

### Enterprise (Custom)
- **Perfect for**: High-traffic apps
- **Unlimited** everything
- **Good for**: 10M+ requests/day
- **Price**: Custom (usually $500+/month)

### Scaling Path Example

| Users | Requests/Day | Plan | Cost |
|-------|-------------|------|------|
| 0-1K | 10K | Hobby (FREE) | $0 |
| 1K-10K | 100K | Hobby (FREE) | $0 |
| 10K-100K | 1M | Pro | $20/mo |
| 100K-1M | 10M | Pro | $20/mo |
| 1M+ | 100M+ | Enterprise | Custom |

**Your app will likely stay FREE until you hit 10K users!** 🎉

---

## 🚨 Common Issues & Solutions

### "Module not found" Error

**Cause**: Missing dependencies in `package.json`

**Solution**:
```bash
cd backend-express
npm install
vercel --prod
```

### "Function exceeded timeout"

**Cause**: Claude API taking too long (>30s on Hobby plan)

**Solution**: Upgrade to Pro plan (300s timeout) or optimize requests

### "Environment variable not found"

**Cause**: Variable not set in Vercel

**Solution**:
```bash
# Check current variables
vercel env ls

# Add missing variable
vercel env add VARIABLE_NAME production

# Redeploy
vercel --prod
```

### "CORS error" from iOS app

**Cause**: Vercel URL not allowed in CORS

**Solution**: Should work with `ALLOWED_ORIGINS=*`, but if not:
```bash
vercel env add ALLOWED_ORIGINS production
# Enter: https://your-ios-app-domain.com

vercel --prod
```

---

## 🔒 Security Best Practices

### 1. Protect Environment Variables
- ✅ Never commit API keys to git
- ✅ Use Vercel environment variables
- ✅ Rotate keys periodically

### 2. Rate Limiting
Already enabled! Default: 100 requests per 15 minutes per IP

To adjust:
```bash
vercel env add RATE_LIMIT_MAX_REQUESTS production
# Enter: 200 (or your preferred limit)
```

### 3. CORS Configuration
For production, restrict origins:
```bash
vercel env add ALLOWED_ORIGINS production
# Enter: https://yourdomain.com,https://app.yourdomain.com
```

### 4. Monitor Logs
Check Vercel logs daily for:
- Unusual traffic spikes
- Error patterns
- Failed authentication attempts

---

## 📈 Performance Optimization

### 1. Enable Edge Caching
Add to `vercel.json`:
```json
{
  "headers": [
    {
      "source": "/health",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "s-maxage=60, stale-while-revalidate"
        }
      ]
    }
  ]
}
```

### 2. Use Edge Functions (Optional)
For ultra-low latency, convert to Edge Functions:
- Learn more: https://vercel.com/docs/functions/edge-functions

### 3. Monitor Performance
- Use Vercel Analytics
- Set up alerts for slow requests
- Optimize slow endpoints

---

## 🎯 Next Steps After Deployment

1. ✅ **Test thoroughly**
   - Upload documents
   - Test Claude analysis
   - Test Plaid integration
   - Check error handling

2. ✅ **Setup Supabase** (if not done)
   - For production document storage
   - Better than in-memory mock

3. ✅ **Add Custom Domain** (optional)
   - `api.mortgageguardian.com`
   - Free SSL included

4. ✅ **Setup Monitoring**
   - Enable Vercel Analytics ($20/mo)
   - Or use free alternatives (Sentry, LogRocket)

5. ✅ **Deploy iOS App**
   - Update API URL in app
   - Deploy to TestFlight
   - Submit to App Store

---

## 🆘 Getting Help

### Vercel Support
- **Docs**: https://vercel.com/docs
- **Community**: https://github.com/vercel/vercel/discussions
- **Status**: https://vercel-status.com

### Project Support
- **Check logs**: `vercel logs` or Vercel dashboard
- **Test locally**: `npm run dev` in `backend-express/`
- **Health check**: Always test `/health` endpoint first

### Common Commands
```bash
# View logs
vercel logs

# List deployments
vercel ls

# View environment variables
vercel env ls

# Remove deployment
vercel remove [deployment-url]

# Get project info
vercel inspect [deployment-url]
```

---

## 🎉 Congratulations!

Your Mortgage Guardian backend is now:
- ✅ **Deployed on Vercel**
- ✅ **Scales to millions automatically**
- ✅ **Global CDN (100+ locations)**
- ✅ **Automatic HTTPS**
- ✅ **Free tier to start**
- ✅ **Zero configuration scaling**

**Your Backend URL**: `https://your-project.vercel.app`

**Time to deploy**: ~10 minutes
**Time to scale to 1M users**: Automatic! ⚡

---

## 📚 Additional Resources

- **Vercel Docs**: https://vercel.com/docs
- **Express on Vercel**: https://vercel.com/guides/using-express-with-vercel
- **Environment Variables**: https://vercel.com/docs/concepts/projects/environment-variables
- **Custom Domains**: https://vercel.com/docs/concepts/projects/custom-domains
- **Pricing**: https://vercel.com/pricing

---

**Ready to deploy?** Run this now:

```bash
cd backend-express
npm install -g vercel
vercel login
vercel --prod
```

Then add your environment variables and you're live! 🚀
