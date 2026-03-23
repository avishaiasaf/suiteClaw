#!/usr/bin/env bash
# Generates a new age keypair for SOPS encryption
set -euo pipefail

KEY_DIR="$HOME/.config/sops/age"
KEY_FILE="${KEY_DIR}/keys.txt"

if [ -f "$KEY_FILE" ]; then
    echo "Age key already exists at: $KEY_FILE"
    echo "Public key:"
    grep "public key:" "$KEY_FILE" | awk '{print $NF}'
    exit 0
fi

# Check if age is installed
if ! command -v age-keygen &> /dev/null; then
    echo "ERROR: age is not installed. Install it: brew install age"
    exit 1
fi

mkdir -p "$KEY_DIR"
age-keygen -o "$KEY_FILE" 2>&1
chmod 600 "$KEY_FILE"

echo ""
echo "Age keypair generated at: $KEY_FILE"
echo ""
echo "NEXT STEPS:"
echo "1. Copy the public key above"
echo "2. Replace AGE_PUBLIC_KEY_PLACEHOLDER in .sops.yaml with your public key"
echo "3. Edit secrets/secrets.enc.yaml with real values"
echo "4. Run: sops -e -i secrets/secrets.enc.yaml"
echo "5. BACK UP your private key file: $KEY_FILE"
echo "   If you lose this key, you cannot decrypt your secrets!"
