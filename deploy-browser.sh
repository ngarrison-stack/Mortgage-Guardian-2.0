#!/bin/bash

# Browser-based deployment (no token needed)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🌐 Browser-Based Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

cd backend-express

echo -e "${YELLOW}This will open your browser for authentication.${NC}"
echo -e "${BLUE}You'll need to:${NC}"
echo "  1. Login to Railway"
echo "  2. Select or create a project"
echo "  3. Deploy the backend"
echo ""
read -p "Press Enter to continue..."

# Step 1: Login via browser
echo -e "${BLUE}Opening browser for Railway login...${NC}"
railway login

if [ $? -ne 0 ]; then
    echo -e "${RED}Login failed. Please try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Logged in successfully${NC}"

# Step 2: Initialize project
echo -e "${BLUE}Creating Railway project...${NC}"
railway init mortgage-guardian-backend

# Step 3: Deploy
echo -e "${BLUE}Deploying backend...${NC}"
railway up -d

# Step 4: Add services
echo -e "${YELLOW}After deployment completes, run these commands:${NC}"
echo ""
echo "# Add PostgreSQL:"
echo "railway add postgres"
echo ""
echo "# Add Redis:"
echo "railway add redis"
echo ""
echo "# Set environment variables:"
cat << 'EOF'
railway variables set NODE_ENV=production
railway variables set JWT_SECRET=KJPZqWa7WKWV0EjDKU5EmVDxUi3WJyso4OGKcPFFQa8=
railway variables set ENCRYPTION_KEY=MzrdN6qF4aZWY4VwzEIyHjFdUy7OeAq1wC/SZyx7HqA=
railway variables set ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org"
railway variables set RATE_LIMIT_WINDOW_MS=900000
railway variables set RATE_LIMIT_MAX_REQUESTS=100
EOF

echo ""
echo "# Generate domain:"
echo "railway domain"
echo ""
echo -e "${GREEN}Then update your frontend with the Railway URL!${NC}"