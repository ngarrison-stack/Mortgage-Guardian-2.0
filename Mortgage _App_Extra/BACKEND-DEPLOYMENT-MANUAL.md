# Backend Deployment Guide

## Quick Deployment Options

### Option 1: Railway (Recommended - Free Tier)

1. **Login to Railway**
   ```bash
   cd backend-express
   npx @railway/cli login
   ```

2. **Create Project**
   ```bash
   railway init -n mortgage-guardian-backend
   ```

3. **Add Services**
   ```bash
   railway add -p postgresql
   railway add -p redis
   ```

4. **Deploy**
   ```bash
   railway up
   ```

5. **Get Domain**
   ```bash
   railway domain
   ```

6. **Add Environment Variables**
   - Visit: https://railway.app/dashboard
   - Click your project
   - Go to Variables tab
   - Add:
     - `NODE_ENV=production`
     - `CORS_ORIGIN=https://mortgageguardian.org,https://mortgage-guardian-app.netlify.app`
     - `JWT_SECRET=` (generate secure secret)
     - `ENCRYPTION_KEY=` (generate secure key)

### Option 2: Render (Free Tier)

1. **Visit**: https://render.com
2. **Sign up/Login**
3. **New → Web Service**
4. **Connect GitHub repo**: ngarrison-stack/Mortgage-Guardian-2.0
5. **Settings**:
   - Name: `mortgage-guardian-backend`
   - Root Directory: `backend-express`
   - Build Command: `npm install && npm run build`
   - Start Command: `npm start`
6. **Add PostgreSQL**: New → PostgreSQL
7. **Environment Variables**: Same as Railway

### Option 3: Fly.io (Free Tier)

1. **Install Fly CLI**
   ```bash
   brew install flyctl
   ```

2. **Login**
   ```bash
   flyctl auth login
   ```

3. **Launch**
   ```bash
   cd backend-express
   flyctl launch --name mortgage-guardian-backend
   ```

4. **Deploy**
   ```bash
   flyctl deploy
   ```

5. **Add PostgreSQL**
   ```bash
   flyctl postgres create
   flyctl postgres attach
   ```

## Current Frontend Status

✅ **Frontend is LIVE at:**
- https://mortgageguardian.org
- https://www.mortgageguardian.org
- https://app.mortgageguardian.org
- Direct: https://mortgage-guardian-app.netlify.app

## Update Frontend with Backend URL

Once backend is deployed, update `frontend/.env.production`:
```env
NEXT_PUBLIC_API_URL=https://YOUR-BACKEND-URL
```

Then redeploy frontend:
```bash
cd frontend
npm run build
npx netlify-cli deploy --prod --dir=.next
```