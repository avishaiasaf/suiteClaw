#!/usr/bin/env bash
# Health check for SL OpenClaw services
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} $name"
        ((PASS++))
    else
        echo -e "${RED}[FAIL]${NC} $name"
        ((FAIL++))
    fi
}

echo "=== SL OpenClaw Health Check ==="
echo ""

# Container status
check "Traefik running" "docker compose ps traefik --format '{{.State}}' | grep -q running"
check "OpenClaw running" "docker compose ps openclaw --format '{{.State}}' | grep -q running"
check "PostgreSQL running" "docker compose ps postgres --format '{{.State}}' | grep -q running"
check "OPA running" "docker compose ps opa --format '{{.State}}' | grep -q running"

echo ""

# Service responsiveness
check "PostgreSQL accepts connections" "docker compose exec -T postgres pg_isready -U postgres"
check "OPA health endpoint" "docker compose exec -T opa wget -q --spider http://localhost:8181/health"
check "OpenClaw gateway responding" "docker compose exec -T openclaw wget -q --spider http://localhost:18789/healthz 2>/dev/null || curl -sf http://localhost:18789/healthz >/dev/null 2>&1"

echo ""

# Database checks
check "audit database exists" "docker compose exec -T postgres psql -U postgres -lqt | grep -q audit"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
