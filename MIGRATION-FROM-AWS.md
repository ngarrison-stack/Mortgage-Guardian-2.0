# 🔄 AWS-FREE MIGRATION GUIDE

## Overview
This guide migrates Mortgage Guardian 2.0 from AWS (Lambda, S3, DynamoDB, Bedrock) to a free/low-cost alternative stack.

## ❌ Removing These AWS Services:
- **AWS Lambda** → Railway/Vercel
- **API Gateway** → Express.js REST API
- **AWS Bedrock** → Direct Anthropic Claude API
- **DynamoDB** → Supabase PostgreSQL
- **S3** → Supabase Storage
- **CloudWatch** → Railway logs / Vercel logs

## ✅ New Tech Stack (All Free Tiers Available)

### **Backend Hosting: Railway** (Recommended)
- **Why**: Free $5/month credit, always-on servers, easy deployment
- **Alternative**: Render ($0 free tier, sleeps after inactivity)
- **Alternative**: Fly.io ($5 free credit)
- **Alternative**: Vercel (serverless functions, free tier)

### **Database: Supabase**
- **Why**: Free PostgreSQL database (500MB), realtime capabilities, easy auth
- **Alternative**: PlanetScale (MySQL, free tier)
- **Alternative**: MongoDB Atlas (free 512MB)

### **Storage: Supabase Storage**
- **Why**: Included with Supabase, S3-compatible API, 1GB free
- **Alternative**: Cloudinary (free 25GB/month, optimized for images)
- **Alternative**: Backblaze B2 (10GB free)

### **Claude AI: Direct Anthropic API**
- **Why**: Same Claude models, no AWS Bedrock needed
- **Cost**: Pay-per-token (Claude 3.5 Sonnet: $3/million input tokens)

### **Plaid Integration**
- **Status**: ✅ Already AWS-independent (just needs HTTP server)

---

## 📋 Migration Steps

### **Step 1: Create Supabase Project** (5 minutes)

1. **Sign up**: https://supabase.com
2. **Create new project**:
   - Name: `mortgage-guardian`
   - Database password: (save securely)
   - Region: Choose closest to your users

3. **Get credentials** from Settings → API:
   - `SUPABASE_URL`: https://your-project.supabase.co
   - `SUPABASE_ANON_KEY`: public anon key
   - `SUPABASE_SERVICE_KEY`: service role key (keep secret!)

4. **Create database tables** (SQL Editor):
```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT UNIQUE NOT NULL,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Documents table
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id TEXT UNIQUE NOT NULL,
  user_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  document_type TEXT,
  content TEXT,
  analysis_results JSONB,
  metadata JSONB,
  storage_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_created_at ON documents(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- RLS policies (users can only access their own data)
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can view own documents" ON documents
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own documents" ON documents
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own documents" ON documents
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own documents" ON documents
  FOR DELETE USING (auth.uid()::text = user_id);
```

5. **Setup Storage Bucket**:
   - Go to Storage → New Bucket
   - Name: `documents`
   - Public: No (private)
   - File size limit: 50MB
   - Allowed MIME types: `application/pdf,image/jpeg,image/png,image/heic`

---

### **Step 2: Deploy New Backend to Railway** (10 minutes)

1. **Sign up**: https://railway.app
2. **Create new project**: Empty project
3. **Deploy from GitHub**:
   - Connect your GitHub repository
   - Select `backend-express` directory (we'll create this)
   - Auto-deploy on push: ✅

4. **Add environment variables** (Settings → Variables):
```bash
NODE_ENV=production
PORT=3000

# Anthropic Claude API
ANTHROPIC_API_KEY=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

# Plaid
PLAID_CLIENT_ID=68bdabb75b00b300221d6a6f
PLAID_SECRET=a0b4a831d7c437125f1a285c90dd7a
PLAID_ENV=sandbox

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
```

5. **Get deployment URL**: Railway will give you a URL like `https://mortgage-guardian-production.up.railway.app`

---

### **Step 3: Alternative - Deploy to Vercel** (5 minutes)

If you prefer Vercel's serverless approach:

1. **Install Vercel CLI**:
```bash
npm install -g vercel
```

2. **Deploy**:
```bash
cd backend-express
vercel --prod
```

3. **Add environment variables** via Vercel dashboard

---

## 💰 Cost Comparison

### **AWS Stack (OLD):**
- Lambda: $0.20 per 1M requests
- API Gateway: $3.50 per million requests
- DynamoDB: $1.25 per million reads
- S3: $0.023 per GB/month
- Bedrock Claude: $3 per million input tokens
- **Total for 10K users**: ~$500-1000/month

### **New Stack:**
- Railway: **FREE** (up to $5 credit/month) or $5-20/month
- Supabase: **FREE** (500MB DB, 1GB storage) or $25/month Pro
- Claude API: $3 per million tokens (same as before)
- **Total for 10K users**: ~$50-100/month

**💰 Savings: 80-90% reduction in infrastructure costs!**

---

## 🔧 Technical Implementation

See the new `backend-express/` directory for the complete implementation:

- `backend-express/server.js` - Main Express server
- `backend-express/routes/` - API routes
- `backend-express/services/` - Business logic
- `backend-express/config/` - Configuration
- `backend-express/package.json` - Dependencies

---

## ✅ Migration Checklist

- [ ] Create Supabase project and database
- [ ] Setup Supabase storage bucket
- [ ] Get Anthropic Claude API key (already have it!)
- [ ] Deploy backend to Railway/Vercel
- [ ] Test all API endpoints
- [ ] Update iOS app API URL
- [ ] Test end-to-end functionality
- [ ] Delete AWS resources (optional)

---

## 🚀 Deployment Commands

```bash
# 1. Setup new backend
cd backend-express
npm install

# 2. Test locally
npm run dev

# 3. Deploy to Railway
# (Use Railway dashboard or CLI)

# 4. Update iOS app
# Edit MortgageGuardian/Configuration/APIConfiguration.swift
# Change baseURL to Railway URL

# 5. Test
curl https://your-app.railway.app/health
```

---

## 📊 Feature Parity Matrix

| Feature | AWS | New Stack | Status |
|---------|-----|-----------|--------|
| Claude AI Analysis | Bedrock | Direct API | ✅ Same |
| Document Storage | S3 | Supabase Storage | ✅ Better API |
| Database | DynamoDB | PostgreSQL | ✅ More powerful |
| Plaid Integration | Lambda | Express | ✅ Identical |
| API Routing | API Gateway | Express | ✅ More flexible |
| Monitoring | CloudWatch | Railway Logs | ✅ Better UI |
| Deployment | SAM | Git Push | ✅ Easier |

---

## 🎯 Timeline

- **Setup Supabase**: 10 minutes
- **Deploy backend**: 15 minutes
- **Update iOS app**: 5 minutes
- **Testing**: 30 minutes
- **Total**: **~1 hour** to go live!

---

## 🆘 Troubleshooting

### "Railway build fails"
- Check `package.json` has correct start script
- Ensure all dependencies are listed
- Check Railway logs for specific error

### "Supabase connection fails"
- Verify `SUPABASE_URL` and `SUPABASE_SERVICE_KEY`
- Check IP whitelist (Supabase allows all by default)
- Test connection with Postman first

### "Claude API errors"
- Verify API key is valid: https://console.anthropic.com
- Check rate limits (free tier: 5 requests/minute)
- Ensure API key starts with `sk-ant-`

---

**You're now AWS-free and running on better infrastructure! 🎉**
