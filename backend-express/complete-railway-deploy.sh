#!/bin/bash

# Complete Railway Deployment
# Non-interactive deployment completion

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}Completing Railway Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Check if we're in the backend-express directory
if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: Must be run from backend-express directory${NC}"
    exit 1
fi

echo "Railway is connected. Now we need to:"
echo "1. Link to your project"
echo "2. Deploy the service"
echo "3. Generate a public domain"
echo ""

# Option 1: Use existing project
echo -e "${BOLD}Option 1: Use mortgage-guardian-backend project${NC}"
echo ""
echo "Run these commands:"
echo ""
echo -e "${CYAN}# Link to the project${NC}"
echo "railway link --project mortgage-guardian-backend"
echo ""
echo -e "${CYAN}# Deploy the service${NC}"
echo "railway up"
echo ""
echo -e "${CYAN}# Generate public domain${NC}"
echo "railway domain"
echo ""

echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""

# Option 2: Create new deployment
echo -e "${BOLD}Option 2: Create fresh deployment${NC}"
echo ""
echo "Run these commands:"
echo ""
echo -e "${CYAN}# Initialize new Railway project${NC}"
echo "railway init"
echo ""
echo -e "${CYAN}# Add PostgreSQL database${NC}"
echo "railway add postgresql"
echo ""
echo -e "${CYAN}# Add Redis${NC}"
echo "railway add redis"
echo ""
echo -e "${CYAN}# Deploy${NC}"
echo "railway up"
echo ""
echo -e "${CYAN}# Generate domain${NC}"
echo "railway domain"
echo ""

echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""

# Load environment variables
if [ -f ".env.railway.local" ]; then
    echo -e "${BOLD}Setting environment variables...${NC}"

    # Export them for Railway
    export $(grep -v '^#' .env.railway.local | xargs)

    echo -e "${GREEN}✓ Environment variables loaded${NC}"
    echo ""

    # Set Railway variables
    echo "After deployment, set these variables in Railway:"
    echo ""
    echo "railway variables set ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\""
    echo "railway variables set JWT_SECRET=\"$JWT_SECRET\""
    echo "railway variables set ENCRYPTION_KEY=\"$ENCRYPTION_KEY\""
    echo "railway variables set REFRESH_TOKEN_SECRET=\"$REFRESH_TOKEN_SECRET\""

    if [ ! -z "$PLAID_CLIENT_ID" ] && [ "$PLAID_CLIENT_ID" != "your-plaid-client-id" ]; then
        echo "railway variables set PLAID_CLIENT_ID=\"$PLAID_CLIENT_ID\""
        echo "railway variables set PLAID_SECRET=\"$PLAID_SECRET\""
        echo "railway variables set PLAID_ENV=\"$PLAID_ENV\""
    fi
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo ""

echo -e "${BOLD}${YELLOW}Quick Deploy Commands:${NC}"
echo ""
echo "Copy and run these commands:"
echo ""
echo -e "${GREEN}railway link --project mortgage-guardian-backend${NC}"
echo -e "${GREEN}railway up${NC}"
echo -e "${GREEN}railway domain${NC}"
echo ""

echo "After running these, you'll get a public URL like:"
echo "https://mortgage-guardian-backend-production.up.railway.app"
echo ""

echo -e "${CYAN}Need help?${NC}"
echo "1. Visit: https://railway.app/dashboard"
echo "2. Click on mortgage-guardian-backend project"
echo "3. Deploy manually from the dashboard"
echo ""