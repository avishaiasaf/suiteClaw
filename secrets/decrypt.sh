#!/usr/bin/env bash
# Decrypts SOPS-encrypted secrets and writes individual files to secrets/decrypted/
# Called before docker compose up to populate secret files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_FILE="${SCRIPT_DIR}/secrets.enc.yaml"
OUTPUT_DIR="${SCRIPT_DIR}/decrypted"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "ERROR: Encrypted secrets file not found: $SECRETS_FILE"
    exit 1
fi

# Check if sops is installed
if ! command -v sops &> /dev/null; then
    echo "ERROR: sops is not installed. Install it: brew install sops"
    exit 1
fi

# Check if age key is available
if [ -z "${SOPS_AGE_KEY_FILE:-}" ] && [ -z "${SOPS_AGE_KEY:-}" ]; then
    # Default age key location
    DEFAULT_KEY="$HOME/.config/sops/age/keys.txt"
    if [ -f "$DEFAULT_KEY" ]; then
        export SOPS_AGE_KEY_FILE="$DEFAULT_KEY"
    else
        echo "ERROR: No age key found. Set SOPS_AGE_KEY_FILE or place key at $DEFAULT_KEY"
        exit 1
    fi
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Decrypt and extract individual secrets
echo "Decrypting secrets..."
DECRYPTED=$(sops -d "$SECRETS_FILE")

# Write each secret to its own file with restrictive permissions
while IFS=': ' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Trim whitespace
    value=$(echo "$value" | xargs)
    if [ -n "$value" ]; then
        echo -n "$value" > "${OUTPUT_DIR}/${key}"
        chmod 600 "${OUTPUT_DIR}/${key}"
    fi
done <<< "$DECRYPTED"

echo "Secrets decrypted to ${OUTPUT_DIR}/"
ls -la "${OUTPUT_DIR}/"
