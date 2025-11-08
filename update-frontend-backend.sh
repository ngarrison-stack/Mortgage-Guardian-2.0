#!/bin/bash

# Update Frontend with Backend URL and Redeploy

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🔗 Connect Frontend to Backend${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get backend URL from user
echo -e "${YELLOW}Enter your Railway backend URL${NC}"
echo -e "${BLUE}Example: mortgage-guardian-backend-production.up.railway.app${NC}"
read -p "Backend URL (without https://): " BACKEND_URL

if [ -z "$BACKEND_URL" ]; then
    echo -e "${RED}❌ Backend URL is required${NC}"
    exit 1
fi

# Update frontend environment
cd frontend

echo -e "${BLUE}Updating frontend environment...${NC}"
cat > .env.production << EOF
# Backend API
NEXT_PUBLIC_API_URL=https://$BACKEND_URL
NEXT_PUBLIC_APP_URL=https://mortgageguardian.org

# Clerk Authentication (existing values)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_Y29tcGxldGUtYmFybmFjbGUtNjMuY2xlcmsuYWNjb3VudHMuZGV2JA
CLERK_SECRET_KEY=sk_test_qNQF9Hj5RLKbMKpL5FnqKJfRbYvPJGHQNxRkKp5RbY
EOF

echo -e "${GREEN}✅ Environment updated${NC}"

# Build the frontend
echo -e "${BLUE}Building frontend...${NC}"
npm run build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Deploy to Netlify
echo -e "${BLUE}Deploying to Netlify...${NC}"
npx netlify-cli deploy --prod --dir=.next

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ Frontend Updated!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Your platform is now connected:"
echo "  🌐 Frontend: https://mortgageguardian.org"
echo "  🔧 Backend: https://$BACKEND_URL"
echo ""
echo -e "${YELLOW}Testing the connection...${NC}"

# Test the backend health endpoint
curl -s https://$BACKEND_URL/health | python3 -m json.tool

echo ""
echo -e "${GREEN}Next: Update your iOS app with the backend URL${NC}"

cd ..