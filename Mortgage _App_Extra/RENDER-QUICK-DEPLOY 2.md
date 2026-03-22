# 🚀 Quick Deploy to Render.com (5 minutes)

## Why Render?
- **No CLI needed** - Deploy from web browser
- **Free PostgreSQL** included
- **Free Redis** included
- **Automatic HTTPS**
- **GitHub auto-deploy**

## Step-by-Step Deployment

### 1. Go to Render
**https://render.com**

### 2. Sign Up/Login
Use GitHub for easy integration

### 3. Create New Web Service
- Click **"New +"** → **"Web Service"**
- Connect your GitHub account
- Select repo: **Mortgage-Guardian-2.0**

### 4. Configure Service
```
Name: mortgage-guardian-backend
Region: Oregon (US West)
Branch: main
Root Directory: backend-express
Runtime: Node
Build Command: npm install
Start Command: npm start
Instance Type: Free
```

### 5. Add Environment Variables
Click **"Advanced"** and add:

```env
NODE_ENV=production
JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Add your API keys:
ANTHROPIC_API_KEY=your-claude-api-key
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox
```

### 6. Create Database
- Go to Dashboard
- Click **"New +"** → **"PostgreSQL"**
- Name: `mortgage-guardian-db`
- Instance: Free
- Click **"Create Database"**
- Copy the **Internal Database URL**

### 7. Add Database URL
Back in your Web Service environment variables:
```env
DATABASE_URL=postgresql://... (paste the Internal Database URL)
```

### 8. Add Redis
- Click **"New +"** → **"Redis"**
- Name: `mortgage-guardian-redis`
- Instance: Free
- Click **"Create Redis"**
- Copy the **Internal Redis URL**
- Add to environment variables:
```env
REDIS_URL=redis://... (paste the Internal Redis URL)
```

### 9. Deploy
Click **"Create Web Service"**

### 10. Get Your URL
After deployment (~5 minutes), you'll get:
```
https://mortgage-guardian-backend.onrender.com
```

## Test Your Deployment

```bash
# Check health
curl https://mortgage-guardian-backend.onrender.com/health

# Should return:
# {"status":"ok","service":"Mortgage Guardian Backend"}
```

## Update Your Frontend

Update `frontend/.env.production`:
```env
NEXT_PUBLIC_API_URL=https://mortgage-guardian-backend.onrender.com
```

Then redeploy frontend:
```bash
cd frontend
npm run build
npx netlify-cli deploy --prod --dir=.next
```

## ⚠️ Important Notes

### Free Tier Limitations
- **Spins down after 15 min of inactivity** (cold starts ~30s)
- **750 hours/month** (enough for one service)
- **PostgreSQL**: 1GB storage, 30 day retention for backups
- **Redis**: 25MB RAM

### For Production
Consider upgrading to paid plan ($7/month) for:
- No spin-downs
- Better performance
- More resources

## 🎉 Done!

Your backend will be live at:
```
https://mortgage-guardian-backend.onrender.com
```

Total time: **~5 minutes**