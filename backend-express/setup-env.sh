#!/bin/bash

# ============================================
# ENVIRONMENT SETUP SCRIPT
# Generates secure keys and prepares environment
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "============================================"
    echo "$1"
    echo "============================================"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================
# GENERATE SECURE KEYS
# ============================================

print_header "Generating Secure Keys"

# Generate JWT secret (32 bytes = 64 hex chars)
JWT_SECRET=$(openssl rand -hex 32)
print_success "JWT_SECRET generated"

# Generate encryption key (32 bytes = 64 hex chars)
ENCRYPTION_KEY=$(openssl rand -hex 32)
print_success "ENCRYPTION_KEY generated"

# Generate refresh token secret
REFRESH_TOKEN_SECRET=$(openssl rand -hex 32)
print_success "REFRESH_TOKEN_SECRET generated"

# ============================================
# CREATE ENV FILE
# ============================================

print_header "Creating Environment File"

ENV_FILE=".env.railway.local"

cat > "$ENV_FILE" << EOF
# ============================================
# RAILWAY DEPLOYMENT CONFIGURATION
# Generated: $(date)
# ============================================

# IMPORTANT: These are secure production keys
# Keep this file SECRET and do NOT commit to git

# ============================================
# SECURITY KEYS (GENERATED)
# ============================================
JWT_SECRET=${JWT_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}
REFRESH_TOKEN_SECRET=${REFRESH_TOKEN_SECRET}

# ============================================
# APPLICATION SETTINGS
# ============================================
NODE_ENV=production
PORT=3000

# ============================================
# CORS & DOMAINS
# ============================================
ALLOWED_ORIGINS=https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org

# ============================================
# RATE LIMITING
# ============================================
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# ============================================
# ANTHROPIC CLAUDE AI
# ============================================
# TODO: Add your Anthropic API key
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here

# ============================================
# PLAID CONFIGURATION
# ============================================
# TODO: Add your Plaid credentials
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox

# ============================================
# DATABASE & REDIS
# ============================================
# Railway will auto-inject:
# DATABASE_URL - PostgreSQL connection
# REDIS_URL - Redis connection

# ============================================
# OPTIONAL: EMAIL CONFIGURATION
# ============================================
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_USER=your-email@gmail.com
# SMTP_PASS=your-app-password
# EMAIL_FROM=noreply@mortgageguardian.org

# ============================================
# OPTIONAL: MONITORING
# ============================================
# SENTRY_DSN=https://your-key@sentry.io/project
# LOG_LEVEL=info
EOF

print_success "Environment file created: $ENV_FILE"

# ============================================
# CREATE EXPORT SCRIPT
# ============================================

print_header "Creating Export Script"

EXPORT_FILE="export-env.sh"

cat > "$EXPORT_FILE" << EOF
#!/bin/bash
# Source this file to export environment variables
# Usage: source export-env.sh

export JWT_SECRET="${JWT_SECRET}"
export ENCRYPTION_KEY="${ENCRYPTION_KEY}"
export REFRESH_TOKEN_SECRET="${REFRESH_TOKEN_SECRET}"
export NODE_ENV="production"
export ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org"

# Add your API keys here
# export ANTHROPIC_API_KEY="sk-ant-api03-your-key-here"
# export PLAID_CLIENT_ID="your-client-id"
# export PLAID_SECRET="your-secret"

echo "✓ Environment variables exported"
echo "✓ You can now run: ./deploy-railway.sh"
EOF

chmod +x "$EXPORT_FILE"
print_success "Export script created: $EXPORT_FILE"

# ============================================
# CREATE RAILWAY VARIABLE SETTER
# ============================================

print_header "Creating Railway Variable Setter"

VAR_SETTER="set-railway-vars.sh"

cat > "$VAR_SETTER" << 'EOFSCRIPT'
#!/bin/bash

# ============================================
# RAILWAY VARIABLES SETTER
# Sets all environment variables in Railway
# ============================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$RAILWAY_TOKEN" ]; then
    echo -e "${RED}ERROR: RAILWAY_TOKEN not set${NC}"
    echo "Export your Railway token first:"
    echo "export RAILWAY_TOKEN='your-token-here'"
    exit 1
fi

# Load environment from .env.railway.local
if [ -f ".env.railway.local" ]; then
    source .env.railway.local
    echo -e "${GREEN}✓ Loaded variables from .env.railway.local${NC}"
else
    echo -e "${RED}ERROR: .env.railway.local not found${NC}"
    echo "Run ./setup-env.sh first"
    exit 1
fi

echo -e "${BLUE}Setting Railway environment variables...${NC}"

# Core settings
railway variables set NODE_ENV="$NODE_ENV"
railway variables set PORT="$PORT"
railway variables set ALLOWED_ORIGINS="$ALLOWED_ORIGINS"

# Security keys
railway variables set JWT_SECRET="$JWT_SECRET"
railway variables set ENCRYPTION_KEY="$ENCRYPTION_KEY"
railway variables set REFRESH_TOKEN_SECRET="$REFRESH_TOKEN_SECRET"

# Rate limiting
railway variables set RATE_LIMIT_WINDOW_MS="$RATE_LIMIT_WINDOW_MS"
railway variables set RATE_LIMIT_MAX_REQUESTS="$RATE_LIMIT_MAX_REQUESTS"

# API keys (if set)
if [ ! -z "$ANTHROPIC_API_KEY" ] && [ "$ANTHROPIC_API_KEY" != "sk-ant-api03-your-key-here" ]; then
    railway variables set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    echo -e "${GREEN}✓ ANTHROPIC_API_KEY set${NC}"
fi

if [ ! -z "$PLAID_CLIENT_ID" ] && [ "$PLAID_CLIENT_ID" != "your-plaid-client-id" ]; then
    railway variables set PLAID_CLIENT_ID="$PLAID_CLIENT_ID"
    railway variables set PLAID_SECRET="$PLAID_SECRET"
    railway variables set PLAID_ENV="${PLAID_ENV:-sandbox}"
    echo -e "${GREEN}✓ Plaid credentials set${NC}"
fi

echo -e "${GREEN}✓ All variables set successfully!${NC}"
echo ""
echo "Verify with: railway variables"
EOFSCRIPT

chmod +x "$VAR_SETTER"
print_success "Variable setter created: $VAR_SETTER"

# ============================================
# SUMMARY
# ============================================

print_header "Setup Complete!"

echo ""
echo "Generated files:"
echo "  1. $ENV_FILE - Full environment configuration"
echo "  2. $EXPORT_FILE - Export script for local deployment"
echo "  3. $VAR_SETTER - Railway variable setter"
echo ""
echo "Next steps:"
echo ""
echo "Option 1 - Quick deployment with pre-set variables:"
echo "  1. Edit $ENV_FILE and add your API keys"
echo "  2. source $EXPORT_FILE"
echo "  3. ./deploy-railway.sh"
echo ""
echo "Option 2 - Manual Railway variable setup:"
echo "  1. Get your Railway token from: https://railway.app/account/tokens"
echo "  2. export RAILWAY_TOKEN='your-token-here'"
echo "  3. ./$VAR_SETTER"
echo "  4. ./deploy-railway.sh"
echo ""
echo "IMPORTANT:"
echo "  - Add $ENV_FILE to .gitignore (already done)"
echo "  - Never commit these files to version control"
echo "  - Store JWT_SECRET and ENCRYPTION_KEY securely"
echo ""
echo "Generated keys:"
echo -e "${GREEN}JWT_SECRET:${NC} ${JWT_SECRET:0:20}..."
echo -e "${GREEN}ENCRYPTION_KEY:${NC} ${ENCRYPTION_KEY:0:20}..."
echo ""
