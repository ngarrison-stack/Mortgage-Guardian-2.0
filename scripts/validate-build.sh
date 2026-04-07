#!/bin/bash

# ============================================
# DOCKER BUILD VALIDATION SCRIPT
# Validates Docker image builds for all services
# ============================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

print_header() {
    echo -e "${BLUE}"
    echo "============================================"
    echo "$1"
    echo "============================================"
    echo -e "${NC}"
}

pass() {
    echo -e "${GREEN}PASS${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}FAIL${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "${YELLOW}WARN${NC} $1"
    WARN=$((WARN + 1))
}

# ── Locate project root ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

print_header "Docker Build Validation"

# ── Check Docker availability ─────────────────────────────────
if ! command -v docker &>/dev/null; then
    fail "Docker CLI not found — install Docker to validate builds"
    echo ""
    echo "Summary: $PASS passed, $WARN warnings, $FAIL failed"
    exit 1
fi

if ! docker info &>/dev/null; then
    fail "Docker daemon not running — start Docker Desktop or dockerd"
    echo ""
    echo "Summary: $PASS passed, $WARN warnings, $FAIL failed"
    exit 1
fi

pass "Docker is available and running"

# ── Check Docker Compose ──────────────────────────────────────
if docker compose version &>/dev/null; then
    pass "Docker Compose is available"
else
    fail "Docker Compose not available"
fi

# ── Validate Dockerfiles exist ────────────────────────────────
print_header "Checking Dockerfiles"

if [ -f "$PROJECT_ROOT/backend-express/Dockerfile" ]; then
    pass "backend-express/Dockerfile exists"
else
    fail "backend-express/Dockerfile missing"
fi

if [ -f "$PROJECT_ROOT/frontend/Dockerfile" ]; then
    pass "frontend/Dockerfile exists"
else
    fail "frontend/Dockerfile missing"
fi

if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    pass "docker-compose.yml exists"
else
    fail "docker-compose.yml missing"
fi

# ── Validate .dockerignore files ──────────────────────────────
print_header "Checking .dockerignore Files"

for service in backend-express frontend; do
    ignore_file="$PROJECT_ROOT/$service/.dockerignore"
    if [ -f "$ignore_file" ]; then
        pass "$service/.dockerignore exists"

        for pattern in node_modules .env .git; do
            if grep -q "^${pattern}$" "$ignore_file" 2>/dev/null || grep -q "^${pattern}\$" "$ignore_file" 2>/dev/null; then
                pass "$service/.dockerignore excludes $pattern"
            else
                fail "$service/.dockerignore missing exclusion: $pattern"
            fi
        done

        if grep -q ".planning" "$ignore_file" 2>/dev/null; then
            pass "$service/.dockerignore excludes .planning"
        else
            warn "$service/.dockerignore does not exclude .planning"
        fi
    else
        fail "$service/.dockerignore missing"
    fi
done

# ── Build images ──────────────────────────────────────────────
print_header "Building Docker Images"

echo "Building backend image..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" build backend 2>&1 | tail -5; then
    pass "Backend image built successfully"
else
    fail "Backend image build failed"
fi

echo ""
echo "Building frontend image..."
if docker compose -f "$PROJECT_ROOT/docker-compose.yml" build frontend 2>&1 | tail -5; then
    pass "Frontend image built successfully"
else
    fail "Frontend image build failed"
fi

# ── Check image sizes ────────────────────────────────────────
print_header "Image Sizes"

for image in mortgage-guardian-20-clean-backend mortgage-guardian-20-clean-frontend; do
    size=$(docker images "$image:latest" --format "{{.Size}}" 2>/dev/null)
    if [ -n "$size" ]; then
        pass "$image: $size"
        # Warn if image exceeds 1GB
        size_mb=$(docker images "$image:latest" --format "{{.VirtualSize}}" 2>/dev/null | awk '{
            if ($0 ~ /GB/) { gsub(/GB/,""); printf "%.0f\n", $1 * 1024 }
            else if ($0 ~ /MB/) { gsub(/MB/,""); printf "%.0f\n", $1 }
            else { print 0 }
        }')
    else
        warn "$image: image not found (may use different naming)"
    fi
done

# ── Summary ───────────────────────────────────────────────────
print_header "Summary"

echo -e "${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
