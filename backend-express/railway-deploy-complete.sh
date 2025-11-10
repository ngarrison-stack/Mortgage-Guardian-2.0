#!/bin/bash

# Railway Complete Deployment Script for Mortgage Guardian Backend
# This script deploys the backend and configures all services

set -e

echo "=========================================="
echo "Railway Deployment - Mortgage Guardian"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Change to backend directory
cd /Users/nickgarrison/Documents/GitHub/Mortgage-Guardian-2.0-Clean/backend-express

# Check if Railway CLI is installed and authenticated
echo -e "${BLUE}Checking Railway CLI...${NC}"
if ! command -v railway &> /dev/null; then
    echo -e "${RED}Railway CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check Railway authentication
echo -e "${BLUE}Verifying Railway authentication...${NC}"
railway whoami || {
    echo -e "${RED}Not authenticated with Railway. Please run: railway login${NC}"
    exit 1
}

# Show current project status
echo -e "${BLUE}Current Railway project status:${NC}"
railway status

echo ""
echo -e "${YELLOW}Step 1: Loading environment variables from .env.railway.local${NC}"

# Read .env.railway.local and prepare variables
if [ ! -f ".env.railway.local" ]; then
    echo -e "${RED}Error: .env.railway.local not found${NC}"
    exit 1
fi

# Extract variables (excluding comments and empty lines)
ENV_VARS=$(grep -v '^#' .env.railway.local | grep -v '^$' | grep '=' || true)

echo -e "${GREEN}Found $(echo "$ENV_VARS" | wc -l) environment variables${NC}"

echo ""
echo -e "${YELLOW}Step 2: Deploying backend service${NC}"

# Try to deploy with service name
echo -e "${BLUE}Deploying code to Railway...${NC}"
railway up --detach --service backend 2>/dev/null || railway up --detach || {
    echo -e "${YELLOW}Creating new service and deploying...${NC}"
    # If no service exists, Railway will create one
    railway up
}

echo ""
echo -e "${YELLOW}Step 3: Setting environment variables${NC}"

# Set each environment variable
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    if [[ -z "$key" ]] || [[ "$key" == \#* ]]; then
        continue
    fi

    # Clean up the key and value
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    # Skip if key or value is empty
    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
        continue
    fi

    # Set the variable
    echo -e "${BLUE}Setting: $key${NC}"
    railway variables --set "$key=$value" 2>/dev/null || echo -e "${YELLOW}  (may already exist)${NC}"
done <<< "$ENV_VARS"

echo ""
echo -e "${YELLOW}Step 4: Generating public domain${NC}"

# Generate a Railway domain
echo -e "${BLUE}Generating public domain...${NC}"
DOMAIN_OUTPUT=$(railway domain 2>&1 || true)
echo "$DOMAIN_OUTPUT"

# Extract the domain from output
RAILWAY_DOMAIN=$(echo "$DOMAIN_OUTPUT" | grep -oE '[a-z0-9-]+\.up\.railway\.app' | head -1 || true)

if [ -z "$RAILWAY_DOMAIN" ]; then
    echo -e "${YELLOW}Attempting to create new domain...${NC}"
    railway domain --service backend 2>&1 || railway domain 2>&1
    sleep 2
    DOMAIN_OUTPUT=$(railway domain 2>&1 || true)
    RAILWAY_DOMAIN=$(echo "$DOMAIN_OUTPUT" | grep -oE '[a-z0-9-]+\.up\.railway\.app' | head -1 || true)
fi

echo ""
echo -e "${YELLOW}Step 5: Checking deployment status${NC}"

# Get deployment logs
echo -e "${BLUE}Recent deployment logs:${NC}"
railway logs --deployment latest 2>/dev/null || echo -e "${YELLOW}Logs will be available once deployment completes${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "=========================================="
echo ""

if [ -n "$RAILWAY_DOMAIN" ]; then
    echo -e "${GREEN}Your backend is deployed at:${NC}"
    echo -e "${BLUE}https://$RAILWAY_DOMAIN${NC}"
    echo ""
    echo -e "${GREEN}Health check endpoint:${NC}"
    echo -e "${BLUE}https://$RAILWAY_DOMAIN/health${NC}"
    echo ""
    echo -e "${YELLOW}Testing health endpoint in 10 seconds...${NC}"
    sleep 10
    echo ""
    curl -s "https://$RAILWAY_DOMAIN/health" | jq . || curl -s "https://$RAILWAY_DOMAIN/health" || echo -e "${YELLOW}Service may still be starting up${NC}"
else
    echo -e "${YELLOW}Domain not yet available. Check Railway dashboard:${NC}"
    echo -e "${BLUE}https://railway.app/dashboard${NC}"
fi

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Update your iOS app with the backend URL"
echo "2. Test the /health endpoint"
echo "3. Test Claude AI endpoint: POST /api/v1/ai/claude/analyze"
echo "4. Monitor logs: railway logs"
echo ""

# Save the domain to a file
if [ -n "$RAILWAY_DOMAIN" ]; then
    echo "https://$RAILWAY_DOMAIN" > RAILWAY_URL.txt
    echo -e "${GREEN}Backend URL saved to RAILWAY_URL.txt${NC}"
fi
