# 🚀 QUICK START GUIDE (AWS-FREE)

## Get Mortgage Guardian Online in 1 Hour!

This guide will get your app deployed without AWS using free/low-cost alternatives.

---

## ✅ Prerequisites (5 minutes)

1. **Anthropic Claude API Key** (Required)
   - Sign up: https://console.anthropic.com
   - Get API key: https://console.anthropic.com/settings/keys
   - Costs: ~$3 per 1M tokens (Claude 3.5 Sonnet)

2. **Plaid Credentials** (Optional - has mock fallback)
   - Sign up: https://dashboard.plaid.com/signup
   - Get Client ID and Secret from Keys section
   - Free: Development sandbox

3. **Supabase Account** (Optional - has mock fallback)
   - Sign up: https://supabase.com
   - Free tier: 500MB database, 1GB storage
   - Create new project (takes 2 minutes)

4. **Railway Account** (For hosting - Recommended)
   - Sign up: https://railway.app
   - Free: $5 credit/month
   - Or use Vercel/Render

---

## 🎯 Step 1: Deploy Backend (15 minutes)

### Option A: Railway (Easiest - Recommended)

1. **Fork/Clone this repository** if you haven't

2. **Sign in to Railway**: https://railway.app

3. **Create new project**:
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Connect your GitHub account
   - Select this repository
   - Choose `backend-express` as the root directory

4. **Add environment variables** (Settings → Variables):
   ```bash
   NODE_ENV=production
   PORT=3000

   # Required: Anthropic Claude API
   ANTHROPIC_API_KEY=sk-ant-your-key-here

   # Optional: Plaid (uses mock if not set)
   PLAID_CLIENT_ID=68bdabb75b00b300221d6a6f
   PLAID_SECRET=your-plaid-secret
   PLAID_ENV=sandbox

   # Optional: Supabase (uses mock if not set)
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_KEY=your-service-key
   ```

5. **Deploy!** Railway will:
   - Install dependencies
   - Start the server
   - Give you a public URL like: `https://mortgage-guardian-production.up.railway.app`

6. **Copy your deployment URL** - you'll need it for the iOS app

### Option B: Vercel (Serverless)

```bash
cd backend-express
npm install -g vercel
vercel --prod
# Follow prompts and add environment variables
```

### Option C: Render (Free tier)

1. Go to https://render.com
2. New → Web Service
3. Connect GitHub repo
4. Root directory: `backend-express`
5. Build: `npm install`
6. Start: `npm start`
7. Add environment variables
8. Deploy

---

## 🗄️ Step 2: Setup Supabase (10 minutes) - OPTIONAL

If you want real database/storage (not required for testing):

1. **Create project** at https://supabase.com
   - Project name: `mortgage-guardian`
   - Set strong database password
   - Choose region closest to users

2. **Create database tables** (SQL Editor):
   ```sql
   -- Users table
   CREATE TABLE users (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     user_id TEXT UNIQUE NOT NULL,
     email TEXT,
     created_at TIMESTAMPTZ DEFAULT NOW()
   );

   -- Documents table
   CREATE TABLE documents (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     document_id TEXT UNIQUE NOT NULL,
     user_id TEXT NOT NULL,
     file_name TEXT NOT NULL,
     document_type TEXT,
     analysis_results JSONB,
     metadata JSONB,
     storage_path TEXT,
     created_at TIMESTAMPTZ DEFAULT NOW(),
     FOREIGN KEY (user_id) REFERENCES users(user_id)
   );

   -- Indexes
   CREATE INDEX idx_documents_user_id ON documents(user_id);
   CREATE INDEX idx_documents_created_at ON documents(created_at DESC);
   ```

3. **Create storage bucket**:
   - Storage → New bucket
   - Name: `documents`
   - Public: No (private)
   - File size limit: 50MB

4. **Get credentials** (Settings → API):
   - Copy `URL` and `service_role key`
   - Add to Railway environment variables
   - Redeploy backend

---

## 📱 Step 3: Update iOS App (5 minutes)

1. **Open project** in Xcode:
   ```bash
   cd Mortgage-Guardian-2.0
   open MortgageGuardian.xcworkspace
   ```

2. **Update API configuration**:
   - Replace: `MortgageGuardian/Configuration/APIConfiguration.swift`
   - With: `MortgageGuardian/Configuration/APIConfiguration-NEW.swift`
   - Update the `baseURL` to your Railway URL:

   ```swift
   // Change this line:
   static let baseURL = "REPLACE_WITH_YOUR_DEPLOYMENT_URL"

   // To your Railway URL:
   static let baseURL = "https://mortgage-guardian-production.up.railway.app"
   ```

3. **Build and test**:
   - Select iPhone simulator
   - Press ⌘R to run
   - Test document analysis feature

---

## 🧪 Step 4: Test Everything (10 minutes)

### Test Backend Health

```bash
# Replace with your Railway URL
curl https://your-app.railway.app/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-...",
  "services": {
    "anthropic": true,
    "plaid": true,
    "supabase": true
  }
}
```

### Test Claude API

```bash
curl -X POST https://your-app.railway.app/v1/ai/claude/test \
  -H "Content-Type: application/json"
```

### Test from iOS App

1. Open app in simulator
2. Upload a test mortgage document
3. Watch analysis results appear
4. Check Railway logs for requests

---

## 🎉 Step 5: Deploy to TestFlight (20 minutes)

See main `DEPLOYMENT_GUIDE.md` for full TestFlight instructions.

Quick version:

```bash
cd Mortgage-Guardian-2.0

# Setup fastlane (if not done)
bundle install

# Build and upload to TestFlight
bundle exec fastlane beta
```

---

## 💰 Cost Breakdown

### Free Tier (Perfect for Development)

- **Railway**: $5 free credit/month
- **Supabase**: 500MB database, 1GB storage
- **Claude API**: Pay per use (~$0.30 per document)
- **Plaid**: Free in sandbox mode
- **Total**: **FREE** for development!

### Production (10K users)

- **Railway**: $20/month (scales automatically)
- **Supabase**: $25/month Pro tier
- **Claude API**: ~$30/month (100 docs/day)
- **Plaid**: ~$25/month (varies by connections)
- **Total**: **~$100/month**

vs AWS stack at ~$500-1000/month = **80-90% savings!**

---

## 🔧 Troubleshooting

### "Backend health check fails"

```bash
# Check Railway logs
railway logs

# Common issues:
# 1. ANTHROPIC_API_KEY not set
# 2. Port not set to 3000
# 3. Build failed (check logs)
```

### "Claude API errors in app"

- Verify API key is valid at https://console.anthropic.com
- Check Railway environment variables
- Test backend directly with curl

### "iOS app can't connect"

- Verify `baseURL` matches Railway URL exactly
- Check Info.plist allows HTTP (or use HTTPS)
- Test `/health` endpoint with curl first

### "Plaid not working"

- That's OK! Mock service works fine for testing
- Get real credentials from https://dashboard.plaid.com
- Update Railway environment variables

---

## 📊 Architecture Comparison

### OLD (AWS)
```
iOS App → API Gateway → Lambda → Bedrock/DynamoDB/S3
Cost: ~$500-1000/mo | Setup: Complex | Suspended ❌
```

### NEW (AWS-Free)
```
iOS App → Railway → Express.js → Claude API/Supabase
Cost: ~$50-100/mo | Setup: 1 hour | Works ✅
```

---

## 🎯 Next Steps

1. ✅ **Test thoroughly** with sample documents
2. ✅ **Add real Plaid credentials** (optional)
3. ✅ **Setup Supabase** for production storage (optional)
4. ✅ **Configure custom domain** (optional)
5. ✅ **Deploy to TestFlight** for beta testing
6. ✅ **Submit to App Store** when ready

---

## 📞 Support

- **Backend not starting?** Check Railway logs
- **API errors?** Test `/health` endpoint first
- **iOS build issues?** Clean build folder (⌘⇧K)
- **Plaid errors?** Use mock mode (it's fine!)

---

## 🏆 You Did It!

Your app is now:
- ✅ Running on modern infrastructure
- ✅ 80-90% cheaper than AWS
- ✅ Easier to maintain and scale
- ✅ Ready for production
- ✅ AWS-free! 🎉

**Total time: ~1 hour from zero to deployed backend**

**Next**: Test the app, deploy to TestFlight, and submit to App Store!

---

## 📚 Additional Resources

- **Full Migration Guide**: `MIGRATION-FROM-AWS.md`
- **Backend README**: `backend-express/README.md`
- **Deployment Guide**: `DEPLOYMENT_GUIDE.md`
- **Railway Docs**: https://docs.railway.app
- **Supabase Docs**: https://supabase.com/docs
- **Claude API Docs**: https://docs.anthropic.com

---

**Welcome to the AWS-free world! 🚀**
