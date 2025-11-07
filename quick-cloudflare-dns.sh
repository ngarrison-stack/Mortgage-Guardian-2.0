#!/bin/bash

# Quick Cloudflare DNS Configuration
# Just need your API token!

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ZONE_ID="8593dfb958a0a85d49b348bd8a619607"

echo -e "${CYAN}Quick Cloudflare DNS Setup${NC}"
echo "=========================="
echo ""
echo "This will configure your DNS records automatically!"
echo ""
echo -e "${YELLOW}Get your API Token:${NC}"
echo "1. Go to: https://dash.cloudflare.com/profile/api-tokens"
echo "2. Click 'Create Token'"
echo "3. Use 'Edit zone DNS' template"
echo "4. Select: mortgageguardian.org"
echo "5. Create and copy the token"
echo ""

read -s -p "Paste your API Token here: " API_TOKEN
echo ""
echo ""

# Test connection
echo "Testing API connection..."
if curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $API_TOKEN" | grep -q '"success":true'; then
    echo -e "${GREEN}✅ Connected to Cloudflare!${NC}"
else
    echo "❌ Invalid token. Please check and try again."
    exit 1
fi

# Function to add DNS record
add_record() {
    echo "Adding: $2.$3 → $4"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$1\",\"name\":\"$2\",\"content\":\"$4\",\"ttl\":1,\"proxied\":true}" > /dev/null
}

echo ""
echo "Adding DNS Records..."
echo "--------------------"

# For now, point everything to a coming soon page or your current hosting
# Update these when Vercel is ready
add_record "CNAME" "@" "mortgageguardian.org" "proxy-ssl.webflow.com"
add_record "CNAME" "www" "mortgageguardian.org" "proxy-ssl.webflow.com"
add_record "CNAME" "app" "mortgageguardian.org" "proxy-ssl.webflow.com"

# If you have a server IP, replace this
# add_record "A" "@" "mortgageguardian.org" "YOUR_IP"

echo ""
echo -e "${GREEN}✅ DNS records added!${NC}"
echo ""
echo "Next steps:"
echo "1. Fix Vercel account: https://vercel.com/teams/nicholas-garrisons-projects/settings/billing"
echo "2. Or deploy to Netlify (free): ./deploy-netlify.sh"
echo "3. Update DNS records with actual hosting"
echo ""
echo "Your domain is now managed by Cloudflare!"