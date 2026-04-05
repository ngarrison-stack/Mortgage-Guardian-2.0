#!/bin/bash
# Health Endpoint E2E Verification Script
# Run this script to verify the API health endpoint works correctly

set -e

PORT=${PORT:-3000}
BASE_URL="http://localhost:${PORT}"

echo "====================================="
echo "Health Endpoint E2E Verification"
echo "====================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ "$1" = "pass" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    elif [ "$1" = "fail" ]; then
        echo -e "${RED}✗ FAIL${NC}: $2"
    else
        echo -e "${YELLOW}● INFO${NC}: $2"
    fi
}

# Step 1: Check if server is running
echo "Step 1: Checking server availability..."
if curl -s --connect-timeout 5 "${BASE_URL}/health" > /dev/null 2>&1; then
    print_status "pass" "Server is running on port ${PORT}"
else
    print_status "fail" "Server is not running. Start with: cd backend-express && npm run dev"
    echo ""
    echo "To start the server:"
    echo "  cd backend-express"
    echo "  npm install"
    echo "  npm run dev"
    echo ""
    exit 1
fi

# Step 2: Test GET /health returns 200
echo ""
echo "Step 2: Testing GET /health returns 200..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health")
if [ "$HTTP_STATUS" = "200" ]; then
    print_status "pass" "GET /health returns HTTP 200"
else
    print_status "fail" "GET /health returned HTTP ${HTTP_STATUS} (expected 200)"
    exit 1
fi

# Step 3: Test response includes status: healthy
echo ""
echo "Step 3: Verifying response includes status: healthy..."
RESPONSE=$(curl -s "${BASE_URL}/health")
if echo "$RESPONSE" | grep -q '"status":"healthy"'; then
    print_status "pass" "Response includes status: healthy"
else
    print_status "fail" "Response does not include status: healthy"
    echo "Response received: $RESPONSE"
    exit 1
fi

# Step 4: Verify response structure
echo ""
echo "Step 4: Verifying response structure..."
REQUIRED_FIELDS=("status" "timestamp" "uptime" "environment" "version" "services")
ALL_FIELDS_PRESENT=true

for field in "${REQUIRED_FIELDS[@]}"; do
    if echo "$RESPONSE" | grep -q "\"$field\""; then
        print_status "pass" "Field '$field' present"
    else
        print_status "fail" "Field '$field' missing"
        ALL_FIELDS_PRESENT=false
    fi
done

if [ "$ALL_FIELDS_PRESENT" = false ]; then
    exit 1
fi

# Step 5: Display full response
echo ""
echo "Step 5: Full health response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# Summary
echo ""
echo "====================================="
echo -e "${GREEN}All E2E verification tests passed!${NC}"
echo "====================================="
echo ""
echo "Health endpoint is working correctly."
echo ""
echo "To test graceful shutdown:"
echo "  1. Start server: npm run dev"
echo "  2. Send SIGTERM: kill -SIGTERM <pid>"
echo "  3. Verify log: 'SIGTERM received, shutting down gracefully'"
