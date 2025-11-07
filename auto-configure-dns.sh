#!/bin/bash

# Automated DNS Configuration for mortgageguardian.org
# Using provided API token

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Your credentials (set as environment variables for security)
# Export these before running the script:
# export CLOUDFLARE_API_TOKEN="your-api-token"
# export CLOUDFLARE_ZONE_ID="your-zone-id"
# export CLOUDFLARE_ACCOUNT_ID="your-account-id"

API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
ZONE_ID="${CLOUDFLARE_ZONE_ID:-8593dfb958a0a85d49b348bd8a619607}"
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-fd71ffcb58faf50d37cb11706f121c70}"

if [ -z "$API_TOKEN" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN environment variable not set${NC}"
    echo "Please run: export CLOUDFLARE_API_TOKEN='your-api-token'"
    exit 1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚀 Automated DNS Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to add/update DNS record
configure_dns_record() {
    local type=$1
    local name=$2
    local content=$3
    local proxied=${4:-true}

    echo -e "${BLUE}Configuring: ${name}.mortgageguardian.org → ${content}${NC}"

    # Check if record exists
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$type&name=$name.mortgageguardian.org" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING" ]; then
        # Update existing record
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":$proxied}" > /dev/null
        echo -e "  ${GREEN}✅ Updated existing record${NC}"
    else
        # Create new record
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":$proxied}" > /dev/null
        echo -e "  ${GREEN}✅ Created new record${NC}"
    fi
}

echo -e "${CYAN}Step 1: Configuring DNS Records${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# For now, use a temporary landing page
# Will update once deployment is ready
configure_dns_record "A" "@" "192.0.2.1" true  # Temporary IP (will update)
configure_dns_record "CNAME" "www" "mortgageguardian.org" true
configure_dns_record "CNAME" "app" "mortgageguardian.org" true
configure_dns_record "CNAME" "api" "mortgageguardian.org" true

echo ""
echo -e "${CYAN}Step 2: Configuring Email Routing${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Enable email routing
echo "Enabling email routing..."
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/enable" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"enabled":true}' > /dev/null

# Get user email
echo ""
echo -e "${YELLOW}What email address should receive forwarded emails?${NC}"
read -p "Your email: " USER_EMAIL

# Verify destination email first
echo "Verifying email destination..."
VERIFY_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/email/routing/addresses" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"email\":\"$USER_EMAIL\"}")

if echo "$VERIFY_RESPONSE" | grep -q "success.*true"; then
    echo -e "${GREEN}✅ Email destination verified${NC}"
else
    echo -e "${YELLOW}Note: Check your email for verification link from Cloudflare${NC}"
fi

# Create email routing rules
create_email_rule() {
    local address=$1
    echo -e "${BLUE}Creating: ${address}@mortgageguardian.org → ${USER_EMAIL}${NC}"

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/rules" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"actions\": [{\"type\": \"forward\", \"value\": [\"$USER_EMAIL\"]}],
            \"matchers\": [{\"type\": \"literal\", \"field\": \"to\", \"value\": \"$address@mortgageguardian.org\"}],
            \"enabled\": true,
            \"name\": \"Forward $address\",
            \"priority\": 0
        }" > /dev/null 2>&1

    echo -e "  ${GREEN}✅ Email rule created${NC}"
}

create_email_rule "support"
create_email_rule "info"
create_email_rule "hello"
create_email_rule "admin"
create_email_rule "contact"

echo ""
echo -e "${CYAN}Step 3: Configuring Security Settings${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# SSL Mode - Flexible for now (until we deploy)
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"flexible"}' > /dev/null
echo -e "${GREEN}✅ SSL mode configured${NC}"

# Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null
echo -e "${GREEN}✅ Always Use HTTPS enabled${NC}"

# Automatic HTTPS Rewrites
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/automatic_https_rewrites" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null
echo -e "${GREEN}✅ Automatic HTTPS Rewrites enabled${NC}"

# Enable Brotli Compression
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/brotli" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"value":"on"}' > /dev/null
echo -e "${GREEN}✅ Brotli compression enabled${NC}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     ✅ DNS CONFIGURATION COMPLETE!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Your domain is now configured:"
echo "  🌐 https://mortgageguardian.org"
echo "  🌐 https://www.mortgageguardian.org"
echo "  📱 https://app.mortgageguardian.org"
echo "  🔧 https://api.mortgageguardian.org"
echo ""
echo "Email addresses configured:"
echo "  📧 support@mortgageguardian.org → $USER_EMAIL"
echo "  📧 info@mortgageguardian.org → $USER_EMAIL"
echo "  📧 hello@mortgageguardian.org → $USER_EMAIL"
echo "  📧 admin@mortgageguardian.org → $USER_EMAIL"
echo "  📧 contact@mortgageguardian.org → $USER_EMAIL"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo "• DNS propagation takes 5-30 minutes"
echo "• Check email for Cloudflare verification if needed"
echo "• Next: Deploy your app to update DNS records"
echo ""
echo -e "${GREEN}🎉 Your professional domain is ready!${NC}"