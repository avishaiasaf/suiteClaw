.PHONY: help up down restart logs status decrypt-secrets encrypt-secrets backup-db restore-db health init

COMPOSE = docker compose
COMPOSE_PROD = docker compose -f docker-compose.yml -f docker-compose.prod.yml

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Lifecycle ───────────────────────────────────────────────

init: ## First-time setup: generate age keys, create .env, decrypt secrets
	@echo "=== Setting up age encryption keys ==="
	@bash scripts/setup-age-keys.sh
	@echo ""
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example — edit it with your values"; fi
	@echo ""
	@echo "=== Next steps ==="
	@echo "1. Edit .env with your domain and email"
	@echo "2. Update .sops.yaml with your age public key"
	@echo "3. Edit secrets/secrets.enc.yaml with real passwords"
	@echo "4. Run: make encrypt-secrets"
	@echo "5. Run: make decrypt-secrets"
	@echo "6. Run: make up"

up: ## Start all services (dev mode)
	$(COMPOSE) up -d

up-prod: ## Start all services (production mode with resource limits)
	$(COMPOSE_PROD) up -d

down: ## Stop all services
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

logs: ## Tail all service logs
	$(COMPOSE) logs -f --tail=100

logs-n8n: ## Tail n8n main + worker logs
	$(COMPOSE) logs -f --tail=100 n8n-main n8n-worker

logs-opa: ## Tail OPA logs
	$(COMPOSE) logs -f --tail=100 opa

status: ## Show container status
	$(COMPOSE) ps

# ─── Scaling ─────────────────────────────────────────────────

scale-workers: ## Scale n8n workers (usage: make scale-workers N=3)
	$(COMPOSE) up -d --scale n8n-worker=$(N)

# ─── Secrets ─────────────────────────────────────────────────

decrypt-secrets: ## Decrypt SOPS secrets to secrets/decrypted/
	@bash secrets/decrypt.sh

encrypt-secrets: ## Encrypt secrets file with SOPS
	sops -e -i secrets/secrets.enc.yaml

edit-secrets: ## Edit encrypted secrets in-place
	sops secrets/secrets.enc.yaml

# ─── Database ────────────────────────────────────────────────

backup-db: ## Backup PostgreSQL databases
	@bash scripts/backup-postgres.sh

restore-db: ## Restore PostgreSQL from backup (usage: make restore-db FILE=backup.sql.gz)
	@bash scripts/restore-postgres.sh $(FILE)

db-shell: ## Open PostgreSQL shell
	$(COMPOSE) exec postgres psql -U postgres

db-shell-audit: ## Open PostgreSQL shell to audit database
	$(COMPOSE) exec postgres psql -U postgres -d audit

# ─── Health ──────────────────────────────────────────────────

health: ## Run health checks on all services
	@bash scripts/health-check.sh

# ─── Cleanup ─────────────────────────────────────────────────

clean: ## Remove all data volumes (DESTRUCTIVE)
	@echo "WARNING: This will delete all data volumes!"
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] && $(COMPOSE) down -v || echo "Aborted."

prune: ## Remove unused Docker resources
	docker system prune -f
