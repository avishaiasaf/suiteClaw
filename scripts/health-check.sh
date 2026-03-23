#!/usr/bin/env bash
# Health check for all SL OpenClaw services
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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
check "PostgreSQL running" "docker compose ps postgres --format '{{.State}}' | grep -q running"
check "Redis running" "docker compose ps redis --format '{{.State}}' | grep -q running"
check "n8n Main running" "docker compose ps n8n-main --format '{{.State}}' | grep -q running"
check "n8n Worker running" "docker compose ps n8n-worker --format '{{.State}}' | grep -q running"
check "OPA running" "docker compose ps opa --format '{{.State}}' | grep -q running"

echo ""

# Service responsiveness
check "PostgreSQL accepts connections" "docker compose exec -T postgres pg_isready -U postgres"
check "Redis responds to ping" "docker compose exec -T redis redis-cli ping"
check "OPA health endpoint" "docker compose exec -T opa wget -q --spider http://localhost:8181/health"

echo ""

# Database checks
check "n8n database exists" "docker compose exec -T postgres psql -U postgres -lqt | grep -q n8n"
check "memory database exists" "docker compose exec -T postgres psql -U postgres -lqt | grep -q memory"
check "audit database exists" "docker compose exec -T postgres psql -U postgres -lqt | grep -q audit"
check "pgvector extension enabled" "docker compose exec -T postgres psql -U postgres -d memory -c 'SELECT 1 FROM pg_extension WHERE extname = '\''vector'\'';' | grep -q 1"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
