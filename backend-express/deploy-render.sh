#!/bin/bash

# Deploy to Render.com - Alternative to Railway
# Simpler deployment with free tier

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║         RENDER.COM DEPLOYMENT - EASY ALTERNATIVE            ║
║              No CLI Authentication Required!                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${GREEN}Render.com Benefits:${NC}"
echo "✓ Free tier with 750 hours/month"
echo "✓ Automatic SSL certificates"
echo "✓ PostgreSQL database included"
echo "✓ Deploy from GitHub (no CLI needed)"
echo "✓ Environment variables via dashboard"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}Step-by-Step Render Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}Step 1: Create render.yaml${NC}"
echo "Creating Render blueprint configuration..."
echo ""

# Create render.yaml
cat > render.yaml << 'YAML'
services:
  - type: web
    name: mortgage-guardian-backend
    runtime: node
    region: oregon
    plan: free
    buildCommand: npm install
    startCommand: npm start
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: JWT_SECRET
        generateValue: true
      - key: ENCRYPTION_KEY
        generateValue: true
      - key: REFRESH_TOKEN_SECRET
        generateValue: true
      - key: ANTHROPIC_API_KEY
        sync: false
      - key: PLAID_CLIENT_ID
        sync: false
      - key: PLAID_SECRET
        sync: false
      - key: PLAID_ENV
        value: sandbox
      - key: ALLOWED_ORIGINS
        value: https://mortgageguardian.org,https://www.mortgageguardian.org
      - key: RATE_LIMIT_WINDOW_MS
        value: 900000
      - key: RATE_LIMIT_MAX_REQUESTS
        value: 100

databases:
  - name: mortgage-guardian-db
    plan: free
    databaseName: mortgage_guardian
    user: mortgage_admin

  - name: mortgage-guardian-redis
    plan: free
    type: redis
YAML

echo -e "${GREEN}✓ render.yaml created${NC}"
echo ""

echo -e "${BOLD}Step 2: Manual Steps in Browser${NC}"
echo ""
echo "1. Go to: ${CYAN}https://dashboard.render.com/select-repo?type=blueprint${NC}"
echo ""
echo "2. Connect your GitHub account (if not already connected)"
echo ""
echo "3. Select repository: ${CYAN}Mortgage-Guardian-2.0${NC}"
echo ""
echo "4. Select branch: ${CYAN}main${NC}"
echo ""
echo "5. Root directory: ${CYAN}backend-express${NC}"
echo ""
echo "6. Click ${GREEN}'Apply'${NC}"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}Step 3: Add Your API Keys${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""
echo "After deployment starts, go to Environment tab and add:"
echo ""

# Read the local env file and display the keys to add
if [ -f ".env.railway.local" ]; then
    echo -e "${YELLOW}Copy these values:${NC}"
    echo ""
    echo "ANTHROPIC_API_KEY:"
    grep "^ANTHROPIC_API_KEY=" .env.railway.local | cut -d'=' -f2
    echo ""
    echo "PLAID_CLIENT_ID:"
    grep "^PLAID_CLIENT_ID=" .env.railway.local | cut -d'=' -f2
    echo ""
    echo "PLAID_SECRET:"
    grep "^PLAID_SECRET=" .env.railway.local | cut -d'=' -f2
    echo ""
fi

echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

read -p "Ready to open Render dashboard? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v open &> /dev/null; then
        open "https://dashboard.render.com/select-repo?type=blueprint"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "https://dashboard.render.com/select-repo?type=blueprint"
    else
        echo "Please open: https://dashboard.render.com/select-repo?type=blueprint"
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}After Deployment Completes:${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Your backend will be available at:"
echo -e "${CYAN}https://mortgage-guardian-backend.onrender.com${NC}"
echo ""
echo "Test with:"
echo "curl https://mortgage-guardian-backend.onrender.com/health"
echo ""
echo -e "${YELLOW}Note: Free tier may have 30-second cold starts${NC}"
echo -e "${YELLOW}First request after inactivity will be slow${NC}"
echo ""

# Save deployment info
echo "https://mortgage-guardian-backend.onrender.com" > render-deployment-url.txt
echo -e "${GREEN}✓ Expected URL saved to render-deployment-url.txt${NC}"