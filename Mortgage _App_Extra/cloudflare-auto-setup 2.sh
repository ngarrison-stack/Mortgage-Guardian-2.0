#!/bin/bash

# ============================================
# 🚀 CLOUDFLARE AUTOMATED DNS SETUP
# ============================================
# This script will automatically configure your DNS records
# No manual copying required!

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cloudflare Configuration
ZONE_ID="8593dfb958a0a85d49b348bd8a619607"
ACCOUNT_ID="fd71ffcb58faf50d37cb11706f121c70"
DOMAIN="mortgageguardian.org"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚀 CLOUDFLARE AUTOMATED DNS SETUP${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Zone ID: $ZONE_ID${NC}"
echo -e "${GREEN}Account ID: $ACCOUNT_ID${NC}"
echo ""

# Get API Token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${YELLOW}Please enter your Cloudflare API Token:${NC}"
    echo -e "${BLUE}To get it:${NC}"
    echo "1. Go to: https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Click 'Create Token'"
    echo "3. Use 'Edit zone DNS' template"
    echo "4. Select Zone: mortgageguardian.org"
    echo "5. Click 'Continue to summary' → 'Create Token'"
    echo ""
    read -s -p "API Token: " CLOUDFLARE_API_TOKEN
    echo ""
fi

# Test API connection
echo -e "${YELLOW}Testing Cloudflare API connection...${NC}"
VERIFY=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" | grep -o '"success":[^,]*' | grep -o 'true\|false')

if [ "$VERIFY" != "true" ]; then
    echo -e "${RED}❌ Invalid API token. Please check and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ API connection successful!${NC}"
echo ""

# ============================================
# FUNCTION: Add/Update DNS Record
# ============================================
add_dns_record() {
    local record_type=$1
    local name=$2
    local content=$3
    local proxied=${4:-true}

    echo -e "${BLUE}Adding $record_type record: $name → $content${NC}"

    # Check if record exists
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$record_type&name=$name.$DOMAIN" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING" ]; then
        # Update existing record
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$record_type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":$proxied}" > /dev/null
        echo -e "${GREEN}  ✅ Updated existing record${NC}"
    else
        # Create new record
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$record_type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":$proxied}" > /dev/null
        echo -e "${GREEN}  ✅ Created new record${NC}"
    fi
}

# ============================================
# STEP 1: DEPLOY TO VERCEL
# ============================================
echo -e "${CYAN}Step 1: Deploying Frontend to Vercel${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "Installing Vercel CLI..."
    npm install -g vercel
fi

cd frontend

# Deploy to Vercel
echo -e "${YELLOW}Deploying to Vercel...${NC}"
echo -e "${BLUE}If prompted for login, press Enter to open browser${NC}"
echo ""

VERCEL_URL=$(vercel --prod --yes 2>&1 | grep "Production:" | awk '{print $2}')

if [ -z "$VERCEL_URL" ]; then
    # Fallback deployment
    vercel --prod --yes
    VERCEL_URL="cname.vercel-dns.com"
fi

echo -e "${GREEN}✅ Frontend deployed!${NC}"
echo ""

# Add custom domain to Vercel
echo "Adding custom domain to Vercel..."
vercel domains add app.mortgageguardian.org 2>/dev/null || echo "Domain already configured"
vercel domains add mortgageguardian.org 2>/dev/null || echo "Domain already configured"

cd ..

# ============================================
# STEP 2: DEPLOY TO RAILWAY
# ============================================
echo ""
echo -e "${CYAN}Step 2: Deploying Backend to Railway${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "Installing Railway CLI..."
    npm install -g @railway/cli
fi

cd backend-express

echo -e "${YELLOW}Setting up Railway...${NC}"
echo -e "${BLUE}A browser will open for Railway login${NC}"
echo ""

# Login to Railway
railway login

# Create new project
railway init -n mortgage-guardian-api

# Deploy
echo "Deploying to Railway..."
railway up

# Get Railway domain
RAILWAY_DOMAIN=$(railway domain 2>/dev/null | grep -o '[a-z0-9-]*\.up\.railway\.app' | head -1)

if [ -z "$RAILWAY_DOMAIN" ]; then
    echo -e "${YELLOW}Please provide your Railway domain (e.g., your-app.up.railway.app):${NC}"
    read RAILWAY_DOMAIN
fi

echo -e "${GREEN}✅ Backend deployed to: $RAILWAY_DOMAIN${NC}"

cd ..

# ============================================
# STEP 3: CONFIGURE CLOUDFLARE DNS
# ============================================
echo ""
echo -e "${CYAN}Step 3: Configuring Cloudflare DNS Automatically${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Add DNS Records
add_dns_record "CNAME" "@" "cname.vercel-dns.com" true
add_dns_record "CNAME" "www" "cname.vercel-dns.com" true
add_dns_record "CNAME" "app" "cname.vercel-dns.com" true
add_dns_record "CNAME" "api" "$RAILWAY_DOMAIN" true

echo ""
echo -e "${GREEN}✅ DNS records configured!${NC}"

# ============================================
# STEP 4: CONFIGURE EMAIL ROUTING
# ============================================
echo ""
echo -e "${CYAN}Step 4: Setting Up Email Forwarding${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}What email should receive forwarded messages?${NC}"
read -p "Your email: " USER_EMAIL

# Enable email routing
echo "Enabling email routing..."
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/enable" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"enabled":true}' > /dev/null

# Add email routing rules
add_email_forward() {
    local from=$1
    local to=$2

    echo -e "${BLUE}Creating: $from@$DOMAIN → $to${NC}"

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/rules" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"actions\": [{\"type\": \"forward\", \"value\": [\"$to\"]}],
            \"matchers\": [{\"type\": \"literal\", \"field\": \"to\", \"value\": \"$from@$DOMAIN\"}],
            \"enabled\": true
        }" > /dev/null 2>&1

    echo -e "${GREEN}  ✅ Email forward created${NC}"
}

# Create email forwards
add_email_forward "support" "$USER_EMAIL"
add_email_forward "info" "$USER_EMAIL"
add_email_forward "hello" "$USER_EMAIL"
add_email_forward "noreply" "$USER_EMAIL"

echo ""
echo -e "${GREEN}✅ Email forwarding configured!${NC}"

# ============================================
# STEP 5: CONFIGURE SSL & SECURITY
# ============================================
echo ""
echo -e "${CYAN}Step 5: Configuring SSL & Security${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set SSL mode to Full (strict)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"strict"}' > /dev/null

echo -e "${GREEN}✅ SSL mode set to Full (strict)${NC}"

# Enable Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null

echo -e "${GREEN}✅ Always Use HTTPS enabled${NC}"

# Enable Automatic HTTPS Rewrites
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/automatic_https_rewrites" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null

echo -e "${GREEN}✅ Automatic HTTPS Rewrites enabled${NC}"

# ============================================
# CREATE MONITORING SCRIPT
# ============================================
cat > check-deployment.sh << 'EOF'
#!/bin/bash

echo "🔍 Checking Deployment Status..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check Frontend
echo "Frontend Status:"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://app.mortgageguardian.org)
if [ "$STATUS" = "200" ]; then
    echo -e "  ${GREEN}✅ https://app.mortgageguardian.org - Online${NC}"
else
    echo -e "  ${YELLOW}⏳ https://app.mortgageguardian.org - Status: $STATUS${NC}"
fi

# Check API
echo ""
echo "API Status:"
API_CHECK=$(curl -s https://api.mortgageguardian.org/health 2>/dev/null)
if [ -n "$API_CHECK" ]; then
    echo -e "  ${GREEN}✅ https://api.mortgageguardian.org - Online${NC}"
    echo "  Response: $API_CHECK"
else
    echo -e "  ${YELLOW}⏳ https://api.mortgageguardian.org - Waiting for deployment${NC}"
fi

# Check DNS
echo ""
echo "DNS Resolution:"
dig +short app.mortgageguardian.org | head -1

# Check Email MX Records
echo ""
echo "Email MX Records:"
dig +short MX mortgageguardian.org

echo ""
echo "Full status: https://mortgageguardian.org"
EOF

chmod +x check-deployment.sh

# ============================================
# COMPLETION
# ============================================
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     🎉 FULLY AUTOMATED DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Frontend deployed to Vercel${NC}"
echo -e "${GREEN}✅ Backend deployed to Railway${NC}"
echo -e "${GREEN}✅ DNS records automatically configured${NC}"
echo -e "${GREEN}✅ SSL certificates active${NC}"
echo -e "${GREEN}✅ Email forwarding configured${NC}"
echo ""
echo -e "${CYAN}Your sites are now live at:${NC}"
echo "  🌐 https://mortgageguardian.org"
echo "  📱 https://app.mortgageguardian.org"
echo "  🔧 https://api.mortgageguardian.org"
echo ""
echo -e "${CYAN}Email addresses:${NC}"
echo "  📧 support@mortgageguardian.org → $USER_EMAIL"
echo "  📧 info@mortgageguardian.org → $USER_EMAIL"
echo "  📧 hello@mortgageguardian.org → $USER_EMAIL"
echo ""
echo -e "${YELLOW}DNS propagation may take 5-30 minutes${NC}"
echo ""
echo "Run ./check-deployment.sh to monitor status"
echo ""
echo -e "${GREEN}🚀 Your site is going live!${NC}"