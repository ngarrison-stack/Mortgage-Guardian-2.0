#!/bin/bash

# Railway Backend Deployment Script
# This script guides you through deploying the backend to Railway

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚂 Railway Backend Deployment Guide${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}Railway CLI not found. Installing...${NC}"
    npm install -g @railway/cli
else
    echo -e "${GREEN}✅ Railway CLI is installed${NC}"
fi

cd backend-express

echo ""
echo -e "${BLUE}Step 1: Login to Railway${NC}"
echo -e "${YELLOW}This will open your browser for authentication${NC}"
railway login

echo ""
echo -e "${BLUE}Step 2: Initialize Railway Project${NC}"
railway init

echo ""
echo -e "${BLUE}Step 3: Link to GitHub (optional but recommended)${NC}"
echo -e "${YELLOW}You can also deploy directly without GitHub${NC}"
railway link

echo ""
echo -e "${BLUE}Step 4: Add PostgreSQL Database${NC}"
railway add -d postgresql

echo ""
echo -e "${BLUE}Step 5: Add Redis Cache${NC}"
railway add -d redis

echo ""
echo -e "${BLUE}Step 6: Deploy the Backend${NC}"
railway up

echo ""
echo -e "${GREEN}Getting deployment information...${NC}"
sleep 5

# Get the deployment URL
echo ""
echo -e "${BLUE}Step 7: Generate Domain${NC}"
railway domain

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ Backend Deployment Started!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Go to https://railway.app/dashboard"
echo "2. Click on your project"
echo "3. Go to the Variables tab"
echo "4. Add these environment variables:"
echo ""
echo -e "${BLUE}Required Variables:${NC}"
echo "  NODE_ENV=production"
echo "  JWT_SECRET=$(openssl rand -base64 32)"
echo "  ENCRYPTION_KEY=$(openssl rand -base64 32)"
echo "  ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org"
echo ""
echo -e "${BLUE}API Keys (from your accounts):${NC}"
echo "  ANTHROPIC_API_KEY=your-claude-api-key"
echo "  PLAID_CLIENT_ID=your-plaid-client-id"
echo "  PLAID_SECRET=your-plaid-secret"
echo "  PLAID_ENV=sandbox"
echo ""
echo -e "${BLUE}Optional (if using Supabase):${NC}"
echo "  SUPABASE_URL=your-project-url"
echo "  SUPABASE_ANON_KEY=your-anon-key"
echo ""
echo -e "${GREEN}Railway will automatically provide:${NC}"
echo "  DATABASE_URL (PostgreSQL connection)"
echo "  REDIS_URL (Redis connection)"
echo "  PORT (server port)"
echo ""
echo -e "${CYAN}Once variables are added, Railway will automatically redeploy!${NC}"
echo ""
echo -e "${YELLOW}Save your backend URL to update the frontend:${NC}"
railway domain