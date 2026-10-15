# 🪵 Woodpecker CI + Docker Registry on Hetzner

Production-ready CI/CD with a private Docker Registry, automatic SSL, and a worker-ready deployment setup.

---

## 📐 Architecture

```
┌─────────────────────────────────────────┐
│         Hetzner Cloud VM                │
│  ┌─────────────────────────────────┐    │
│  │  Traefik (Reverse Proxy + SSL)  │    │
│  └─────────────────────────────────┘    │
│         │         │         │            │
│    ┌────┘    ┌────┘    ┌────┘           │
│    ▼         ▼         ▼                 │
│ ┌────────┐ ┌────────┐ ┌────────────┐    │
│ │Woodpeck│ │Woodpeck│ │   Docker   │    │
│ │ Server │ │ Agent  │ │  Registry  │    │
│ └────────┘ └────────┘ └────────────┘    │
└─────────────────────────────────────────┘
                    │
                    │ docker pull/push
                    ▼
┌─────────────────────────────────────────┐
│          Second Machine (Worker)        │
│         (fetches images from            │
│            private registry)              │
└─────────────────────────────────────────┘
```

---

## 🚀 Prerequisites

1. **Hetzner Cloud Account** - [hetzner.com/cloud](https://www.hetzner.com/cloud/)
2. **Domain Name** - with DNS management access (Cloudflare, etc.)
3. **GitHub Account** - for OAuth integration
4. **SSH Key** - loaded into Hetzner for server access

---

## 📋 Step-by-Step Deployment

### Step 1: Create Your Hetzner Server

**Recommended specs for CI + Registry:**
- **Type:** Shared vCPU (CX21) minimum, CPX31 recommended
- **OS:** Debian 12 or Ubuntu 22.04 LTS
- **Disk:** 40-80 GB (registry images take space)
- **Location:** Pick closest to you/workers
- **Firewalls:** We'll use UFW inside the VM

**Add your SSH key** in the Hetzner console when creating the server.

### Step 2: Configure DNS Records

Point these A records to your Hetzner VM's public IP:

| Record | Target | Purpose |
|--------|--------|---------|
| `ci` | `your-server-ip` | Woodpecker UI |
| `registry` | `your-server-ip` | Docker Registry |
| `ui.registry` | `your-server-ip` | Registry Web UI (optional) |
| `traefik` | `your-server-ip` | Traefik Dashboard (optional) |

**Example:** If your domain is `example.com`:
- `ci.example.com`
- `registry.example.com`

### Step 3: Initial Server Setup

SSH into your new Hetzner VM and run the setup script:

```bash
# 1. SSH into the server
ssh root@your-server-ip

# 2. Create a user (recommended instead of root)
adduser deploy
usermod -aG sudo deploy
usermod -aG docker deploy

# 3. Switch to the user
su - deploy

# 4. Clone/copy this repo to ~/woodpecker-infra
git clone <your-repo> ~/woodpecker-infra
cd ~/woodpecker-infra

# 5. Run the host setup
./scripts/setup-host.sh

# 6. IMPORTANT: Log out and back in (or run `newgrp docker`)
exit
ssh deploy@your-server-ip
cd ~/woodpecker-infra
```

This installs Docker, Docker Compose, UFW firewall, and creates necessary directories.

### Step 4: Configure Environment Variables

```bash
cp .env.example .env
nano .env  # or vim
```

Fill in **all** values:

```env
# Your domain
BASE_DOMAIN=example.com
ACME_EMAIL=your-email@example.com

# Generate this with: htpasswd -nbB admin "yourpassword"
# Replace $ with $$ in the output for Docker Compose
TRAEFIK_AUTH=admin:$$2y$$10$$...

# Woodpecker
WOODPECKER_DOMAIN=ci.example.com
WOODPECKER_ADMIN_USERS=yourgithubusername
GITHUB_CLIENT=xxx          # From GitHub OAuth App
GITHUB_SECRET=xxx          # From GitHub OAuth App

# Registry
REGISTRY_DOMAIN=registry.example.com
REGISTRY_USER=registryuser
REGISTRY_PASSWORD=supersecurepassword123
```

### Step 5: Create GitHub OAuth App

Woodpecker requires OAuth to authenticate users. Here's how to set it up with GitHub:

1. Go to **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**
2. Fill in:
   - **Application name:** `Woodpecker CI`
   - **Homepage URL:** `https://ci.example.com`
   - **Authorization callback URL:** `https://ci.example.com/authorize`
3. Click **Register application**
4. Click **Generate a new client secret**
5. Copy **Client ID** and **Client Secret** into your `.env` file

### Step 6: Generate Registry Authentication

```bash
cd ~/woodpecker-infra
make setup
# or: ./scripts/generate-registry-auth.sh
```

This creates `registry/auth/htpasswd` for Docker registry login.

### Step 7: Start Everything

```bash
cd ~/woodpecker-infra
make start
# or: docker compose up -d
```

Wait ~30 seconds for Traefik to fetch SSL certificates, then visit:
- **Woodpecker:** https://ci.example.com
- **Registry:** https://registry.example.com (no UI, API only)
- **Registry UI:** https://ui.registry.example.com
- **Traefik Dashboard:** https://traefik.example.com (optional)

---

## 🖥️ Worker Machine Setup

Your second machine needs Docker and registry login credentials to pull images.

### Option A: Run the Setup Script

On your **second machine** (the worker):

```bash
# Copy the script over
scp scripts/setup-worker.sh user@worker-ip:/tmp/

# SSH to worker and run it
ssh user@worker-ip
sudo bash /tmp/setup-worker.sh registry.example.com registryuser
# Enter password when prompted
```

### Option B: Manual Steps

```bash
# Install Docker (Debian/Ubuntu)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Login to your private registry
docker login registry.example.com
# Enter username and password from .env

# Test pulling
# (push an image first from CI or locally)
docker pull registry.example.com/myapp:latest
```

---

## 🔄 Using the Registry in CI Pipelines

### Method 1: Registry Secrets in Woodpecker

In the Woodpecker UI, add secrets to your repository:

| Secret Name | Value |
|-------------|-------|
| `registry_username` | `registryuser` |
| `registry_password` | `supersecurepassword123` |

Then use in `.woodpecker.yml`:

```yaml
steps:
  build-and-push:
    image: plugins/docker
    settings:
      registry: registry.example.com
      repo: registry.example.com/myapp
      tags: [latest, "${CI_COMMIT_SHA:0:8}"]
      username:
        from_secret: registry_username
      password:
        from_secret: registry_password
```

### Method 2: Pre-authenticated Agent (Simpler)

If you want all pipelines to be pre-authenticated with your registry, mount the Docker config into the agent:

```bash
# On the server, log docker into the registry
docker login registry.example.com

# Copy config to a shared location
cp ~/.docker/config.json ~/woodpecker-infra/registry/docker-config.json
```

Then update `docker-compose.yml` for the agent:

```yaml
  woodpecker-agent:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./registry/docker-config.json:/root/.docker/config.json:ro
```

Restart: `docker compose up -d`

---

## 🔌 Adding a Remote Woodpecker Agent (Advanced)

If you want the **second machine to also run CI builds**, install an agent there instead of (or in addition to) the server:

```bash
# On the WORKER machine:
docker run -d \
  --name woodpecker-agent \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e WOODPECKER_SERVER=ci.example.com:9000 \
  -e WOODPECKER_AGENT_SECRET=<same-secret-from-.env> \
  -e WOODPECKER_MAX_WORKFLOWS=2 \
  woodpeckerci/woodpecker-agent:v2
```

Make sure port `9000` is accessible (adjust UFW on the server):

```bash
sudo ufw allow from worker-ip to any port 9000
```

---

## 🔧 Maintenance Commands

```bash
# View logs
make logs
# docker compose logs -f --tail=50 [service]

# Restart a service
docker compose restart registry

# Update images
make pull && make start

# Backup registry data
sudo tar czvf registry-backup-$(date +%F).tar.gz /var/lib/docker/volumes/woodpecker-infra_registry-data/

# Clean up old images from registry
# Use the Registry UI at https://ui.registry.example.com
# Or API: curl -u user:pass -X DELETE https://registry.example.com/v2/<name>/manifests/<ref>

# Free disk space
docker system prune -a --volumes
```

---

## 🔒 Security Checklist

- [ ] All services use HTTPS (Traefik + Let's Encrypt)
- [ ] Registry has basic auth enabled
- [ ] UFW firewall active (only 22, 80, 443 open)
- [ ] Woodpecker uses strong agent secret
- [ ] Traefik dashboard has basic auth
- [ ] `.env` file is NOT committed to git
- [ ] `registry/auth/htpasswd` is NOT committed to git
- [ ] GitHub OAuth secret is rotated periodically
- [ ] Server SSH uses key-only auth, password disabled
- [ ] Regular backups of `woodpecker-server-data` volume

---

## 🐛 Troubleshooting

### "Bad Gateway" when accessing Woodpecker
```bash
docker compose logs woodpecker-server
# Check if OAuth is configured correctly
# Verify WOODPECKER_HOST matches the URL you visit
```

### Registry login fails
```bash
# Verify htpasswd exists
cat registry/auth/htpasswd

# Test registry directly
curl -u user:pass https://registry.example.com/v2/_catalog
```

### SSL certificate not issued
```bash
docker compose logs traefik
# Ensure DNS records point to the server IP
# Traefik needs port 80 open for ACME challenge
```

### Agent won't connect
```bash
# Verify agent secret matches server
docker compose logs woodpecker-agent
# If remote agent, ensure port 9000 is reachable
nc -zv ci.example.com 9000
```

### No space left on device
```bash
# Registry images consume space!
df -h
docker system df
docker system prune -a  # CAREFUL: removes unused images
```

---

## 📦 Project Structure

```
woodpecker-infra/
├── docker-compose.yml          # All services
├── .env.example                # Configuration template
├── Makefile                    # Common commands
├── README.md                   # This file
├── registry/
│   ├── config.yml              # Registry configuration
│   └── auth/                   # htpasswd generated here
├── scripts/
│   ├── setup-host.sh           # Initial server setup
│   ├── setup-worker.sh         # Worker machine setup
│   └── generate-registry-auth.sh  # Creates htpasswd
└── example-pipeline/
    ├── .woodpecker.yml         # Sample CI pipeline
    └── Dockerfile              # Sample Dockerfile
```

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Start all | `make start` |
| Stop all | `make stop` |
| View logs | `make logs` |
| Update images | `make pull && make start` |
| Registry login | `docker login registry.example.com` |
| Push image | `docker push registry.example.com/myapp:latest` |
| Pull image | `docker pull registry.example.com/myapp:latest` |

---

## 📝 Next Steps

1. **Add your first repo** in the Woodpecker UI
2. **Copy `.woodpecker.yml`** from `example-pipeline/` into your project
3. **Push to GitHub** and watch the build!
4. **Set up deployment** to your worker machine via SSH or webhook

---

Built with ❤️ for self-hosted CI/CD.
