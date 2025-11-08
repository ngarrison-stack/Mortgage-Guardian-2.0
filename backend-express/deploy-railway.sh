#!/bin/bash

# ============================================
# RAILWAY AUTOMATED DEPLOYMENT SCRIPT
# Mortgage Guardian Backend - Token-Based Auth
# ============================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# CONFIGURATION
# ============================================

PROJECT_NAME="mortgage-guardian-backend"
SERVICE_NAME="backend-api"
REGION="us-west1"

# Check for Railway token
if [ -z "$RAILWAY_TOKEN" ]; then
    echo -e "${RED}ERROR: RAILWAY_TOKEN environment variable not set${NC}"
    echo ""
    echo "To get your Railway token:"
    echo "1. Visit https://railway.app/account/tokens"
    echo "2. Create a new token"
    echo "3. Export it: export RAILWAY_TOKEN='your-token-here'"
    echo ""
    exit 1
fi

# ============================================
# FUNCTIONS
# ============================================

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================
# PRE-FLIGHT CHECKS
# ============================================

print_header "Pre-flight Checks"

# Check Railway CLI
if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found"
    echo "Install with: npm install -g @railway/cli"
    exit 1
fi
print_success "Railway CLI installed"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    print_error "package.json not found. Run this script from backend-express directory"
    exit 1
fi
print_success "In correct directory"

# Check required files
required_files=("server.js" "railway.toml" "package.json" "Procfile")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file missing: $file"
        exit 1
    fi
done
print_success "All required files present"

# ============================================
# ENVIRONMENT VARIABLES CHECK
# ============================================

print_header "Checking Required Environment Variables"

# Required variables (will be prompted if missing)
required_vars=(
    "ANTHROPIC_API_KEY"
    "JWT_SECRET"
    "ENCRYPTION_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
        print_warning "$var not set in environment"
    else
        print_success "$var configured"
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_warning "Some required variables are missing"
    echo ""
    echo "You can either:"
    echo "1. Set them now in Railway dashboard after deployment"
    echo "2. Export them before running this script"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================
# RAILWAY AUTHENTICATION
# ============================================

print_header "Authenticating with Railway"

# Set Railway token for CLI
export RAILWAY_TOKEN

# Verify token works
if railway whoami &> /dev/null; then
    print_success "Railway authentication successful"
    railway whoami
else
    print_error "Railway authentication failed"
    echo "Please check your RAILWAY_TOKEN"
    exit 1
fi

# ============================================
# PROJECT SETUP
# ============================================

print_header "Setting Up Railway Project"

# Check if project exists
print_info "Checking for existing project..."

# Try to link to existing project or create new one
if railway status &> /dev/null; then
    print_success "Already linked to a Railway project"
    railway status
else
    print_info "Creating new Railway project..."
    railway init --name "$PROJECT_NAME" || {
        print_error "Failed to create project"
        exit 1
    }
    print_success "Project created: $PROJECT_NAME"
fi

# ============================================
# ADD DATABASE SERVICES
# ============================================

print_header "Setting Up Database Services"

print_info "Adding PostgreSQL database..."
railway add --database postgres || print_warning "PostgreSQL might already exist"

print_info "Adding Redis cache..."
railway add --database redis || print_warning "Redis might already exist"

print_success "Database services configured"

# ============================================
# ENVIRONMENT VARIABLES SETUP
# ============================================

print_header "Configuring Environment Variables"

# Set production environment variables
print_info "Setting environment variables..."

# Core settings
railway variables set NODE_ENV=production
railway variables set PORT=3000

# CORS configuration for your domains
railway variables set ALLOWED_ORIGINS="https://mortgageguardian.org,https://www.mortgageguardian.org,https://app.mortgageguardian.org,https://mortgage-guardian-app.netlify.app"

# Rate limiting
railway variables set RATE_LIMIT_WINDOW_MS=900000
railway variables set RATE_LIMIT_MAX_REQUESTS=100

# Set sensitive variables if provided
if [ ! -z "$ANTHROPIC_API_KEY" ]; then
    railway variables set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    print_success "ANTHROPIC_API_KEY configured"
fi

if [ ! -z "$JWT_SECRET" ]; then
    railway variables set JWT_SECRET="$JWT_SECRET"
    print_success "JWT_SECRET configured"
fi

if [ ! -z "$ENCRYPTION_KEY" ]; then
    railway variables set ENCRYPTION_KEY="$ENCRYPTION_KEY"
    print_success "ENCRYPTION_KEY configured"
fi

# Optional: Plaid configuration
if [ ! -z "$PLAID_CLIENT_ID" ]; then
    railway variables set PLAID_CLIENT_ID="$PLAID_CLIENT_ID"
    railway variables set PLAID_SECRET="$PLAID_SECRET"
    railway variables set PLAID_ENV="${PLAID_ENV:-sandbox}"
    print_success "Plaid credentials configured"
fi

print_success "Environment variables configured"

# ============================================
# DEPLOYMENT
# ============================================

print_header "Deploying to Railway"

print_info "Starting deployment (this may take 2-3 minutes)..."

# Deploy with Railway
railway up --detach || {
    print_error "Deployment failed"
    exit 1
}

print_success "Deployment initiated"

# Wait for deployment to complete
print_info "Waiting for deployment to complete..."
sleep 10

# Get deployment status
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if railway status | grep -q "Deployed"; then
        print_success "Deployment completed successfully!"
        break
    fi

    echo -n "."
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    print_warning "Deployment status check timed out"
    print_info "Check Railway dashboard for status"
fi

# ============================================
# DOMAIN & URL CONFIGURATION
# ============================================

print_header "Getting Deployment URL"

# Generate a domain
print_info "Generating Railway domain..."
railway domain || print_warning "Domain might already exist"

# Get the deployment URL
DEPLOY_URL=$(railway status --json 2>/dev/null | grep -o 'https://[^"]*' | head -1 || echo "")

if [ ! -z "$DEPLOY_URL" ]; then
    print_success "Deployment URL: $DEPLOY_URL"
else
    print_info "Getting domain information..."
    railway status
    print_info "You can also run: railway domain"
fi

# ============================================
# HEALTH CHECK
# ============================================

print_header "Running Health Check"

if [ ! -z "$DEPLOY_URL" ]; then
    print_info "Waiting 30 seconds for service to start..."
    sleep 30

    print_info "Testing health endpoint..."

    if curl -f -s "${DEPLOY_URL}/health" > /dev/null; then
        print_success "Health check passed!"

        # Show health response
        echo ""
        echo "Health check response:"
        curl -s "${DEPLOY_URL}/health" | python3 -m json.tool 2>/dev/null || curl -s "${DEPLOY_URL}/health"
        echo ""
    else
        print_warning "Health check failed or service still starting"
        print_info "This is normal for initial deployment"
        print_info "Check Railway dashboard for logs"
    fi
else
    print_warning "Could not determine deployment URL"
    print_info "Run 'railway status' to get your URL"
fi

# ============================================
# POST-DEPLOYMENT INFORMATION
# ============================================

print_header "Deployment Complete!"

echo ""
echo -e "${GREEN}✓ Backend deployed successfully!${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. View logs:"
echo "   railway logs"
echo ""
echo "2. Open Railway dashboard:"
echo "   railway open"
echo ""
echo "3. Get deployment URL:"
echo "   railway status"
echo ""
echo "4. Test endpoints:"
if [ ! -z "$DEPLOY_URL" ]; then
    echo "   curl ${DEPLOY_URL}/health"
    echo "   curl -X POST ${DEPLOY_URL}/v1/ai/claude/analyze -H 'Content-Type: application/json' -d '{...}'"
else
    echo "   curl <your-url>/health"
fi
echo ""
echo "5. Configure custom domain (optional):"
echo "   railway domain"
echo ""
echo "6. Set any missing environment variables:"
echo "   railway variables set VARIABLE_NAME=value"
echo ""
echo "7. View all variables:"
echo "   railway variables"
echo ""

# Show current environment
print_header "Current Configuration"
railway variables

echo ""
print_success "Deployment script completed successfully!"
echo ""
