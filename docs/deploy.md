# SL OpenClaw — Hetzner VPS Deployment Guide

Target: **Hetzner CPX32** (4 vCPU, 8GB RAM), fresh Ubuntu, domain available.

---

## Prerequisites

- Hetzner VPS with Ubuntu 22.04 or 24.04
- SSH access (root initially)
- A domain with DNS management access
- Your Anthropic API key

---

## Step 1: DNS Setup

Point your domain to the VPS IP address:

| Record | Name | Value |
|--------|------|-------|
| A | `n8n.yourdomain.com` | `<VPS_IP>` |
| A | `grafana.yourdomain.com` | `<VPS_IP>` (optional, for Phase 5 monitoring) |

DNS propagation: 5-15 min with Cloudflare, up to 48h with others. Verify with:
```bash
dig n8n.yourdomain.com +short
# Should return your VPS IP
```

---

## Step 2: Server Hardening

SSH into the VPS as root:

```bash
# Update system
apt update && apt upgrade -y

# Create deploy user
adduser deploy
usermod -aG sudo deploy

# Copy SSH keys to deploy user
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Disable root SSH + password auth
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Firewall
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

> **Important**: Before closing this SSH session, verify you can SSH as `deploy` in a separate terminal.

---

## Step 3: Install Dependencies

Still as root:

```bash
# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy

# Verify Docker Compose plugin
docker compose version
# Should show v2.x+

# age (encryption)
apt install -y age

# sops (secrets management)
SOPS_VERSION=3.9.4
curl -LO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64"
mv "sops-v${SOPS_VERSION}.linux.amd64" /usr/local/bin/sops
chmod +x /usr/local/bin/sops

# Build tools + git
apt install -y make git
```

---

## Step 4: Clone Repository

Switch to the deploy user:

```bash
su - deploy
```

Clone and set up the project:

```bash
sudo mkdir -p /opt/suiteclaw
sudo chown deploy:deploy /opt/suiteclaw

git clone git@github.com:avishaiasaf/suiteClaw.git /opt/suiteclaw
cd /opt/suiteclaw
```

> **Note**: You'll need SSH keys for the deploy user to access the private repo.
> Generate with `ssh-keygen -t ed25519` and add the public key to GitHub as a deploy key.

---

## Step 5: Generate Encryption Keys

```bash
cd /opt/suiteclaw

# Run first-time setup
make init
```

This will:
1. Generate an age keypair at `~/.config/sops/age/keys.txt`
2. Print the **public key** — copy it
3. Create `.env` from `.env.example`

Now configure:

```bash
# 1. Set the age public key in .sops.yaml
vim .sops.yaml
# Replace AGE_PUBLIC_KEY_PLACEHOLDER with the public key from above

# 2. Configure environment
vim .env
```

Set these values in `.env`:
```
N8N_HOST=n8n.yourdomain.com
ACME_EMAIL=your@email.com
TIMEZONE=Asia/Jerusalem
N8N_WORKER_REPLICAS=2
```

---

## Step 6: Configure Secrets

Generate strong passwords and edit the secrets file:

```bash
# Generate random passwords (copy each output)
openssl rand -base64 24  # pg_root_password
openssl rand -base64 24  # pg_n8n_password
openssl rand -base64 24  # pg_memory_password
openssl rand -base64 24  # pg_audit_password
openssl rand -base64 24  # redis_password
openssl rand -hex 32     # n8n_encryption_key (hex, no special chars)
```

Edit the secrets file:

```bash
vim secrets/secrets.enc.yaml
```

Replace every `CHANGE_ME_*` with the generated values. Also set `anthropic_api_key` to your real Anthropic API key.

Then encrypt and decrypt:

```bash
# Encrypt (commits safely to git)
make encrypt-secrets

# Decrypt to files Docker can mount
make decrypt-secrets

# Verify all secret files exist
ls -la secrets/decrypted/
# Should show: pg_root_password, pg_n8n_password, pg_memory_password,
#              pg_audit_password, redis_password, n8n_encryption_key,
#              anthropic_api_key
```

### Critical Backups

Back up these immediately — if lost, you cannot recover:

1. **Age private key**: `~/.config/sops/age/keys.txt`
2. **n8n encryption key**: the value you set (n8n encrypts all credentials with this)

Store copies in a password manager or offline secure location.

---

## Step 7: Launch the Stack

```bash
cd /opt/suiteclaw

# Start with production resource limits (tuned for CPX32)
make up-prod

# Watch startup logs (Ctrl+C to stop following)
make logs
```

### What happens on first start:

1. Traefik starts, requests Let's Encrypt certificate for your domain
2. PostgreSQL initializes: creates `n8n`, `memory`, `audit` databases
3. pgvector extension is enabled on the `memory` database
4. Audit tables + immutability triggers are created
5. Redis starts with password authentication
6. n8n main connects to PostgreSQL + Redis, starts the web UI
7. n8n workers connect and begin polling for jobs
8. OPA loads the Tier 1/2 policies

### Verify everything is healthy:

```bash
make health
```

Expected output:
```
=== SL OpenClaw Health Check ===

[OK] Traefik running
[OK] PostgreSQL running
[OK] Redis running
[OK] n8n Main running
[OK] n8n Worker running
[OK] OPA running

[OK] PostgreSQL accepts connections
[OK] Redis responds to ping
[OK] OPA health endpoint

[OK] n8n database exists
[OK] memory database exists
[OK] audit database exists
[OK] pgvector extension enabled

=== Results: 13 passed, 0 failed ===
```

---

## Step 8: Verify n8n

1. Open `https://n8n.yourdomain.com` in your browser
2. Create the initial owner account (first-time setup wizard)
3. Create a test workflow:
   - Add a **Manual Trigger** node
   - Add a **Set** node (set any value)
   - Connect them, click **Test Workflow**
4. Verify the execution ran on a worker:
   ```bash
   make logs-n8n
   # Look for: "Execution finished" from the worker container
   ```

---

## Step 9: Verify OPA

```bash
# From the VPS, test the policy engine
docker compose exec opa wget -qO- http://localhost:8181/health
# Should return: {}

# Test a Tier 1 read-only policy evaluation
docker compose exec opa wget -qO- --post-data='{"input":{"tier":1,"action_type":"query","client_id":"pilot-client"}}' \
  http://localhost:8181/v1/data/tier1/allow
# Should return: {"result":true}

# Test that writes are denied at Tier 1
docker compose exec opa wget -qO- --post-data='{"input":{"tier":1,"action_type":"create","client_id":"pilot-client"}}' \
  http://localhost:8181/v1/data/tier1/allow
# Should return: {"result":false}
```

---

## Step 10: First Backup

```bash
make backup-db
# Creates timestamped .sql.gz files in ./backups/
ls -la backups/
```

Set up a cron job for daily backups:

```bash
crontab -e
```

Add:
```
0 3 * * * cd /opt/suiteclaw && make backup-db >> /var/log/suiteclaw-backup.log 2>&1
```

---

## Resource Allocation (CPX32 — 4 vCPU, 8GB RAM)

The `docker-compose.prod.yml` sets these limits:

| Service | CPUs | Memory | Notes |
|---------|------|--------|-------|
| PostgreSQL | 1.5 | 2G | Shared across n8n + memory + audit DBs |
| Redis | 0.5 | 512M | Queue + caching |
| n8n Main | 1.0 | 2G | UI + webhooks + API |
| n8n Worker x2 | 1.0 each | 2G each | Workflow execution |
| OPA | 0.5 | 256M | Policy evaluation |
| Traefik | 0.5 | 256M | Reverse proxy |

Total: ~4 vCPU, ~7GB RAM allocated (leaves headroom for OS).

---

## Troubleshooting

### Traefik can't get Let's Encrypt cert
- Verify DNS A record points to VPS IP: `dig n8n.yourdomain.com +short`
- Port 80 must be open (Let's Encrypt HTTP challenge): `ufw status`
- Check Traefik logs: `docker compose logs traefik`

### n8n shows "Bad Gateway"
- PostgreSQL may still be initializing. Wait 30s, retry
- Check logs: `make logs-n8n`
- Verify PostgreSQL is healthy: `docker compose exec postgres pg_isready`

### Redis healthcheck fails
- The healthcheck needs auth. If it's failing, check:
  ```bash
  docker compose exec redis redis-cli -a "$(cat secrets/decrypted/redis_password)" ping
  ```

### PostgreSQL init scripts fail
- Check init logs: `docker compose logs postgres`
- If the database users already exist (from a previous run), drop volumes:
  ```bash
  docker compose down -v  # WARNING: destroys all data
  make up-prod
  ```

### "Permission denied" on secrets
- Ensure `secrets/decrypted/` files are owned by the deploy user
- Run: `chmod 600 secrets/decrypted/*`

### OPA returns empty/error
- Verify policies are mounted: `docker compose exec opa ls /policies/`
- Check OPA logs: `make logs-opa`

---

## Useful Commands

```bash
make help              # List all available commands
make status            # Container status
make logs              # Tail all logs
make logs-n8n          # Tail n8n logs only
make health            # Run health checks
make backup-db         # Backup databases
make db-shell          # PostgreSQL interactive shell
make db-shell-audit    # PostgreSQL shell → audit database
make scale-workers N=3 # Scale workers (if you upgrade VPS)
make edit-secrets      # Edit encrypted secrets in-place
```

---

## Next Steps After Deployment

Once the stack is running and verified:

1. **Phase 1**: Configure the NetSuite MCP connector and build the master router n8n workflow
2. Deploy the tool-router RESTlet to your NetSuite sandbox
3. Create the first SuiteQL generation workflow in n8n
4. Test end-to-end: Slack message → intent classification → SuiteQL → results
