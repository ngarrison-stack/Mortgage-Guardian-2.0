# START HERE - Deploy Your Backend to Railway

**Quick Start**: Run `./DEPLOY-NOW.sh` and follow the prompts!

## What You Have

A complete, production-ready Railway deployment system with:

- ✓ Automated deployment scripts
- ✓ Secure key generation
- ✓ Interactive wizard
- ✓ Comprehensive testing
- ✓ Full documentation
- ✓ Production security

## Deploy in 3 Steps

### Step 1: Get Railway Token

Visit: https://railway.app/account/tokens

Create a token and run:
```bash
export RAILWAY_TOKEN='your-token-here'
```

### Step 2: Add Your API Key

Edit `.env.railway.local`:
```bash
nano .env.railway.local
```

Update this line:
```env
ANTHROPIC_API_KEY=sk-ant-api03-YOUR-ACTUAL-KEY
```

Save and exit (Ctrl+X, Y, Enter)

### Step 3: Deploy

```bash
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express
./DEPLOY-NOW.sh
```

Follow the prompts. Done in ~5 minutes!

## Your Deployment Will Include

- **Backend API**: Node.js 20 + Express
- **PostgreSQL**: Managed database
- **Redis**: Caching layer
- **HTTPS**: Automatic SSL
- **Monitoring**: Built-in health checks
- **Auto-deploy**: Git push to deploy

## After Deployment

You'll get a URL like:
```
https://mortgage-guardian-backend-production.up.railway.app
```

Test it:
```bash
curl https://your-url/health
```

Update your frontend to use this URL!

## Need Help?

### Quick Guides
- `QUICK-START.md` - 5-minute guide
- `RAILWAY-DEPLOYMENT.md` - Complete documentation
- `DEPLOYMENT-FLOW.md` - Visual flow diagrams
- `README-DEPLOYMENT.md` - Command reference

### Interactive Wizard
```bash
./DEPLOY-NOW.sh
```

### Automated Deployment
```bash
source export-env.sh
./deploy-railway.sh
```

### Test Deployment
```bash
./test-deployment.sh
```

## Common Commands

```bash
# View logs
railway logs

# Check status
railway status

# Open dashboard
railway open

# Update variable
railway variables set KEY=value

# Rollback
railway rollback
```

## Cost

Railway Starter: **$5/month**
- 500 execution hours
- PostgreSQL included
- Redis included
- SSL certificates included
- Automatic deployments

## Support

- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- Project logs: `railway logs`

## Ready?

```bash
./DEPLOY-NOW.sh
```

Let's deploy! 🚀
