#!/bin/bash

# Quick Deploy Script - With Anthropic Key Already Configured
# Run this after getting your Railway token

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║         MORTGAGE GUARDIAN - QUICK DEPLOYMENT                ║
║              Anthropic Key Already Configured               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${GREEN}✓ Anthropic API key already configured${NC}"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${RED}✗ Railway CLI not found${NC}"
    echo ""
    echo "Installing Railway CLI..."
    npm install -g @railway/cli
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get Railway Token
echo -e "${BOLD}Enter Your Railway Token${NC}"
echo ""
echo "Get your token from: https://railway.app/account/tokens"
echo -e "${YELLOW}Note: Token will be hidden as you type${NC}"
echo ""
read -s -p "Railway Token: " RAILWAY_TOKEN_INPUT
echo ""
echo ""

# Validate and export token
if [ ! -z "$RAILWAY_TOKEN_INPUT" ]; then
    export RAILWAY_TOKEN="$RAILWAY_TOKEN_INPUT"

    # Test the token
    echo "Validating token..."
    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓ Railway token authenticated successfully!${NC}"
        railway whoami
    else
        echo -e "${YELLOW}⚠ Could not verify token, but proceeding...${NC}"
    fi
else
    echo -e "${RED}✗ No token provided${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Optional: Plaid Configuration
echo -e "${BOLD}Plaid Banking Integration (Optional)${NC}"
echo ""
read -p "Configure Plaid now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Plaid Client ID:"
    read PLAID_CLIENT_INPUT

    echo "Plaid Secret (hidden):"
    read -s PLAID_SECRET_INPUT
    echo ""

    echo "Environment (sandbox/development/production) [default: sandbox]:"
    read PLAID_ENV_INPUT
    PLAID_ENV_INPUT="${PLAID_ENV_INPUT:-sandbox}"

    if [ ! -z "$PLAID_CLIENT_INPUT" ]; then
        sed -i.bak "s|PLAID_CLIENT_ID=.*|PLAID_CLIENT_ID=$PLAID_CLIENT_INPUT|" .env.railway.local
        sed -i.bak "s|PLAID_SECRET=.*|PLAID_SECRET=$PLAID_SECRET_INPUT|" .env.railway.local
        sed -i.bak "s|PLAID_ENV=.*|PLAID_ENV=$PLAID_ENV_INPUT|" .env.railway.local
        echo -e "${GREEN}✓ Plaid configured${NC}"
        export PLAID_CLIENT_ID="$PLAID_CLIENT_INPUT"
        export PLAID_SECRET="$PLAID_SECRET_INPUT"
        export PLAID_ENV="$PLAID_ENV_INPUT"
    fi
else
    echo -e "${CYAN}Skipping Plaid (can be added later via Railway dashboard)${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Deployment Summary
echo -e "${BOLD}${BLUE}Deployment Configuration${NC}"
echo ""
echo -e "${CYAN}✓${NC} Express.js Backend API"
echo -e "${CYAN}✓${NC} PostgreSQL Database (auto-provisioned)"
echo -e "${CYAN}✓${NC} Redis Cache (auto-provisioned)"
echo -e "${CYAN}✓${NC} Claude AI Integration (Anthropic)"
if [ ! -z "$PLAID_CLIENT_ID" ]; then
    echo -e "${CYAN}✓${NC} Plaid Banking Integration"
fi
echo -e "${CYAN}✓${NC} HTTPS with SSL (automatic)"
echo -e "${CYAN}✓${NC} Production Environment"
echo ""

read -p "Ready to deploy? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BOLD}${GREEN}🚀 Starting Railway Deployment...${NC}"
echo ""

# Load environment
source export-env.sh

# Run deployment
echo -e "${CYAN}Creating Railway project and deploying...${NC}"
echo ""

# Deploy using the main deployment script
if ./deploy-railway.sh; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           DEPLOYMENT SUCCESSFUL! 🎉                   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Try to get the deployment URL
    sleep 3
    DEPLOY_URL=$(railway status --json 2>/dev/null | grep -o 'https://[^"]*' | head -1 || echo "")

    if [ ! -z "$DEPLOY_URL" ]; then
        echo -e "${BOLD}${CYAN}Your backend is live at:${NC}"
        echo -e "${BOLD}${GREEN}$DEPLOY_URL${NC}"
        echo ""

        # Test the deployment
        echo "Testing health endpoint..."
        if curl -s "$DEPLOY_URL/health" | grep -q "ok"; then
            echo -e "${GREEN}✓ Backend is responding correctly!${NC}"
        else
            echo -e "${YELLOW}⚠ Health check pending (may take a minute to start)${NC}"
        fi
    else
        echo "Run 'railway status' to get your deployment URL"
    fi

    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "1. View logs:        railway logs"
    echo "2. Open dashboard:   railway open"
    echo "3. Get domain:       railway domain"
    echo "4. Test endpoints:   ./test-deployment.sh"
    echo ""
    echo -e "${YELLOW}Important:${NC} Save your deployment URL for frontend configuration!"
    echo ""

    # Save deployment URL if we got it
    if [ ! -z "$DEPLOY_URL" ]; then
        echo "$DEPLOY_URL" > deployment-url.txt
        echo -e "${GREEN}✓ URL saved to deployment-url.txt${NC}"
    fi
else
    echo ""
    echo -e "${RED}Deployment encountered issues${NC}"
    echo ""
    echo "Check logs with: railway logs"
    echo "View status with: railway status"
    exit 1
fi