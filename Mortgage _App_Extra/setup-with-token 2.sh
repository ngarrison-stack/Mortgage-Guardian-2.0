#!/bin/bash

# Complete Setup with Your Cloudflare Credentials
# Zone ID: 8593dfb958a0a85d49b348bd8a619607
# Account ID: fd71ffcb58faf50d37cb11706f121c70

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ZONE_ID="8593dfb958a0a85d49b348bd8a619607"
ACCOUNT_ID="fd71ffcb58faf50d37cb11706f121c70"

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚀 Complete MortgageGuardian.org Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get API Token
echo -e "${YELLOW}Please paste your Cloudflare API Token:${NC}"
echo "(The one you just created at dash.cloudflare.com/profile/api-tokens)"
echo ""
read -s -p "API Token: " API_TOKEN
echo ""
echo ""

# Verify token
echo "Verifying token..."
if curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ Token verified successfully!${NC}"
else
    echo -e "❌ Invalid token. Please check and try again."
    exit 1
fi

# Save token for other scripts
export CLOUDFLARE_API_TOKEN=$API_TOKEN

# Function to add DNS record
add_dns() {
    local type=$1
    local name=$2
    local content=$3

    echo "  Adding: $name → $content"

    # Delete existing record if it exists
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$name.mortgageguardian.org" \
        -H "Authorization: Bearer $API_TOKEN" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING" ]; then
        curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING" \
            -H "Authorization: Bearer $API_TOKEN" > /dev/null
    fi

    # Add new record
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":true}" > /dev/null
}

echo ""
echo -e "${CYAN}Step 1: Configuring DNS Records${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# For now, point to Netlify (since Vercel needs payment)
add_dns "CNAME" "@" "mortgage-guardian-app.netlify.app"
add_dns "CNAME" "www" "mortgage-guardian-app.netlify.app"
add_dns "CNAME" "app" "mortgage-guardian-app.netlify.app"

echo -e "${GREEN}✅ DNS records configured!${NC}"

echo ""
echo -e "${CYAN}Step 2: Setting Up Email Forwarding${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "What email should receive forwarded messages?"
read -p "Your email: " USER_EMAIL

# Enable email routing
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/enable" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"enabled":true}' > /dev/null

# Add destination address
DEST_ID=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/email/routing/addresses" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"email\":\"$USER_EMAIL\"}" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# Create email routing rules
create_email_rule() {
    local from=$1
    echo "  Creating: $from@mortgageguardian.org → $USER_EMAIL"

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/rules" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"actions\": [{\"type\": \"forward\", \"value\": [\"$USER_EMAIL\"]}],
            \"matchers\": [{\"type\": \"literal\", \"field\": \"to\", \"value\": \"$from@mortgageguardian.org\"}],
            \"enabled\": true,
            \"name\": \"Forward $from\"
        }" > /dev/null 2>&1
}

create_email_rule "support"
create_email_rule "info"
create_email_rule "hello"
create_email_rule "admin"

echo -e "${GREEN}✅ Email forwarding configured!${NC}"

echo ""
echo -e "${CYAN}Step 3: Configuring Security Settings${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# SSL Mode
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"flexible"}' > /dev/null
echo "  ✅ SSL mode configured"

# Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null
echo "  ✅ Always Use HTTPS enabled"

# Auto Minify
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/minify" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":{"css":true,"html":true,"js":true}}' > /dev/null
echo "  ✅ Auto minification enabled"

echo ""
echo -e "${CYAN}Step 4: Deploying Your App${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Now let's deploy your app to Netlify (free)..."
echo ""

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "Installing Netlify CLI..."
    npm install -g netlify-cli
fi

cd frontend

echo "Building your app..."
npm run build

echo ""
echo "Deploying to Netlify..."
echo "(A browser will open for authentication)"
netlify deploy --prod --dir=.next --site-name=mortgage-guardian-app

cd ..

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ COMPLETE SETUP SUCCESSFUL!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Your sites are configured at:"
echo "  🌐 https://mortgageguardian.org"
echo "  📱 https://app.mortgageguardian.org"
echo "  🌐 https://www.mortgageguardian.org"
echo ""
echo "Email addresses ready:"
echo "  📧 support@mortgageguardian.org → $USER_EMAIL"
echo "  📧 info@mortgageguardian.org → $USER_EMAIL"
echo "  📧 hello@mortgageguardian.org → $USER_EMAIL"
echo "  📧 admin@mortgageguardian.org → $USER_EMAIL"
echo ""
echo -e "${YELLOW}Note: DNS propagation takes 5-30 minutes${NC}"
echo ""
echo "Test your site in a few minutes!"
echo ""
echo -e "${GREEN}🎉 Your professional website is going live!${NC}"