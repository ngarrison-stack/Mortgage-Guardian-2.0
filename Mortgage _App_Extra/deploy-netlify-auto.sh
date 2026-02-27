#!/bin/bash

# Automated Netlify Deployment Script
# No interactive prompts - fully automated

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🚀 Automated Netlify Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Kill any existing Netlify processes
pkill -f "netlify-cli" 2>/dev/null

cd frontend

# Build the project first
echo -e "${BLUE}Building frontend...${NC}"
npm run build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"
echo ""

# Deploy to Netlify with automatic site creation
echo -e "${BLUE}Deploying to Netlify...${NC}"
echo "Creating new site: mortgage-guardian-app"

# Create a new site and deploy in one command
npx netlify-cli deploy --create-site mortgage-guardian-app --dir .next --prod --json > deploy-result.json 2>&1

# Check if deployment was successful
if grep -q "deploy_url" deploy-result.json 2>/dev/null; then
    DEPLOY_URL=$(grep "deploy_url" deploy-result.json | sed 's/.*"deploy_url":\s*"\([^"]*\)".*/\1/')
    SITE_URL=$(grep "url" deploy-result.json | grep -v "deploy_url" | head -1 | sed 's/.*"url":\s*"\([^"]*\)".*/\1/')

    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo ""
    echo "Deploy URL: $DEPLOY_URL"
    echo "Site URL: $SITE_URL"

    # Extract Netlify subdomain for DNS configuration
    NETLIFY_DOMAIN=$(echo "$SITE_URL" | sed 's|https://||' | sed 's|http://||')

    echo ""
    echo -e "${CYAN}Updating Cloudflare DNS...${NC}"

    # Update DNS using our Cloudflare credentials
    cd ..
    cat > update-dns-netlify.sh << 'EOF'
#!/bin/bash

API_TOKEN="GEywU4-Jur5BG2nw9O_Aj5Gk04P778TFANkJgegm"
ZONE_ID="8593dfb958a0a85d49b348bd8a619607"
NETLIFY_DOMAIN="$1"

# Function to update DNS record
update_dns_record() {
    local name=$1
    local content=$2

    echo "Updating $name.mortgageguardian.org → $content"

    # Get existing record ID if it exists
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$name.mortgageguardian.org" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$EXISTING" ]; then
        # Update existing record
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":false}" > /dev/null
    else
        # Create new record
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":1,\"proxied\":false}" > /dev/null
    fi
}

# Update root domain
update_dns_record "@" "$NETLIFY_DOMAIN"
update_dns_record "www" "$NETLIFY_DOMAIN"
update_dns_record "app" "$NETLIFY_DOMAIN"

echo "✅ DNS records updated!"
EOF

    chmod +x update-dns-netlify.sh
    ./update-dns-netlify.sh "$NETLIFY_DOMAIN"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ✅ DEPLOYMENT COMPLETE!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Your site is live at:"
    echo "  🌐 $SITE_URL"
    echo ""
    echo "Custom domain (propagating):"
    echo "  🌐 https://mortgageguardian.org"
    echo "  🌐 https://www.mortgageguardian.org"
    echo "  📱 https://app.mortgageguardian.org"
    echo ""
    echo -e "${YELLOW}Note: DNS propagation takes 5-30 minutes${NC}"

else
    echo -e "${YELLOW}Trying alternative deployment method...${NC}"

    # Alternative: Use netlify init and deploy separately
    npx netlify-cli init --manual
    npx netlify-cli deploy --dir .next --prod
fi

cd ..