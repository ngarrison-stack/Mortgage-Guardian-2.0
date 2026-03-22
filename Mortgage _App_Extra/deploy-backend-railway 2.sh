#!/bin/bash

# Deploy Backend to Railway
# Free tier includes 500 hours/month and PostgreSQL

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚂 Railway Backend Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo -e "${YELLOW}Installing Railway CLI...${NC}"
    npm install -g @railway/cli
fi

cd backend-express

# Create Railway configuration
echo -e "${BLUE}Creating Railway configuration...${NC}"
cat > railway.toml << 'EOF'
[build]
builder = "nixpacks"

[deploy]
numReplicas = 1
startCommand = "npm start"
healthcheckPath = "/health"
restartPolicyType = "always"

[[services]]
name = "web"
port = 3000

[services.web]
healthcheckPath = "/health"
EOF

# Create nixpacks configuration for build
cat > nixpacks.toml << 'EOF'
[phases.setup]
nixPkgs = ["nodejs-20_x", "npm-9_x"]

[phases.install]
cmds = ["npm ci --production=false"]

[phases.build]
cmds = ["npm run build"]

[start]
cmd = "npm start"
EOF

# Update package.json scripts
echo -e "${BLUE}Updating package.json for production...${NC}"
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// Ensure production scripts
pkg.scripts = {
    ...pkg.scripts,
    'start': 'node dist/server.js',
    'build': 'tsc',
    'postinstall': 'npm run build'
};

// Add engines for Railway
pkg.engines = {
    'node': '>=20.0.0',
    'npm': '>=9.0.0'
};

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('✅ package.json updated');
"

# Create production environment template
cat > .env.railway << 'EOF'
# Railway will auto-inject these:
# DATABASE_URL - PostgreSQL connection string
# REDIS_URL - Redis connection string
# PORT - Server port

# Add these in Railway dashboard:
NODE_ENV=production
CORS_ORIGIN=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org,https://mortgage-guardian-app.netlify.app

# Security
JWT_SECRET=your-production-jwt-secret-change-this
ENCRYPTION_KEY=your-production-encryption-key-change-this

# Services (configure as needed)
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENVIRONMENT=sandbox

# Email (optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
EOF

echo -e "${GREEN}✅ Railway configuration created${NC}"
echo ""

echo -e "${CYAN}Logging into Railway...${NC}"
railway login

echo ""
echo -e "${CYAN}Creating new Railway project...${NC}"
railway init -n mortgage-guardian-backend

echo ""
echo -e "${CYAN}Adding PostgreSQL database...${NC}"
railway add -p postgresql

echo ""
echo -e "${CYAN}Adding Redis cache...${NC}"
railway add -p redis

echo ""
echo -e "${CYAN}Deploying to Railway...${NC}"
railway up

echo ""
echo -e "${GREEN}Getting deployment URL...${NC}"
BACKEND_URL=$(railway domain)

echo ""
echo -e "${CYAN}Updating frontend environment...${NC}"
cd ../frontend

# Update frontend .env.production with backend URL
cat > .env.production << EOF
NEXT_PUBLIC_API_URL=https://$BACKEND_URL
NEXT_PUBLIC_APP_URL=https://mortgageguardian.org
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=$NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
CLERK_SECRET_KEY=$CLERK_SECRET_KEY
EOF

echo -e "${GREEN}✅ Frontend environment updated${NC}"

cd ..

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ BACKEND DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Backend URL: https://$BACKEND_URL"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Go to Railway dashboard: https://railway.app/dashboard"
echo "2. Click on your project: mortgage-guardian-backend"
echo "3. Go to Variables tab"
echo "4. Add the environment variables from .env.railway"
echo "5. Railway will automatically redeploy with new variables"
echo ""
echo -e "${GREEN}Your full stack is now deployed!${NC}"
echo "  🌐 Frontend: https://mortgageguardian.org"
echo "  🔧 Backend: https://$BACKEND_URL"
echo "  📊 Database: PostgreSQL (managed by Railway)"
echo "  💾 Cache: Redis (managed by Railway)"