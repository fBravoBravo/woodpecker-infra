#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$INFRA_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Please copy .env.example to .env and configure it first."
    exit 1
fi

# Source the env file for variables
set -a
source "$ENV_FILE"
set +a

# Create auth directory
mkdir -p "$INFRA_DIR/registry/auth"

echo "Generating registry htpasswd file..."
htpasswd -Bbn "${REGISTRY_USER}" "${REGISTRY_PASSWORD}" > "$INFRA_DIR/registry/auth/htpasswd"

echo "Registry auth created at: $INFRA_DIR/registry/auth/htpasswd"
echo ""
echo "Credentials:"
echo "  User: ${REGISTRY_USER}"
echo "  Password: ${REGISTRY_PASSWORD}"
