# SL OpenClaw — SolutionLab AI Employee

OpenClaw-based autonomous AI employee for NetSuite consulting. Connects to Slack and Telegram as a SolutionLab team member, uses your existing n8n instance for NetSuite operations via MCP.

## Architecture

```
Slack / Telegram
      ↓
OpenClaw Gateway (port 18789)
  ├── Claude Sonnet (reasoning)
  ├── Memory (SQLite + embeddings)
  ├── SOUL.md (SolutionLab identity)
  └── MCP tools → your n8n instance → NetSuite
      ↓
OPA Policy Engine (permission tiers)
      ↓
PostgreSQL (audit logs)
```

## Quick Start

```bash
make init                    # Generate keys, create .env
vim .env                     # Set API keys, channel tokens
make encrypt-secrets         # Encrypt secrets
make decrypt-secrets         # Decrypt for Docker
make up-prod                 # Start the stack
make logs-openclaw           # Watch OpenClaw startup
make health                  # Verify all services
```

## Configuration

All OpenClaw config lives in the `openclaw/` directory:

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent identity — who it is, what it does, its principles |
| `AGENTS.md` | Boot sequence, message handling rules, permission tiers |
| `USER.md` | Your profile (handler context) |
| `MEMORY.md` | Long-term knowledge (clients, decisions, history) |
| `config.json` | LLM provider, channels, MCP tools, memory search config |
| `skills/netsuite/` | NetSuite operations — SuiteQL patterns, tool docs |
| `skills/suitescript/` | SuiteScript generation — templates, conventions |
| `skills/client-comms/` | Client communication — email templates, tone |
| `memory/` | Daily work logs (auto-created YYYY-MM-DD.md files) |

## Commands

```bash
make help              # All available commands
make logs-openclaw     # OpenClaw logs
make shell             # Shell inside OpenClaw container
make dashboard         # Get dashboard URL + auth token
make channels          # List configured channels
make doctor            # OpenClaw diagnostics
make health            # Health check all services
make backup-db         # Backup audit database
```

## Connecting to n8n

Set `N8N_MCP_URL` and `N8N_API_KEY` in `.env` to connect OpenClaw to your existing n8n instance. n8n must have MCP server mode enabled. The agent will discover available workflows as tools automatically.

## Deployment

See `docs/deploy.md` for full Hetzner VPS deployment instructions.
