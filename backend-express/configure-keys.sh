#!/bin/bash

# Configure Keys Script - Secure Input Helper
# This script helps you securely input your API keys

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}Railway & API Key Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Step 1: Railway Token
echo -e "${BOLD}Step 1: Railway Token${NC}"
echo ""
echo "Please paste your Railway token (from https://railway.app/account/tokens):"
echo -e "${YELLOW}Note: The token will be hidden as you type for security${NC}"
echo ""
read -s -p "Railway Token: " RAILWAY_TOKEN_INPUT
echo ""
echo ""

# Validate Railway token
if [[ "$RAILWAY_TOKEN_INPUT" == railway_* ]] || [[ "$RAILWAY_TOKEN_INPUT" == token_* ]]; then
    export RAILWAY_TOKEN="$RAILWAY_TOKEN_INPUT"
    echo -e "${GREEN}✓ Railway token format looks valid${NC}"

    # Test the token
    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓ Railway token authenticated successfully!${NC}"
        railway whoami
    else
        echo -e "${YELLOW}⚠ Could not verify token (may still work during deployment)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Token doesn't match expected format, but proceeding...${NC}"
    export RAILWAY_TOKEN="$RAILWAY_TOKEN_INPUT"
fi

echo ""
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
echo ""

# Step 2: Anthropic API Key
echo -e "${BOLD}Step 2: Anthropic API Key${NC}"
echo ""
echo "Please paste your Anthropic API key (starts with sk-ant-api03-):"
echo -e "${YELLOW}Note: The key will be hidden as you type for security${NC}"
echo ""
read -s -p "Anthropic API Key: " ANTHROPIC_KEY_INPUT
echo ""
echo ""

# Validate Anthropic key format
if [[ "$ANTHROPIC_KEY_INPUT" == sk-ant-api03-* ]]; then
    # Update .env.railway.local
    sed -i.bak "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY_INPUT|" .env.railway.local
    echo -e "${GREEN}✓ Anthropic API key configured successfully${NC}"
    export ANTHROPIC_API_KEY="$ANTHROPIC_KEY_INPUT"
else
    echo -e "${YELLOW}⚠ Warning: Key doesn't start with 'sk-ant-api03-'${NC}"
    echo "Proceeding anyway, but verify your key is correct..."
    sed -i.bak "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY_INPUT|" .env.railway.local
    export ANTHROPIC_API_KEY="$ANTHROPIC_KEY_INPUT"
fi

echo ""
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
echo ""

# Step 3: Optional Plaid Configuration
echo -e "${BOLD}Step 3: Plaid Configuration (Optional)${NC}"
echo ""
read -p "Do you want to configure Plaid banking integration? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your Plaid Client ID:"
    read PLAID_CLIENT_INPUT

    echo "Enter your Plaid Secret:"
    read -s PLAID_SECRET_INPUT
    echo ""

    echo "Enter Plaid Environment (sandbox/development/production) [default: sandbox]:"
    read PLAID_ENV_INPUT
    PLAID_ENV_INPUT="${PLAID_ENV_INPUT:-sandbox}"

    if [ ! -z "$PLAID_CLIENT_INPUT" ]; then
        sed -i.bak "s|PLAID_CLIENT_ID=.*|PLAID_CLIENT_ID=$PLAID_CLIENT_INPUT|" .env.railway.local
        sed -i.bak "s|PLAID_SECRET=.*|PLAID_SECRET=$PLAID_SECRET_INPUT|" .env.railway.local
        sed -i.bak "s|PLAID_ENV=.*|PLAID_ENV=$PLAID_ENV_INPUT|" .env.railway.local
        echo -e "${GREEN}✓ Plaid credentials configured${NC}"
        export PLAID_CLIENT_ID="$PLAID_CLIENT_INPUT"
        export PLAID_SECRET="$PLAID_SECRET_INPUT"
        export PLAID_ENV="$PLAID_ENV_INPUT"
    fi
else
    echo -e "${CYAN}Skipping Plaid configuration (can be added later)${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}         Configuration Complete!              ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""

echo "Your keys have been configured. Ready to deploy!"
echo ""
echo -e "${CYAN}Next step: Run the deployment${NC}"
echo ""
echo "Press Enter to start deployment, or Ctrl+C to exit..."
read

echo ""
echo -e "${BOLD}${BLUE}Starting Railway deployment...${NC}"
echo ""

# Run the deployment with the configured environment
./deploy-railway.sh