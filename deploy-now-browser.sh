#!/bin/bash

# IMMEDIATE DEPLOYMENT - Browser Auth

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚀 DEPLOYING BACKEND NOW${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

cd backend-express

echo -e "${YELLOW}This will open your browser to login to Railway.${NC}"
echo -e "${BLUE}After login, deployment will proceed automatically.${NC}"
echo ""
echo -e "${GREEN}Press Enter to start deployment...${NC}"
read

# Login via browser
echo -e "${BLUE}Opening browser for Railway login...${NC}"
railway login

echo -e "${GREEN}✓ Login successful!${NC}"
echo ""

# Create and deploy
echo -e "${BLUE}Creating Railway project...${NC}"
railway init mortgage-guardian-backend

echo -e "${BLUE}Deploying backend...${NC}"
railway up --detach

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ BACKEND DEPLOYED!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Now run these commands to complete setup:${NC}"
echo ""
echo "# 1. Add PostgreSQL:"
echo -e "${CYAN}railway add postgres${NC}"
echo ""
echo "# 2. Add Redis:"
echo -e "${CYAN}railway add redis${NC}"
echo ""
echo "# 3. Set environment variables (copy & paste all):"
cat << 'EOF'
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
railway variables set ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
railway variables set ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org"
railway variables set RATE_LIMIT_WINDOW_MS=900000
railway variables set RATE_LIMIT_MAX_REQUESTS=100
EOF
echo ""
echo "# 4. Get your URL:"
echo -e "${CYAN}railway domain${NC}"
echo ""
echo -e "${GREEN}Your backend will be live in 2-3 minutes!${NC}"