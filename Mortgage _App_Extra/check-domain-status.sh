#!/bin/bash

# Check Domain Status for mortgageguardian.org

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}     🔍 Domain Status Check - mortgageguardian.org${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check DNS resolution
echo -e "${BLUE}DNS Resolution:${NC}"
echo -n "  mortgageguardian.org: "
if host mortgageguardian.org > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Resolving$(host mortgageguardian.org | grep "has address" | head -1 | awk '{print " to "$4}')${NC}"
else
    echo -e "${YELLOW}⏳ Not resolving yet${NC}"
fi

echo -n "  www.mortgageguardian.org: "
if host www.mortgageguardian.org > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Resolving${NC}"
else
    echo -e "${YELLOW}⏳ Not resolving yet${NC}"
fi

echo -n "  app.mortgageguardian.org: "
if host app.mortgageguardian.org > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Resolving${NC}"
else
    echo -e "${YELLOW}⏳ Not resolving yet${NC}"
fi

echo ""
echo -e "${BLUE}HTTPS Status:${NC}"
echo -n "  SSL Certificate: "
if echo | openssl s_client -connect mortgageguardian.org:443 2>/dev/null | grep -q "Verify return code: 0"; then
    echo -e "${GREEN}✅ Valid SSL${NC}"
else
    echo -e "${YELLOW}⏳ Waiting for SSL${NC}"
fi

echo ""
echo -e "${BLUE}Website Status:${NC}"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://mortgageguardian.org 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
    echo -e "  ${GREEN}✅ Site is responding (HTTP $STATUS)${NC}"
elif [ "$STATUS" = "000" ]; then
    echo -e "  ${YELLOW}⏳ Site not accessible yet (DNS propagating)${NC}"
else
    echo -e "  ${YELLOW}⚠️  HTTP Status: $STATUS${NC}"
fi

echo ""
echo -e "${BLUE}Email MX Records:${NC}"
MX_RECORDS=$(dig +short MX mortgageguardian.org 2>/dev/null)
if [ -n "$MX_RECORDS" ]; then
    echo -e "${GREEN}✅ Email routing configured${NC}"
    echo "$MX_RECORDS" | while read line; do
        echo "     $line"
    done
else
    echo -e "${YELLOW}⏳ MX records not found yet${NC}"
fi

echo ""
echo -e "${CYAN}Current Time:${NC} $(date)"
echo ""
echo -e "${YELLOW}Note:${NC}"
echo "• DNS propagation typically takes 5-30 minutes"
echo "• Some ISPs may cache for up to 48 hours"
echo "• Try clearing browser cache if site doesn't load"
echo ""

# Cloudflare nameserver check
echo -e "${BLUE}Nameservers:${NC}"
NS_RECORDS=$(dig +short NS mortgageguardian.org 2>/dev/null)
if echo "$NS_RECORDS" | grep -q "cloudflare"; then
    echo -e "${GREEN}✅ Using Cloudflare nameservers${NC}"
else
    echo -e "${YELLOW}Current nameservers:${NC}"
    echo "$NS_RECORDS" | while read ns; do
        echo "     $ns"
    done
fi

echo ""
echo -e "${GREEN}Run this script again in a few minutes to check progress${NC}"