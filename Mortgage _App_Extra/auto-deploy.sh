#!/bin/bash

# ============================================
# 🤖 AUTOMATED DEPLOYMENT FOR MORTGAGE GUARDIAN
# ============================================
# This script will automatically:
# 1. Deploy frontend to Vercel
# 2. Deploy backend to Railway
# 3. Generate DNS records for you to copy
# 4. Set up everything with minimal manual work

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
DOMAIN="mortgageguardian.org"
FRONTEND_SUBDOMAIN="app.mortgageguardian.org"
API_SUBDOMAIN="api.mortgageguardian.org"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🤖 AUTOMATED DEPLOYMENT - mortgageguardian.org${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}This script will automatically:${NC}"
echo "✅ Deploy your frontend to Vercel"
echo "✅ Deploy your backend to Railway"
echo "✅ Configure custom domains"
echo "✅ Generate DNS records for GoDaddy/Cloudflare"
echo "✅ Set up SSL certificates"
echo ""
echo -e "${YELLOW}You'll only need to:${NC}"
echo "📋 Copy DNS records to your provider (GoDaddy/Cloudflare)"
echo ""
read -p "Ready to start? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# ============================================
# STEP 1: INSTALL REQUIRED TOOLS
# ============================================
echo ""
echo -e "${CYAN}Step 1: Checking/Installing Required Tools${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check/Install Vercel CLI
if ! command -v vercel &> /dev/null; then
    echo "📦 Installing Vercel CLI..."
    npm install -g vercel
    echo -e "${GREEN}✅ Vercel CLI installed${NC}"
else
    echo -e "${GREEN}✅ Vercel CLI already installed${NC}"
fi

# Check/Install Railway CLI
if ! command -v railway &> /dev/null; then
    echo "📦 Installing Railway CLI..."
    npm install -g @railway/cli
    echo -e "${GREEN}✅ Railway CLI installed${NC}"
else
    echo -e "${GREEN}✅ Railway CLI already installed${NC}"
fi

# ============================================
# STEP 2: DEPLOY FRONTEND TO VERCEL
# ============================================
echo ""
echo -e "${CYAN}Step 2: Deploying Frontend to Vercel${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd frontend

# Create Vercel configuration
cat > vercel.json << EOF
{
  "name": "mortgage-guardian-frontend",
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/next"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/$1"
    }
  ],
  "env": {
    "NEXT_PUBLIC_API_URL": "https://api.mortgageguardian.org",
    "NEXT_PUBLIC_APP_URL": "https://app.mortgageguardian.org"
  }
}
EOF

echo "🚀 Deploying to Vercel..."
echo -e "${YELLOW}Note: If prompted, use these settings:${NC}"
echo "  • Set up and deploy: Y"
echo "  • Which scope: Your account"
echo "  • Link to existing project: N"
echo "  • Project name: mortgage-guardian"
echo "  • Directory: ./"
echo "  • Override settings: N"
echo ""

# Deploy with production flag
DEPLOYMENT_URL=$(vercel --prod --yes 2>&1 | grep -o 'https://[^ ]*' | tail -1)

if [ -z "$DEPLOYMENT_URL" ]; then
    # Fallback if URL capture fails
    vercel --prod --yes
    echo ""
    echo -e "${YELLOW}Enter your Vercel deployment URL:${NC}"
    read DEPLOYMENT_URL
fi

echo -e "${GREEN}✅ Frontend deployed to: $DEPLOYMENT_URL${NC}"

# Add custom domain
echo ""
echo "🔗 Adding custom domain: $FRONTEND_SUBDOMAIN"
vercel domains add $FRONTEND_SUBDOMAIN 2>/dev/null || echo "Domain may already be configured"

# Get Vercel DNS info
echo ""
echo -e "${GREEN}✅ Frontend deployment complete!${NC}"
VERCEL_CNAME="cname.vercel-dns.com"

cd ..

# ============================================
# STEP 3: DEPLOY BACKEND TO RAILWAY
# ============================================
echo ""
echo -e "${CYAN}Step 3: Deploying Backend to Railway${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd backend-express

# Create Railway configuration
cat > railway.json << EOF
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "numReplicas": 1,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
EOF

echo "🚀 Setting up Railway deployment..."
echo ""
echo -e "${YELLOW}Railway Login Required:${NC}"
echo "A browser will open for authentication..."
echo ""

# Login to Railway
railway login

echo ""
echo "📝 Creating new Railway project..."

# Initialize Railway project
railway init -n mortgage-guardian-backend

echo ""
echo "🚀 Deploying to Railway..."
railway up

echo ""
echo "🔗 Setting up custom domain..."

# Try to add domain (may require manual step)
railway domain add $API_SUBDOMAIN 2>/dev/null || {
    echo ""
    echo -e "${YELLOW}⚠️  Please add custom domain manually:${NC}"
    echo "1. Open: https://railway.app/dashboard"
    echo "2. Select your project: mortgage-guardian-backend"
    echo "3. Go to Settings → Domains"
    echo "4. Add: $API_SUBDOMAIN"
    echo ""
    read -p "Press Enter after adding domain in Railway..."
}

# Get Railway URL
echo ""
echo "📝 Getting Railway URL..."
RAILWAY_URL=$(railway status 2>/dev/null | grep -o 'https://[^ ]*' | head -1)

if [ -z "$RAILWAY_URL" ]; then
    echo -e "${YELLOW}Enter your Railway URL (e.g., your-app.up.railway.app):${NC}"
    read RAILWAY_URL
fi

echo -e "${GREEN}✅ Backend deployed to: $RAILWAY_URL${NC}"

cd ..

# ============================================
# STEP 4: GENERATE DNS RECORDS
# ============================================
echo ""
echo -e "${CYAN}Step 4: DNS Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create DNS records file
cat > DNS_RECORDS.txt << EOF
════════════════════════════════════════════════════════════
     DNS RECORDS FOR GODADDY / CLOUDFLARE
════════════════════════════════════════════════════════════

COPY THESE RECORDS TO YOUR DNS PROVIDER:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FOR CLOUDFLARE (Recommended):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Type    Name    Content                     Proxy
----    ----    -------                     -----
CNAME   @       $VERCEL_CNAME              ✅ On
CNAME   www     $VERCEL_CNAME              ✅ On
CNAME   app     $VERCEL_CNAME              ✅ On
CNAME   api     ${RAILWAY_URL#https://}    ✅ On

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FOR GODADDY DIRECT:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Type    Name    Value                       TTL
----    ----    -----                       ---
CNAME   @       $VERCEL_CNAME              600
CNAME   www     $VERCEL_CNAME              600
CNAME   app     $VERCEL_CNAME              600
CNAME   api     ${RAILWAY_URL#https://}    600

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EMAIL FORWARDING (Cloudflare):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

In Cloudflare → Email → Email Routing:
• support@mortgageguardian.org → your-email@gmail.com
• info@mortgageguardian.org → your-email@gmail.com
• hello@mortgageguardian.org → your-email@gmail.com

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EMAIL FORWARDING (GoDaddy):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

In GoDaddy → Email Forwarding:
• support → your-email@gmail.com
• info → your-email@gmail.com
• hello → your-email@gmail.com

════════════════════════════════════════════════════════════
EOF

# Display DNS records
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}     📋 DNS RECORDS - COPY TO YOUR PROVIDER${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
echo ""

cat DNS_RECORDS.txt

# ============================================
# STEP 5: FINAL SETUP
# ============================================
echo ""
echo -e "${CYAN}Step 5: Final Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create environment sync script
cat > sync-env.sh << 'EOF'
#!/bin/bash
# Sync environment variables to Vercel and Railway

echo "Syncing environment variables..."

# Frontend (Vercel)
cd frontend
vercel env add NEXT_PUBLIC_API_URL production < <(echo "https://api.mortgageguardian.org")
vercel env add NEXT_PUBLIC_APP_URL production < <(echo "https://app.mortgageguardian.org")

# Backend (Railway)
cd ../backend-express
railway variables set NODE_ENV=production
railway variables set ALLOWED_ORIGINS=https://app.mortgageguardian.org,https://mortgageguardian.org

echo "✅ Environment variables synced!"
EOF

chmod +x sync-env.sh

# Create monitoring script
cat > check-status.sh << 'EOF'
#!/bin/bash
# Check deployment status

echo "🔍 Checking deployment status..."
echo ""

# Check frontend
echo "Frontend (Vercel):"
curl -s -o /dev/null -w "  Status: %{http_code}\n" https://app.mortgageguardian.org

# Check backend
echo "Backend (Railway):"
curl -s https://api.mortgageguardian.org/health 2>/dev/null | jq '.' || echo "  API not responding yet"

# Check DNS
echo ""
echo "DNS Status:"
dig +short app.mortgageguardian.org
EOF

chmod +x check-status.sh

# ============================================
# COMPLETION
# ============================================
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ AUTOMATED DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 NEXT STEPS (Manual):${NC}"
echo ""
echo "1️⃣  Copy DNS records from DNS_RECORDS.txt to:"
echo "    • Cloudflare: dash.cloudflare.com"
echo "    • OR GoDaddy: godaddy.com → Domains → DNS"
echo ""
echo "2️⃣  Wait for DNS propagation (5-30 minutes)"
echo ""
echo "3️⃣  Test your deployment:"
echo "    ./check-status.sh"
echo ""
echo -e "${GREEN}Your sites will be available at:${NC}"
echo "  🌐 https://mortgageguardian.org"
echo "  📱 https://app.mortgageguardian.org"
echo "  🔧 https://api.mortgageguardian.org"
echo ""
echo -e "${BLUE}📧 Email will forward to your personal email${NC}"
echo "  support@mortgageguardian.org"
echo "  info@mortgageguardian.org"
echo ""
echo -e "${MAGENTA}DNS records saved to: DNS_RECORDS.txt${NC}"
echo ""
echo -e "${GREEN}🎉 Deployment automation complete!${NC}"