#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Hetzner VM Setup for Woodpecker CI + Docker Registry ===${NC}"

# Update system
echo -e "${YELLOW}[1/6] Updating system packages...${NC}"
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apache2-utils \
    git \
    ufw

# Install Docker
echo -e "${YELLOW}[3/6] Installing Docker...${NC}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
echo -e "${YELLOW}[4/6] Configuring Docker...${NC}"
sudo usermod -aG docker "${USER}"

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Configure UFW firewall
echo -e "${YELLOW}[5/6] Configuring firewall...${NC}"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Create directories
echo -e "${YELLOW}[6/6] Creating project directories...${NC}"
mkdir -p ~/woodpecker-infura
mkdir -p ~/woodpecker-infra/traefik/letsencrypt
mkdir -p ~/woodpecker-infra/registry/auth

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Log out and back in (or run 'newgrp docker') for Docker permissions"
echo "2. Clone/copy your woodpecker-infra folder to ~/woodpecker-infra"
echo "3. Copy .env.example to .env and fill in your values"
echo "4. Run ./scripts/generate-registry-auth.sh"
echo "5. Run 'docker compose up -d'"
echo ""
echo "IMPORTANT: Point these DNS records to this server's IP:"
echo "  - ci.yourdomain.com"
echo "  - registry.yourdomain.com"
echo "  - ui.registry.yourdomain.com (optional)"
