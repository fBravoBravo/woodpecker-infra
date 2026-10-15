#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Usage: $0 <registry-domain> <registry-user>"
    echo "Example: $0 registry.yourdomain.com registryuser"
    exit 1
fi

REGISTRY_DOMAIN=$1
REGISTRY_USER=$2

echo -e "${GREEN}=== Worker Machine Setup ===${NC}"

# Install Docker
echo -e "${YELLOW}[1/3] Installing Docker...${NC}"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "${USER}"
sudo systemctl enable docker
sudo systemctl start docker

# Configure Docker daemon for registry
echo -e "${YELLOW}[2/3] Configuring Docker daemon...${NC}"
sudo mkdir -p /etc/docker

# For a registry with valid Let's Encrypt cert, no insecure registry needed
# But we add it to daemon config for reliability
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker

# Login to registry
echo -e "${YELLOW}[3/3] Logging into registry...${NC}"
echo "You will be prompted for the registry password..."
docker login "https://${REGISTRY_DOMAIN}"

echo ""
echo -e "${GREEN}=== Worker Ready ===${NC}"
echo ""
echo "Test pulling an image:"
echo "  docker pull ${REGISTRY_DOMAIN}/your-image:tag"
echo ""
echo "To use in a Woodpecker pipeline on this machine:"
echo '  docker run --rm -v "$(pwd):/workspace" -w /workspace \'
echo "    ${REGISTRY_DOMAIN}/your-build-image:latest make build"
