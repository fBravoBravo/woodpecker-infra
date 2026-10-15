#!/bin/bash
set -euo pipefail

# =============================================================================
# Initial server prep for Coolify deployment on Contabo Cloud VPS
# Run this once after SSH-ing into your fresh Contabo server.
#
# NOTE: If you selected Coolify from the Contabo Marketplace (pre-installed),
# this script is OPTIONAL. You only need this for a bare Ubuntu/Debian image.
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Contabo Cloud VPS Prep for Coolify ===${NC}"

# ── Update system ────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/5] Updating system packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get install -y \
    curl \
    wget \
    git \
    nano \
    htop \
    apache2-utils \
    ufw \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# ── Configure timezone ───────────────────────────────────────────────────────
echo -e "${YELLOW}[2/5] Setting timezone to UTC...${NC}"
timedatectl set-timezone UTC || true

# ── Basic UFW firewall ───────────────────────────────────────────────────────
echo -e "${YELLOW}[3/5] Configuring UFW firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
# Coolify dashboard port (you can close this after setting up the domain)
ufw allow 8000/tcp
# Optional: Coolify real-time service
ufw allow 6001/tcp
# Optional: Coolify SSH multiplexing
ufw allow 6002/tcp

ufw --force enable

# ── Optional: Create non-root user ──────────────────────────────────────────
echo -e "${YELLOW}[4/5] Creating 'deploy' user (optional but recommended)...${NC}"
if ! id "deploy" &>/dev/null; then
    adduser --gecos "" --disabled-password deploy
    usermod -aG sudo deploy
    echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy
    chmod 440 /etc/sudoers.d/deploy
    echo -e "${GREEN}User 'deploy' created. Set a password:${NC}"
    passwd deploy
else
    echo -e "${YELLOW}User 'deploy' already exists — skipping.${NC}"
fi

# ── Next steps ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}=== Server is ready for Coolify ===${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Copy your SSH key to the deploy user (optional):"
echo "   ssh-copy-id deploy@$(hostname -I | awk '{print $1}')"
echo ""
echo "2. Switch to deploy user and install Coolify:"
echo "   su - deploy"
echo "   curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash"
echo ""
echo "3. Open Coolify in your browser:"
echo "   http://$(hostname -I | awk '{print $1}'):8000"
echo ""
echo "4. Follow the full guide: COOLIFY.md in your repo"
echo ""
echo -e "${YELLOW}DNS records must point to: $(hostname -I | awk '{print $1}')${NC}"
