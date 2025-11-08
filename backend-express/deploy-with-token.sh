#!/bin/bash

# Direct Railway deployment with token

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Starting Railway deployment with token...${NC}"

# Set the Railway token
export RAILWAY_TOKEN="a66fbfff-5321-4e5f-add5-a2fae78d081f"

# Check if token is valid
echo -e "${BLUE}Validating Railway token...${NC}"
railway whoami

if [ $? -ne 0 ]; then
    echo -e "${RED}Invalid Railway token. Please check and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Token valid${NC}"

# Initialize new project
echo -e "${BLUE}Creating new Railway project...${NC}"
railway init --name mortgage-guardian-backend

# Link the project
echo -e "${BLUE}Linking project...${NC}"
railway link

# Add PostgreSQL
echo -e "${BLUE}Adding PostgreSQL database...${NC}"
railway add --database postgres

# Add Redis
echo -e "${BLUE}Adding Redis cache...${NC}"
railway add --database redis

# Set environment variables
echo -e "${BLUE}Setting environment variables...${NC}"

# Core settings
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
railway variables set ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
railway variables set ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org,https://mortgage-guardian-app.netlify.app
railway variables set RATE_LIMIT_WINDOW_MS=900000
railway variables set RATE_LIMIT_MAX_REQUESTS=100

# Placeholder API keys (update these with real values)
railway variables set ANTHROPIC_API_KEY=sk-ant-api03-placeholder
railway variables set PLAID_CLIENT_ID=placeholder
railway variables set PLAID_SECRET=placeholder
railway variables set PLAID_ENV=sandbox

echo -e "${GREEN}✓ Environment variables set${NC}"

# Deploy the application
echo -e "${BLUE}Deploying backend...${NC}"
railway up -d

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
sleep 30

# Get the deployment URL
echo -e "${BLUE}Getting deployment URL...${NC}"
DEPLOYMENT_URL=$(railway status --json | grep -o '"url":"[^"]*' | grep -o '[^"]*$' | head -1)

if [ -z "$DEPLOYMENT_URL" ]; then
    echo -e "${YELLOW}Generating domain...${NC}"
    railway domain
    sleep 5
    DEPLOYMENT_URL=$(railway status --json | grep -o '"url":"[^"]*' | grep -o '[^"]*$' | head -1)
fi

echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Backend URL: https://${DEPLOYMENT_URL}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update ANTHROPIC_API_KEY with your real key in Railway dashboard"
echo "2. Update PLAID credentials if using banking features"
echo "3. Test the health endpoint: curl https://${DEPLOYMENT_URL}/health"
echo ""
echo -e "${BLUE}Railway Dashboard: https://railway.app/dashboard${NC}"