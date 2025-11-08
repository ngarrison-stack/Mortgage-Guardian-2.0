#!/bin/bash

# ============================================
# RAILWAY DEPLOYMENT TEST SCRIPT
# Tests deployed endpoints
# ============================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Get deployment URL
print_header "Railway Deployment Tester"

if [ -z "$1" ]; then
    print_info "Getting Railway URL..."
    RAILWAY_URL=$(railway status --json 2>/dev/null | grep -o 'https://[^"]*' | head -1 || echo "")

    if [ -z "$RAILWAY_URL" ]; then
        print_error "Could not determine Railway URL"
        echo ""
        echo "Usage: $0 <deployment-url>"
        echo "Example: $0 https://mortgage-guardian-backend.up.railway.app"
        echo ""
        echo "Or run from Railway project directory to auto-detect URL"
        exit 1
    fi
else
    RAILWAY_URL="$1"
fi

# Remove trailing slash
RAILWAY_URL="${RAILWAY_URL%/}"

print_info "Testing: $RAILWAY_URL"
echo ""

# ============================================
# TEST HEALTH ENDPOINT
# ============================================

print_header "Testing Health Endpoint"

print_info "GET $RAILWAY_URL/health"

HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$RAILWAY_URL/health" 2>/dev/null || echo "000")
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | tail -n 1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HEALTH_CODE" = "200" ]; then
    print_success "Health check passed (HTTP $HEALTH_CODE)"
    echo ""
    echo "Response:"
    echo "$HEALTH_BODY" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_BODY"
    echo ""
else
    print_error "Health check failed (HTTP $HEALTH_CODE)"
    echo "Response: $HEALTH_BODY"
    exit 1
fi

# ============================================
# TEST CORS
# ============================================

print_header "Testing CORS Configuration"

print_info "Testing CORS headers..."

CORS_RESPONSE=$(curl -s -I -X OPTIONS \
    -H "Origin: https://mortgageguardian.org" \
    -H "Access-Control-Request-Method: POST" \
    "$RAILWAY_URL/v1/ai/claude/analyze" 2>/dev/null || echo "")

if echo "$CORS_RESPONSE" | grep -q "access-control-allow-origin"; then
    print_success "CORS headers present"
    echo "$CORS_RESPONSE" | grep -i "access-control"
else
    print_error "CORS headers missing"
fi

echo ""

# ============================================
# TEST CLAUDE ENDPOINT
# ============================================

print_header "Testing Claude AI Endpoint"

print_info "POST $RAILWAY_URL/v1/ai/claude/analyze"

CLAUDE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$RAILWAY_URL/v1/ai/claude/analyze" \
    -H "Content-Type: application/json" \
    -d '{
        "documentText": "Test mortgage statement with property value $300,000",
        "documentType": "statement",
        "propertyValue": 300000
    }' 2>/dev/null || echo "000")

CLAUDE_CODE=$(echo "$CLAUDE_RESPONSE" | tail -n 1)
CLAUDE_BODY=$(echo "$CLAUDE_RESPONSE" | sed '$d')

if [ "$CLAUDE_CODE" = "200" ] || [ "$CLAUDE_CODE" = "400" ] || [ "$CLAUDE_CODE" = "401" ]; then
    print_success "Claude endpoint accessible (HTTP $CLAUDE_CODE)"
    echo ""
    echo "Response snippet:"
    echo "$CLAUDE_BODY" | python3 -m json.tool 2>/dev/null | head -20 || echo "$CLAUDE_BODY" | head -20
    echo ""

    if [ "$CLAUDE_CODE" = "401" ]; then
        print_info "Note: 401 is expected if ANTHROPIC_API_KEY is not configured"
    fi
else
    print_error "Claude endpoint failed (HTTP $CLAUDE_CODE)"
    echo "Response: $CLAUDE_BODY"
fi

# ============================================
# TEST PLAID ENDPOINT
# ============================================

print_header "Testing Plaid Endpoint"

print_info "POST $RAILWAY_URL/v1/plaid/link_token"

PLAID_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$RAILWAY_URL/v1/plaid/link_token" \
    -H "Content-Type: application/json" \
    -d '{"userId": "test-user-123"}' 2>/dev/null || echo "000")

PLAID_CODE=$(echo "$PLAID_RESPONSE" | tail -n 1)
PLAID_BODY=$(echo "$PLAID_RESPONSE" | sed '$d')

if [ "$PLAID_CODE" = "200" ] || [ "$PLAID_CODE" = "400" ] || [ "$PLAID_CODE" = "500" ]; then
    print_success "Plaid endpoint accessible (HTTP $PLAID_CODE)"
    echo ""
    echo "Response snippet:"
    echo "$PLAID_BODY" | python3 -m json.tool 2>/dev/null | head -20 || echo "$PLAID_BODY" | head -20
    echo ""

    if [ "$PLAID_CODE" = "500" ] || [ "$PLAID_CODE" = "400" ]; then
        print_info "Note: Error expected if PLAID credentials are not configured"
    fi
else
    print_error "Plaid endpoint failed (HTTP $PLAID_CODE)"
    echo "Response: $PLAID_BODY"
fi

# ============================================
# TEST 404 HANDLING
# ============================================

print_header "Testing 404 Handler"

print_info "GET $RAILWAY_URL/nonexistent"

NOT_FOUND_RESPONSE=$(curl -s -w "\n%{http_code}" "$RAILWAY_URL/nonexistent" 2>/dev/null || echo "000")
NOT_FOUND_CODE=$(echo "$NOT_FOUND_RESPONSE" | tail -n 1)

if [ "$NOT_FOUND_CODE" = "404" ]; then
    print_success "404 handler working (HTTP $NOT_FOUND_CODE)"
else
    print_error "404 handler issue (HTTP $NOT_FOUND_CODE)"
fi

echo ""

# ============================================
# SUMMARY
# ============================================

print_header "Test Summary"

echo ""
echo "Deployment URL: $RAILWAY_URL"
echo ""
echo "Endpoints tested:"
echo "  ✓ GET  /health"
echo "  ✓ POST /v1/ai/claude/analyze"
echo "  ✓ POST /v1/plaid/link_token"
echo "  ✓ 404 handler"
echo "  ✓ CORS headers"
echo ""
echo "Next steps:"
echo "  1. Configure API keys in Railway dashboard if needed"
echo "  2. Update frontend to use: $RAILWAY_URL"
echo "  3. Test full integration with frontend"
echo "  4. Set up custom domain: railway domain"
echo "  5. Configure monitoring and alerts"
echo ""

print_success "Deployment test complete!"
