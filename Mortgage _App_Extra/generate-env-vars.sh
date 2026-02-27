#!/bin/bash

# Generate secure environment variables for Railway

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🔐 Production Environment Variables${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Generate secure secrets
JWT_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

echo -e "${GREEN}Copy and paste these into Railway Variables tab:${NC}"
echo ""
echo -e "${BLUE}────── Core Settings ──────${NC}"
echo "NODE_ENV=production"
echo "JWT_SECRET=$JWT_SECRET"
echo "ENCRYPTION_KEY=$ENCRYPTION_KEY"
echo ""

echo -e "${BLUE}────── CORS Configuration ──────${NC}"
echo "ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org,https://mortgage-guardian-app.netlify.app"
echo ""

echo -e "${BLUE}────── Rate Limiting ──────${NC}"
echo "RATE_LIMIT_WINDOW_MS=900000"
echo "RATE_LIMIT_MAX_REQUESTS=100"
echo ""

echo -e "${YELLOW}────── API Keys (Add Your Own) ──────${NC}"
echo "# Claude AI (required for document analysis)"
echo "ANTHROPIC_API_KEY=sk-ant-..."
echo ""
echo "# Plaid (required for bank connections)"
echo "PLAID_CLIENT_ID=your-plaid-client-id"
echo "PLAID_SECRET=your-plaid-secret"
echo "PLAID_ENV=sandbox"
echo ""
echo "# Supabase (optional, for storage)"
echo "SUPABASE_URL=https://your-project.supabase.co"
echo "SUPABASE_ANON_KEY=your-anon-key"
echo "SUPABASE_SERVICE_KEY=your-service-key"
echo ""

echo -e "${GREEN}────── Auto-Provided by Railway ──────${NC}"
echo "# These are automatically injected:"
echo "# DATABASE_URL"
echo "# REDIS_URL"
echo "# PORT"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Save these secrets securely!${NC}"
echo "JWT_SECRET: $JWT_SECRET"
echo "ENCRYPTION_KEY: $ENCRYPTION_KEY"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"