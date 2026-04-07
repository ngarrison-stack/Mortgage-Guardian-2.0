#!/bin/bash

# ============================================
# DEPLOYMENT VALIDATION SCRIPT
# Validates a running Mortgage Guardian deployment
# ============================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() {
    echo -e "  ${GREEN}PASS${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "  ${YELLOW}WARN${NC} $1"
    WARN=$((WARN + 1))
}

print_header() {
    echo ""
    echo -e "${BLUE}── $1 ──${NC}"
}

# ── Parse arguments ───────────────────────────────────────────
BASE_URL="${1:-http://localhost:3000}"
# Remove trailing slash
BASE_URL="${BASE_URL%/}"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Deployment Validation${NC}"
echo -e "${BLUE}  Target: ${BASE_URL}${NC}"
echo -e "${BLUE}============================================${NC}"

# Determine if HTTPS
IS_HTTPS=false
if echo "$BASE_URL" | grep -q "^https://"; then
    IS_HTTPS=true
fi

# ── Health Endpoints ──────────────────────────────────────────
print_header "Health Endpoints"

# GET /health -> 200
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/health" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    pass "GET /health -> $RESPONSE"
else
    fail "GET /health -> $RESPONSE (expected 200)"
fi

# GET /health/live -> 200
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/health/live" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    pass "GET /health/live -> $RESPONSE"
else
    fail "GET /health/live -> $RESPONSE (expected 200)"
fi

# GET /health/ready -> 200 or 503
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/health/ready" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    pass "GET /health/ready -> $RESPONSE"
elif [ "$RESPONSE" = "503" ]; then
    warn "GET /health/ready -> $RESPONSE (service not fully ready)"
else
    fail "GET /health/ready -> $RESPONSE (expected 200 or 503)"
fi

# ── Security Headers ─────────────────────────────────────────
print_header "Security Headers"

HEADERS=$(curl -s -I --max-time 10 "$BASE_URL/health" 2>/dev/null || echo "")

# X-Content-Type-Options: nosniff
if echo "$HEADERS" | grep -qi "x-content-type-options.*nosniff"; then
    pass "X-Content-Type-Options: nosniff"
else
    fail "X-Content-Type-Options: nosniff header missing"
fi

# No X-Powered-By
if echo "$HEADERS" | grep -qi "x-powered-by"; then
    fail "X-Powered-By header present (should be removed)"
else
    pass "X-Powered-By header absent"
fi

# Strict-Transport-Security (only check on HTTPS)
if [ "$IS_HTTPS" = true ]; then
    if echo "$HEADERS" | grep -qi "strict-transport-security"; then
        pass "Strict-Transport-Security present"
    else
        fail "Strict-Transport-Security missing on HTTPS deployment"
    fi
else
    warn "Strict-Transport-Security skipped (not HTTPS)"
fi

# X-Frame-Options or CSP frame-ancestors
if echo "$HEADERS" | grep -qi "x-frame-options"; then
    pass "X-Frame-Options present"
elif echo "$HEADERS" | grep -qi "frame-ancestors"; then
    pass "CSP frame-ancestors present"
else
    warn "No X-Frame-Options or CSP frame-ancestors header"
fi

# ── API Structure ─────────────────────────────────────────────
print_header "API Structure"

# GET /nonexistent-route -> 404 JSON
RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 10 "$BASE_URL/nonexistent-route-test-12345" 2>/dev/null || echo -e "\n000")
STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "404" ]; then
    # Check if response is JSON
    if echo "$BODY" | python3 -m json.tool &>/dev/null; then
        pass "GET /nonexistent-route -> 404 JSON"
    else
        warn "GET /nonexistent-route -> 404 but response is not JSON"
    fi
else
    fail "GET /nonexistent-route -> $STATUS (expected 404)"
fi

# GET /api-docs should not be exposed in production
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/api-docs" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "404" ]; then
    pass "GET /api-docs -> 404 (not exposed)"
elif [ "$RESPONSE" = "200" ]; then
    warn "GET /api-docs -> 200 (should be disabled in production)"
else
    pass "GET /api-docs -> $RESPONSE"
fi

# ── Environment Validation ────────────────────────────────────
print_header "Environment Validation"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend-express"

if [ -f "$BACKEND_DIR/utils/envValidator.js" ]; then
    if [ -f "$BACKEND_DIR/.env" ]; then
        # Run env validation in a subprocess with NODE_ENV=development to trigger validation
        ENV_OUTPUT=$(cd "$BACKEND_DIR" && node -e "
            require('dotenv').config();
            process.env.NODE_ENV = process.env.NODE_ENV || 'development';
            try {
                const { validateEnvironment } = require('./utils/envValidator');
                const config = validateEnvironment();
                console.log('ENV_VALID');
            } catch (e) {
                console.error('ENV_ERROR: ' + e.message);
                process.exit(1);
            }
        " 2>&1) || true

        if echo "$ENV_OUTPUT" | grep -q "ENV_VALID"; then
            pass "Environment variables validated"
        elif echo "$ENV_OUTPUT" | grep -q "ENV_ERROR"; then
            ERROR_MSG=$(echo "$ENV_OUTPUT" | grep "ENV_ERROR" | sed 's/ENV_ERROR: //')
            fail "Environment validation failed: $ERROR_MSG"
        else
            warn "Environment validation returned unexpected output"
        fi
    else
        warn "backend-express/.env not found — skipping env validation"
    fi
else
    warn "envValidator.js not found — skipping env validation"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Results${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "  ${GREEN}$PASS passed${NC}  ${YELLOW}$WARN warnings${NC}  ${RED}$FAIL failed${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Deployment validation FAILED${NC}"
    echo ""
    exit 1
else
    echo -e "  ${GREEN}Deployment validation PASSED${NC}"
    echo ""
    exit 0
fi
