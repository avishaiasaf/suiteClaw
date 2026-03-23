# SL OpenClaw — SolutionLab AI Employee

Autonomous AI employee for NetSuite consulting. Uses n8n as the orchestration backbone, Claude as the reasoning engine, MCP for tool connectivity, and a 4-tier permission model with human-in-the-loop gates for financial operations.

## Architecture

```
Traefik (HTTPS) → n8n Main (UI/Webhooks) → Redis (BullMQ) → n8n Workers
                                                                 ↓
                                              PostgreSQL 16 (state + audit + memory)
                                                                 ↓
                    Claude API ← → OPA Policy Engine ← → NetSuite MCP / RESTlet
```

## Quick Start

### Prerequisites
- Docker & Docker Compose v2
- [age](https://github.com/FiloSottile/age) (`brew install age`)
- [sops](https://github.com/getsops/sops) (`brew install sops`)

### Setup

```bash
# 1. Initialize encryption keys and .env
make init

# 2. Edit .env with your domain
vim .env

# 3. Update .sops.yaml with your age public key (from step 1)
vim .sops.yaml

# 4. Set real passwords in secrets file
vim secrets/secrets.enc.yaml

# 5. Encrypt secrets
make encrypt-secrets

# 6. Decrypt for Docker to mount
make decrypt-secrets

# 7. Start the stack
make up

# 8. Verify health
make health
```

### Common Operations

```bash
make up              # Start services (dev)
make up-prod         # Start services (production with resource limits)
make down            # Stop services
make logs            # Tail all logs
make logs-n8n        # Tail n8n logs only
make status          # Container status
make health          # Health check all services
make backup-db       # Backup all databases
make db-shell        # PostgreSQL shell
make scale-workers N=3  # Scale n8n workers
```

## Permission Tiers

| Tier | Approval | Examples |
|------|----------|----------|
| 1 — Read-only | Auto-approve | SuiteQL queries, record reads, reports |
| 2 — Low-risk | Auto + logging | Draft emails, ClickUp tasks, time logging |
| 3 — Medium | Single approval | Record updates, vendor bills under $1K |
| 4 — High-value | Dual approval + evidence | Transactions over $10K, production deploys |

## Directory Structure

- `docker-compose.yml` — Core infrastructure services
- `traefik/` — Reverse proxy & TLS configuration
- `postgres/init/` — Database initialization scripts
- `n8n/workflows/` — n8n workflow JSON exports (by phase)
- `opa/` — Open Policy Agent policies and permission data
- `agent/prompts/` — Claude system prompts and routing logic
- `agent/config/` — Model routing and client configuration
- `netsuite/restlets/` — SuiteScript RESTlet tool router
- `netsuite/sdf-project/` — SDF project for deployments
- `secrets/` — SOPS-encrypted secrets
- `audit/` — Audit schema and retention policies
- `scripts/` — Operational scripts (backup, restore, health)

## Phases

See `docs/architecture.md` for the full 6-phase implementation plan.
