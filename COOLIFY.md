# 🚀 Deploy Woodpecker CI + Registry Inside Coolify (on Contabo Cloud VPS)

This guide deploys **Woodpecker CI**, a **private Docker Registry**, and **Coolify** itself on a single Contabo Cloud VPS. Coolify acts as the "boss" — it handles SSL, reverse proxy, and gives you a slick PaaS dashboard to manage everything.

---

## 📐 Architecture

```
Contabo Cloud VPS 6 (or your chosen tier)
├─ Coolify (PaaS orchestrator + Traefik + SSL)
│  ├─ 🪵 Woodpecker Server  → https://ci.yourdomain.com
│  ├─ 🪵 Woodpecker Agent   → builds your pipelines
│  ├─ 📦 Docker Registry    → https://registry.yourdomain.com
│  └─ 🖥️ Registry UI       → https://ui.registry.yourdomain.com
│
└─ Your future apps deployed via Coolify UI
   ├─ https://app1.yourdomain.com
   └─ https://api.yourdomain.com  etc.
```

---

## 🛒 Step 0: Buy the Server (Contabo Cloud VPS)

| Tier | Specs | Price | Good For |
|------|-------|-------|----------|
| **Cloud VPS 6** | 6 vCPU / 16 GB RAM / 400 GB NVMe | ~€10–13/mo | **Recommended** — room to grow |
| Cloud VPS 4 | 4 vCPU / 8 GB RAM / 200 GB NVMe | ~€7–9/mo | Tight budget, limited apps |
| Cloud VPS 8 | 8 vCPU / 32 GB RAM / 800 GB NVMe | ~€15–18/mo | Multiple apps + heavy CI |

**Why Cloud VPS over Classic?** Modern AMD EPYC CPUs, Gen4 NVMe, and much better network (multi-Gbit). CI builds won't feel sluggish.

**OS:** Ubuntu 22.04 LTS or Debian 12

---

## 🌐 Step 1: Point Your DNS

Create **A records** pointing to your Contabo VPS IP:

| Subdomain | Points To | Purpose |
|-----------|-----------|---------|
| `coolify` | Your VPS IP | Coolify dashboard |
| `ci` | Your VPS IP | Woodpecker CI |
| `registry` | Your VPS IP | Docker Registry |
| `ui.registry` | Your VPS IP | Registry web UI |

**Example:** If you own `example.com`:
- `coolify.example.com`
- `ci.example.com`
- `registry.example.com`
- `ui.registry.example.com`

> ⏳ DNS propagation takes 5–60 minutes. You can verify with:
> ```bash
> dig +short ci.example.com
> ```

---

## 🔑 Step 2: SSH Into Your Server

Contabo emails you the root password after provisioning.

```bash
ssh root@YOUR_CONTABO_IP
```

Do basic hardening (optional but recommended):

```bash
# Update everything
apt update && apt upgrade -y

# Set hostname
hostnamectl set-hostname coolify

# Add a non-root user (Coolify can run as root, but this is cleaner)
adduser deploy
usermod -aG sudo deploy

# Copy SSH key so you don't type passwords
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

---

## 🎛️ Step 3: Install Coolify

Log in as your non-root user (or stay as root — Coolify's installer handles either):

```bash
# Switch to your user
su - deploy

# Run the official Coolify installer
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

This will:
- Install Docker if missing
- Pull Coolify containers
- Start Coolify on port **8000**

⏳ Takes ~3–5 minutes.

---

## 🌐 Step 4: Initial Coolify Setup

1. Open `http://YOUR_CONTABO_IP:8000` in your browser
2. Create your admin account
3. You'll land on the Coolify Dashboard

### Configure Coolify Domain & SSL

Go to **Settings → General**:
- **Instance Domain:** `https://coolify.yourdomain.com`
- **Instance Name:** whatever you want
- Save

Coolify will automatically:
- Set up Traefik reverse proxy
- Fetch a Let's Encrypt SSL certificate for `coolify.yourdomain.com`
- Redirect HTTP → HTTPS

Now access your dashboard at: **`https://coolify.yourdomain.com`**

---

## 🪵 Step 5: Create the Docker Compose Resource

In Coolify:

1. Click **Create New Resource** → **Docker Compose**
2. Give it a name: `ci-registry`
3. Select the server (your VPS)
4. Choose the project (or create a new one like `infra`)

### Paste the Compose File

Copy the contents of [`coolify/docker-compose.coolify.yml`](coolify/docker-compose.coolify.yml) into the Docker Compose text area.

### Set Environment Variables

In the **Environment Variables** section of the resource, add these:

| Variable | Value | Notes |
|----------|-------|-------|
| `WOODPECKER_HOST` | `https://ci.yourdomain.com` | The domain you'll assign to Woodpecker |
| `WOODPECKER_AGENT_SECRET` | `$(openssl rand -hex 32)` | Generate this on your laptop |
| `WOODPECKER_ADMIN_USERS` | `your-github-username` | Your GitHub login |
| `GITHUB_CLIENT` | *(from GitHub OAuth)* | See Step 7 |
| `GITHUB_SECRET` | *(from GitHub OAuth)* | See Step 7 |
| `REGISTRY_USER` | `registryuser` | Pick any username |
| `REGISTRY_PASSWORD` | `supersecurepassword123` | Pick a strong password |

> 💡 Generate the agent secret on your local machine:
> ```bash
> openssl rand -hex 32
> ```
> Paste the output as `WOODPECKER_AGENT_SECRET`.

### Assign Domains to Exposed Services

Coolify detects the `ports:` declarations in your compose and lets you attach domains. For each service:

1. **woodpecker-server** (port `8000`)
   - Click **Configure**
   - Add domain: `ci.yourdomain.com`
   - Coolify auto-generates Traefik labels + SSL

2. **registry** (port `5000`)
   - Click **Configure**
   - Add domain: `registry.yourdomain.com`

3. **registry-ui** (port `80`)
   - Click **Configure**
   - Add domain: `ui.registry.yourdomain.com`

> The `registry-auth-init` and `woodpecker-agent` services have no exposed ports — they stay internal.

### Deploy

Click **Deploy** (or **Save & Deploy**). Coolify will:
- Pull images
- Create volumes
- Start containers
- Set up SSL certificates via Traefik

⏳ First deploy takes ~3–5 minutes as images download.

---

## 🔐 Step 6: Verify Registry Auth Was Created

The `registry-auth-init` container should have run once and generated the `htpasswd` file. Check it:

In Coolify, go to your resource → **Containers** → click `registry-auth-init` → **Logs**.

You should see:
```
Registry htpasswd created
```

If you see it already exists from a previous deploy, that's fine too.

---

## 🔑 Step 7: Create GitHub OAuth App

Woodpecker needs OAuth to know who you are when you log in.

1. Go to: https://github.com/settings/developers
2. Click **OAuth Apps** → **New OAuth App**
3. Fill in:
   - **Application name:** `Woodpecker CI`
   - **Homepage URL:** `https://ci.yourdomain.com`
   - **Authorization callback URL:** `https://ci.yourdomain.com/authorize`
4. Click **Register application**
5. Click **Generate a new client secret**
6. Copy:
   - **Client ID** → paste into Coolify env var `GITHUB_CLIENT`
   - **Client Secret** → paste into Coolify env var `GITHUB_SECRET`

7. **Redeploy** the resource in Coolify so Woodpecker picks up the new env vars.

---

## ✅ Step 8: Test Everything

### Woodpecker CI
Visit: `https://ci.yourdomain.com`
- Click **Login with GitHub**
- You should see the Woodpecker dashboard
- Add a repository by clicking **Add repository**

### Registry
From any machine with Docker:
```bash
docker login registry.yourdomain.com
# Username: registryuser
# Password: (from your env var)
```

You should see `Login Succeeded`.

### Registry UI
Visit: `https://ui.registry.yourdomain.com`
- Browse your registry (empty until you push)

---

## 🔄 Step 9: Your First Pipeline

In any GitHub repo, create `.woodpecker.yml`:

```yaml
variables:
  - &registry "registry.yourdomain.com"
  - &image "${registry}/myapp"

steps:
  build-and-push:
    image: plugins/docker
    settings:
      registry: *registry
      repo: *image
      tags:
        - "${CI_COMMIT_SHA:0:8}"
        - latest
      username:
        from_secret: registry_username
      password:
        from_secret: registry_password
      dockerfile: Dockerfile
    when:
      - event: push
        branch: main
```

### Add Registry Secrets to Woodpecker

1. In Woodpecker UI, go to your repository
2. Click **Secrets** → **Add Secret**
3. Add:
   - `registry_username` = `registryuser`
   - `registry_password` = your registry password

Push to `main` → watch the build → image appears in Registry UI 🎉

---

## 🖥️ Step 10: Worker Machine Setup

Your second machine just needs to pull images from the registry.

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Login to your private registry
docker login registry.yourdomain.com

# Pull your built image
docker pull registry.yourdomain.com/myapp:latest
```

---

## 🎛️ Step 11: Deploy Apps via Coolify (Bonus)

Now that Coolify is running, you also have a full PaaS:

1. In Coolify dashboard → **Create New Resource**
2. Pick:
   - **Application** (Node.js, Go, Python, PHP, etc.)
   - **Database** (Postgres, MySQL, Redis, etc.)
   - **Service** (Ghost, Plausible, etc.)
3. Connect your GitHub repo
4. Coolify auto-builds, deploys, manages SSL

You now have:
- 🪵 Woodpecker for CI/CD
- 📦 Private Registry for images
- 🎛️ Coolify for app deployments
- All on one affordable box

---

## 🔧 Maintenance Commands

### In Coolify UI
- **Restart resource:** Click the 🔁 button on your `ci-registry` resource
- **View logs:** Click any container → **Logs**
- **Update env vars:** Edit → Save → Redeploy

### On the Server (SSH)
```bash
# View all Coolify-managed containers
docker ps

# View resource-specific logs
docker compose -f /data/coolify/applications/.../docker-compose.yml logs -f

# Free up disk space (Docker cache can grow fast on a CI box)
docker system prune -a --volumes

# Check disk usage
df -h
du -sh /var/lib/docker/
```

---

## 🐛 Troubleshooting

### "Bad Gateway" on ci.yourdomain.com
- Check Coolify resource status (is it running?)
- Check `woodpecker-server` logs in Coolify
- Verify `WOODPECKER_HOST` matches the domain exactly (with `https://`)

### GitHub OAuth redirect error
- Double-check the callback URL in GitHub OAuth settings
- Must match `https://ci.yourdomain.com/authorize` exactly

### Registry login fails
- Check `registry-auth-init` logs (did it create htpasswd?)
- Verify you're using `https://` — Coolify handles SSL
- Try: `curl -u user:pass https://registry.yourdomain.com/v2/_catalog`

### SSL certificate not issued
- Ensure DNS A records point to the VPS IP
- Coolify's Traefik needs port 80 open for ACME challenge
- Check Coolify → **Settings** → **SSL/TLS**

### Out of disk space
- Registry images + build caches eat space fast
- In Coolify, add a periodic job or manually run:
  ```bash
  docker system prune -a --volumes -f
  ```
- Consider the Cloud VPS 8 if you deploy many apps

---

## 📁 File Reference

| File | Purpose |
|------|---------|
| `coolify/docker-compose.coolify.yml` | The compose stack for Coolify deployment |
| `COOLIFY.md` | This guide |
| `registry/config.yml` | Registry configuration (mounted into registry container) |
| `example-pipeline/.woodpecker.yml` | Sample CI pipeline |
| `example-pipeline/Dockerfile` | Sample Dockerfile |

---

## 💰 Final Cost

| Item | Monthly |
|------|---------|
| Contabo Cloud VPS 6 | ~€10–13 |
| Domain (e.g., Namecheap) | ~€1–2 |
| **Total** | **~€12–15/mo** |

For that you get:
- Self-hosted CI/CD (unlimited builds, no minute limits)
- Private Docker Registry (unlimited storage on your disk)
- Full PaaS for deploying apps (Coolify)
- Multiple databases, services, etc.

Compare to GitHub Actions + Docker Hub: you'd pay way more for private repos, build minutes, and registry storage. This pays for itself quickly.

---

Ready to deploy? Start at **Step 0** — buy that Contabo box! 🚀
