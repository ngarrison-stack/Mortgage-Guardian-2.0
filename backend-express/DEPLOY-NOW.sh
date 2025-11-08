#!/bin/bash

# ============================================
# MORTGAGE GUARDIAN - DEPLOY NOW WIZARD
# Interactive deployment helper
# ============================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
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
║              MORTGAGE GUARDIAN DEPLOYMENT                   ║
║              Railway Deployment Wizard                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}This wizard will guide you through deploying your backend to Railway.${NC}"
echo ""

# ============================================
# STEP 1: CHECK PREREQUISITES
# ============================================

echo -e "${BOLD}${BLUE}[STEP 1/5] Checking Prerequisites${NC}"
echo ""

# Check Railway CLI
if command -v railway &> /dev/null; then
    echo -e "${GREEN}✓${NC} Railway CLI installed ($(railway --version))"
else
    echo -e "${RED}✗${NC} Railway CLI not found"
    echo ""
    echo "Install with: npm install -g @railway/cli"
    exit 1
fi

# Check if we have generated keys
if [ -f ".env.railway.local" ]; then
    echo -e "${GREEN}✓${NC} Environment configuration exists"
else
    echo -e "${YELLOW}⚠${NC} Running setup to generate secure keys..."
    ./setup-env.sh
fi

# Check required files
if [ -f "deploy-railway.sh" ] && [ -f "export-env.sh" ]; then
    echo -e "${GREEN}✓${NC} Deployment scripts ready"
else
    echo -e "${RED}✗${NC} Deployment scripts missing"
    exit 1
fi

echo ""
read -p "Press Enter to continue..."

# ============================================
# STEP 2: RAILWAY TOKEN
# ============================================

clear
echo -e "${BOLD}${BLUE}[STEP 2/5] Railway Authentication${NC}"
echo ""

if [ ! -z "$RAILWAY_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} RAILWAY_TOKEN already set in environment"
    echo ""
    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓${NC} Token is valid!"
        railway whoami
    else
        echo -e "${RED}✗${NC} Token appears invalid"
        unset RAILWAY_TOKEN
    fi
fi

if [ -z "$RAILWAY_TOKEN" ]; then
    echo "You need a Railway API token to deploy."
    echo ""
    echo -e "${CYAN}To get your token:${NC}"
    echo "1. Visit: https://railway.app/account/tokens"
    echo "2. Click 'Create Token'"
    echo "3. Copy the token"
    echo ""

    read -p "Do you have a Railway token? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Please paste your Railway token:"
        read -s RAILWAY_TOKEN_INPUT
        export RAILWAY_TOKEN="$RAILWAY_TOKEN_INPUT"

        echo ""
        if railway whoami &> /dev/null; then
            echo -e "${GREEN}✓${NC} Token validated successfully!"
        else
            echo -e "${RED}✗${NC} Token validation failed"
            echo "Please check your token and try again"
            exit 1
        fi
    else
        echo ""
        echo "Please get a Railway token and run this script again."
        echo "Visit: https://railway.app/account/tokens"
        exit 1
    fi
fi

echo ""
read -p "Press Enter to continue..."

# ============================================
# STEP 3: API KEYS
# ============================================

clear
echo -e "${BOLD}${BLUE}[STEP 3/5] API Key Configuration${NC}"
echo ""

echo "Checking your API keys in .env.railway.local..."
echo ""

# Check Anthropic API key
ANTHROPIC_KEY=$(grep "^ANTHROPIC_API_KEY=" .env.railway.local | cut -d'=' -f2)

if [[ "$ANTHROPIC_KEY" == "sk-ant-api03-your-key-here" ]] || [ -z "$ANTHROPIC_KEY" ]; then
    echo -e "${YELLOW}⚠${NC} Anthropic API key not configured"
    echo ""
    echo "The backend needs an Anthropic API key for Claude AI analysis."
    echo "Get one from: https://console.anthropic.com"
    echo ""

    read -p "Do you have an Anthropic API key to add now? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Please paste your Anthropic API key (starts with sk-ant-):"
        read -s ANTHROPIC_KEY_INPUT

        # Update .env.railway.local
        if [[ "$ANTHROPIC_KEY_INPUT" == sk-ant-* ]]; then
            sed -i.bak "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY_INPUT|" .env.railway.local
            echo ""
            echo -e "${GREEN}✓${NC} Anthropic API key added"
            export ANTHROPIC_API_KEY="$ANTHROPIC_KEY_INPUT"
        else
            echo ""
            echo -e "${RED}✗${NC} Invalid key format (should start with sk-ant-)"
            echo "You can add it later with: railway variables set ANTHROPIC_API_KEY=your-key"
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠${NC} You can add it after deployment:"
        echo "   railway variables set ANTHROPIC_API_KEY=your-key"
    fi
else
    echo -e "${GREEN}✓${NC} Anthropic API key configured"
    export ANTHROPIC_API_KEY="$ANTHROPIC_KEY"
fi

echo ""

# Check Plaid (optional)
PLAID_CLIENT_ID=$(grep "^PLAID_CLIENT_ID=" .env.railway.local | cut -d'=' -f2)

if [[ "$PLAID_CLIENT_ID" == "your-plaid-client-id" ]] || [ -z "$PLAID_CLIENT_ID" ]; then
    echo -e "${YELLOW}⚠${NC} Plaid credentials not configured (optional)"
    echo ""
    read -p "Do you want to configure Plaid now? (y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Plaid Client ID:"
        read PLAID_CLIENT_ID_INPUT
        echo "Plaid Secret:"
        read -s PLAID_SECRET_INPUT
        echo ""
        echo "Plaid Environment (sandbox/development/production):"
        read PLAID_ENV_INPUT

        if [ ! -z "$PLAID_CLIENT_ID_INPUT" ]; then
            sed -i.bak "s|PLAID_CLIENT_ID=.*|PLAID_CLIENT_ID=$PLAID_CLIENT_ID_INPUT|" .env.railway.local
            sed -i.bak "s|PLAID_SECRET=.*|PLAID_SECRET=$PLAID_SECRET_INPUT|" .env.railway.local
            sed -i.bak "s|PLAID_ENV=.*|PLAID_ENV=${PLAID_ENV_INPUT:-sandbox}|" .env.railway.local
            echo -e "${GREEN}✓${NC} Plaid credentials added"
            export PLAID_CLIENT_ID="$PLAID_CLIENT_ID_INPUT"
            export PLAID_SECRET="$PLAID_SECRET_INPUT"
            export PLAID_ENV="${PLAID_ENV_INPUT:-sandbox}"
        fi
    fi
else
    echo -e "${GREEN}✓${NC} Plaid credentials configured"
fi

echo ""
read -p "Press Enter to continue..."

# ============================================
# STEP 4: DEPLOYMENT
# ============================================

clear
echo -e "${BOLD}${BLUE}[STEP 4/5] Deploying to Railway${NC}"
echo ""

echo "Ready to deploy with the following configuration:"
echo ""
echo -e "${CYAN}Project:${NC} mortgage-guardian-backend"
echo -e "${CYAN}Services:${NC} Backend API, PostgreSQL, Redis"
echo -e "${CYAN}Region:${NC} US (automatic)"
echo -e "${CYAN}HTTPS:${NC} Enabled (automatic)"
echo ""

read -p "Start deployment? (y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Deployment cancelled. Run this script again when ready."
    exit 0
fi

echo ""
echo -e "${BOLD}${GREEN}Starting deployment...${NC}"
echo ""

# Load environment variables
source export-env.sh

# Run deployment
if ./deploy-railway.sh; then
    DEPLOYMENT_SUCCESS=true
else
    DEPLOYMENT_SUCCESS=false
fi

echo ""
read -p "Press Enter to continue..."

# ============================================
# STEP 5: VERIFY & TEST
# ============================================

clear
echo -e "${BOLD}${BLUE}[STEP 5/5] Verification & Testing${NC}"
echo ""

if [ "$DEPLOYMENT_SUCCESS" = true ]; then
    echo -e "${GREEN}✓${NC} Deployment completed successfully!"
    echo ""

    # Get deployment URL
    DEPLOY_URL=$(railway status --json 2>/dev/null | grep -o 'https://[^"]*' | head -1 || echo "")

    if [ ! -z "$DEPLOY_URL" ]; then
        echo -e "${CYAN}Deployment URL:${NC} $DEPLOY_URL"
        echo ""

        read -p "Run health check now? (y/n): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Running tests..."
            echo ""
            ./test-deployment.sh "$DEPLOY_URL"
        fi
    else
        echo "Run this command to get your URL:"
        echo "  railway status"
    fi
else
    echo -e "${RED}✗${NC} Deployment encountered errors"
    echo ""
    echo "Check logs with: railway logs"
fi

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}             DEPLOYMENT WIZARD COMPLETE!              ${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -z "$DEPLOY_URL" ]; then
    echo -e "${CYAN}Your backend is live at:${NC}"
    echo -e "${BOLD}$DEPLOY_URL${NC}"
    echo ""
fi

echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "1. View logs:"
echo "   railway logs"
echo ""
echo "2. Test endpoints:"
echo "   ./test-deployment.sh"
echo ""
echo "3. Open Railway dashboard:"
echo "   railway open"
echo ""
echo "4. Update frontend API URL to your Railway URL"
echo ""
echo "5. Add custom domain (optional):"
echo "   railway domain"
echo ""

if [ ! -z "$DEPLOY_URL" ]; then
    echo -e "${CYAN}Quick test command:${NC}"
    echo "curl $DEPLOY_URL/health"
    echo ""
fi

echo -e "${CYAN}Documentation:${NC}"
echo "  RAILWAY-DEPLOYMENT.md - Full guide"
echo "  QUICK-START.md - Quick reference"
echo ""

echo -e "${GREEN}Happy deploying! 🚀${NC}"
echo ""
