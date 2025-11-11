#!/bin/bash

# Mortgage Guardian Marketing Website - Netlify Deployment Script
# This script deploys the static marketing website to Netlify

set -e

echo "🚀 Starting Mortgage Guardian Marketing Website Deployment to Netlify"
echo "=================================================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo -e "${YELLOW}Netlify CLI not found. Installing...${NC}"
    npm install -g netlify-cli
fi

# Navigate to website directory
cd "$(dirname "$0")"

echo -e "${BLUE}Step 1: Checking Netlify authentication...${NC}"
netlify status || netlify login

echo -e "${BLUE}Step 2: Deploying website to Netlify...${NC}"
# Deploy to production
netlify deploy --dir=. --prod

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure custom domain (mortgageguardian.org) in Netlify dashboard"
echo "2. Update DNS records at your domain registrar (GoDaddy)"
echo "3. Enable HTTPS (automatic with Netlify)"
echo ""
echo "Visit: https://app.netlify.com to manage your deployment"
