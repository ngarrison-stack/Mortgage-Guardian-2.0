#!/bin/bash

# Railway Authentication Fix Script
# Handles common Railway API issues

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}Railway Authentication Fix${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Common Railway API issues and solutions:${NC}"
echo ""

# Option 1: Browser Login
echo -e "${BOLD}Option 1: Browser-based Login${NC}"
echo "This often works when token authentication fails"
echo ""
echo "Run: ${CYAN}railway login${NC}"
echo "This will open your browser for authentication"
echo ""
read -p "Try browser login? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Opening browser for Railway login..."
    railway login

    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓ Login successful!${NC}"
        railway whoami
        echo ""
        echo "Now run: ${CYAN}./deploy-railway.sh${NC}"
        exit 0
    else
        echo -e "${RED}✗ Login still failing${NC}"
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Option 2: Manual Token
echo -e "${BOLD}Option 2: Manual Token Configuration${NC}"
echo ""
echo "1. Go to: https://railway.app/account/tokens"
echo "2. Delete any old tokens"
echo "3. Create a NEW token"
echo "4. Try this format:"
echo ""
echo -e "${CYAN}export RAILWAY_TOKEN=\"your-token-here\"${NC}"
echo -e "${CYAN}railway whoami${NC}"
echo ""
read -p "Do you have a new token to try? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Paste your NEW Railway token:"
    read -s RAILWAY_TOKEN_NEW
    export RAILWAY_TOKEN="$RAILWAY_TOKEN_NEW"

    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓ Token works!${NC}"
        railway whoami
        echo ""
        echo "Token saved. Now run: ${CYAN}./deploy-railway.sh${NC}"
        exit 0
    else
        echo -e "${RED}✗ Token still not working${NC}"
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Option 3: Direct Railway Dashboard
echo -e "${BOLD}Option 3: Deploy via Railway Dashboard (No CLI)${NC}"
echo ""
echo "If the CLI keeps failing, use the web dashboard:"
echo ""
echo "1. Go to: ${CYAN}https://railway.app/new${NC}"
echo "2. Choose 'Deploy from GitHub repo'"
echo "3. Connect your GitHub account"
echo "4. Select repo: Mortgage-Guardian-2.0"
echo "5. Select directory: /backend-express"
echo "6. Railway will auto-detect Node.js"
echo "7. Add environment variables from .env.railway.local"
echo ""
echo -e "${GREEN}This bypasses all CLI authentication issues!${NC}"
echo ""
read -p "Open Railway dashboard now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v open &> /dev/null; then
        open "https://railway.app/new"
    else
        echo "Please open: https://railway.app/new"
    fi

    echo ""
    echo -e "${CYAN}After connecting GitHub, add these environment variables:${NC}"
    echo ""

    # Show the environment variables to add
    if [ -f ".env.railway.local" ]; then
        echo "Copy these to Railway's dashboard:"
        echo ""
        grep -E "^[A-Z]" .env.railway.local | grep -v "^#" | head -20
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Option 4: Alternative platforms
echo -e "${BOLD}Option 4: Alternative Deployment Platforms${NC}"
echo ""
echo "If Railway continues to have issues, try:"
echo ""
echo "1. ${CYAN}Render.com${NC} (Free tier available)"
echo "   - Visit: https://render.com"
echo "   - Click 'New' → 'Web Service'"
echo "   - Connect GitHub"
echo "   - Auto-deploys from GitHub"
echo ""
echo "2. ${CYAN}Heroku${NC} (Paid, but reliable)"
echo "   - Visit: https://heroku.com"
echo "   - Well-established platform"
echo "   - $7/month for hobby tier"
echo ""
echo "3. ${CYAN}Fly.io${NC} (Good free tier)"
echo "   - Visit: https://fly.io"
echo "   - Generous free tier"
echo "   - Global deployment"
echo ""

echo -e "${YELLOW}Would you like me to prepare deployment files for an alternative?${NC}"