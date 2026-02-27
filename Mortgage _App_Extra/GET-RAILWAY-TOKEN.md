# 🔑 How to Get Your Railway Token

## Quick Steps (2 minutes)

### 1. Login to Railway
Go to: **https://railway.app**

### 2. Navigate to Tokens
- Click your **profile icon** (top right)
- Select **Account Settings**
- Click **Tokens** in the sidebar
- Or go directly to: **https://railway.app/account/tokens**

### 3. Create New Token
- Click **"New Token"**
- Give it a name: `Mortgage Guardian Deploy`
- Click **"Create"**
- **Copy the token immediately** (it won't be shown again)

### 4. Test Your Token
```bash
export RAILWAY_TOKEN="your-token-here"
railway whoami
```

Should return your Railway username.

---

## 🚀 Alternative: Deploy Without Token

If you prefer not to use a token, you can deploy interactively:

### Option 1: Browser-Based Deploy
```bash
cd backend-express
railway login    # Opens browser
railway init     # Create project
railway up       # Deploy
```

### Option 2: GitHub Integration
1. Go to https://railway.app/new
2. Click **"Deploy from GitHub repo"**
3. Select **Mortgage-Guardian-2.0**
4. Choose `/backend-express` folder
5. Railway auto-deploys on every push

---

## 🔄 Alternative Platforms (If Railway Doesn't Work)

### Render.com (Recommended Alternative)
```bash
# No CLI needed - web only
1. Go to https://render.com
2. Connect GitHub
3. Deploy backend-express folder
4. Free PostgreSQL included
```

### Fly.io
```bash
brew install flyctl
flyctl auth login
cd backend-express
flyctl launch
flyctl postgres create
flyctl postgres attach
flyctl deploy
```

### Heroku (Requires Credit Card)
```bash
brew tap heroku/brew && brew install heroku
heroku create mortgage-guardian-backend
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini
git push heroku main
```

---

## 📝 Your Current Secure Keys

Save these for any deployment platform:

```
JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
```

CORS Origins:
```
https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org
```