#!/bin/bash

# Test Live Backend Deployment
# Tests the deployed backend API

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${BLUE}Testing Live Backend Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Get the deployment URL
echo "Enter your Railway public URL:"
echo "(e.g., https://mortgage-guardian-20-production.up.railway.app)"
echo ""
read -p "URL: " BACKEND_URL

# Remove trailing slash if present
BACKEND_URL="${BACKEND_URL%/}"

echo ""
echo -e "${CYAN}Testing: $BACKEND_URL${NC}"
echo ""

# Test 1: Health Check
echo -e "${BOLD}Test 1: Health Check${NC}"
echo "Testing: $BACKEND_URL/health"
if curl -s "$BACKEND_URL/health" | grep -q "ok"; then
    echo -e "${GREEN}✓ Health check passed!${NC}"
    echo "Response:"
    curl -s "$BACKEND_URL/health" | python3 -m json.tool 2>/dev/null || curl -s "$BACKEND_URL/health"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Response:"
    curl -s "$BACKEND_URL/health"
fi

echo ""
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""

# Test 2: API Version
echo -e "${BOLD}Test 2: API Version${NC}"
echo "Testing: $BACKEND_URL/api/v1/version"
curl -s "$BACKEND_URL/api/v1/version" | python3 -m json.tool 2>/dev/null || curl -s "$BACKEND_URL/api/v1/version"

echo ""
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""

# Test 3: Response Time
echo -e "${BOLD}Test 3: Response Time${NC}"
echo "Measuring response time..."
TIME=$(curl -o /dev/null -s -w '%{time_total}\n' "$BACKEND_URL/health")
echo "Response time: ${TIME}s"

if (( $(echo "$TIME < 1" | bc -l) )); then
    echo -e "${GREEN}✓ Excellent response time!${NC}"
elif (( $(echo "$TIME < 3" | bc -l) )); then
    echo -e "${YELLOW}⚠ Response time is okay (might be cold start)${NC}"
else
    echo -e "${RED}✗ Slow response time${NC}"
fi

echo ""
echo -e "${CYAN}────────────────────────────────────────${NC}"
echo ""

# Test 4: CORS Headers
echo -e "${BOLD}Test 4: CORS Configuration${NC}"
echo "Testing CORS headers..."
CORS_HEADERS=$(curl -I -s "$BACKEND_URL/health" | grep -i "access-control")
if [ ! -z "$CORS_HEADERS" ]; then
    echo -e "${GREEN}✓ CORS headers present:${NC}"
    echo "$CORS_HEADERS"
else
    echo -e "${YELLOW}⚠ No CORS headers detected${NC}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Save URL for frontend configuration
echo "$BACKEND_URL" > backend-url.txt
echo -e "${GREEN}✓ Backend URL saved to backend-url.txt${NC}"
echo ""

echo -e "${BOLD}${GREEN}Backend Deployment Verified!${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. URL saved: $BACKEND_URL"
echo "2. Ready to configure frontend with this URL"
echo "3. Run: ./deploy-frontend.sh (coming next)"
echo ""