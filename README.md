<div align="center">

# 🦄 Universal Python Deployment System

### Deploy any Python web app to Windows EC2 — in 5 minutes.

*Copy 6 files → Configure 3 settings → Push to GitHub → Live.*

[![Works With](https://img.shields.io/badge/Works%20With-Flask%20%7C%20Django%20%7C%20FastAPI-blue?style=for-the-badge)](.)
[![Platform](https://img.shields.io/badge/Platform-Windows%20EC2-orange?style=for-the-badge&logo=amazon-aws)](.)
[![Setup Time](https://img.shields.io/badge/Setup%20Time-~5%20minutes-brightgreen?style=for-the-badge)](.)

</div>

---

## ✅ Steps

- [ ] Copy 6 files into your project
- [ ] `unicorn_config.json` — set your workers and ports
- [ ] `nginx.conf` — match upstream ports to workers
- [ ] `instances.json` — add your EC2 instance ID and IP
- [ ] `app.py` — add `PORT = int(os.getenv("PORT", 5000))` and use it
- [ ] `requirements.txt` — list all dependencies
- [ ] GitHub Secrets — add `AK` and `SAK`
- [ ] `git push` and wait ~5 minutes
- [ ] Visit `http://YOUR_SERVER_IP` 🎉



---

## 📁 The 7 Files

```
your-project/
├── .github/workflows/
│   └── deploy.yml                 ← 🔒 Universal — never change
├── setup-production.ps1           ← 🔒 Universal — never change
├── unicorn_master.py              ← 🔒 Universal — never change
└── setup-production-REPO.ps1      ← 🔒 Universal — never change
├── unicorn_config.json            ← ⚙️  Configure: define your workers
├── nginx.conf                     ← ⚙️  Configure: match worker ports
└── instances.json                 ← ⚙️  Configure: add your EC2 servers
```

> 🔒 **Universal files** work with any project — copy and forget.
> ⚙️ **Config files** are the only 3 things you customize.

---

## 🎯 Quick Start

### Step 1 — Configure Your Workers (`unicorn_config.json`)

**Simple app (single Python file):**
```json
{
  "services": [
    {"name": "worker_0", "script": "app.py", "port": 5000, "enabled": true},
    {"name": "worker_1", "script": "app.py", "port": 5001, "enabled": true},
    {"name": "worker_2", "script": "app.py", "port": 5002, "enabled": true},
    {"name": "worker_3", "script": "app.py", "port": 5003, "enabled": true}
  ],
  "restart_delay": 5
}
```

**Microservices (multiple apps):**
```json
{
  "services": [
    {"name": "products_0", "script": "app/products/app.py", "port": 5010, "enabled": true},
    {"name": "products_1", "script": "app/products/app.py", "port": 5011, "enabled": true},
    {"name": "orders_0",   "script": "app/orders/app.py",   "port": 5020, "enabled": true},
    {"name": "orders_1",   "script": "app/orders/app.py",   "port": 5021, "enabled": true}
  ],
  "restart_delay": 5
}
```

| Field | Description |
|---|---|
| `name` | Worker identifier (used in logs) |
| `script` | Path to your Python file |
| `port` | Must be unique per worker |
| `enabled` | `true` / `false` to toggle |

---

### Step 2 — Configure Load Balancer (`nginx.conf`)

Match the `upstream` ports to your workers:

```nginx
upstream app_servers {
    server 127.0.0.1:5000;  # ← Match these ports
    server 127.0.0.1:5001;  #   to unicorn_config.json
    server 127.0.0.1:5002;
    server 127.0.0.1:5003;
}
```

---

### Step 3 — Add Your Servers (`instances.json`)

```json
{
  "instances": [
    {"name": "production", "instance_id": "i-0abc123def456", "server_ip": "13.xxx.xxx.xxx"},
    {"name": "staging",    "instance_id": "i-0def456ghi789", "server_ip": "13.xxx.xxx.xxx"}
  ]
}
```

> **Where to find these:** AWS Console → EC2 → Instances → click your instance → copy **Instance ID** and **Public IPv4**

---

### Step 4 — Update Your App (1 line)

```python
# Add at the top of app.py:
import os
PORT = int(os.getenv("PORT", 5000))

# Change at the bottom:
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT)  # ✅ was: port=5000
```

That's it. This lets Unicorn run multiple copies on different ports.

---

### Step 5 — Add GitHub Secrets

Go to your repo → **Settings → Secrets → Actions** and add:

| Secret | Value |
|---|---|
| `AK` | Your AWS Access Key ID |
| `SAK` | Your AWS Secret Access Key |

> **Where to get keys:** AWS Console → IAM → Users → Security credentials → Create access key

---

### Step 6 — Deploy 🚀

```bash
git add .
git commit -m "Add deployment system"
git push origin main
```

GitHub Actions will automatically:
1. Connect to your EC2 instances via AWS SSM
2. Install Python, Git, Nginx, NSSM
3. Clone your repo and install dependencies
4. Start all workers and configure load balancing
5. Open firewall port 80

**Your app is live in ~5 minutes at `http://YOUR_SERVER_IP`** 🎉

---

## 🏗️ Architecture

```
Internet
   │
   ▼ Port 80
 Nginx (Load Balancer)
   │
   ├──▶ Worker 0  :5000
   ├──▶ Worker 1  :5001
   ├──▶ Worker 2  :5002
   └──▶ Worker 3  :5003

Unicorn Master (always watching)
  └── Worker crashes? → Auto-restarts in 5s
  └── Logs → logs/worker_0.log, logs/worker_1.log ...
```

**Deployment flow:**
```
git push
   └── GitHub Actions triggered
         └── For each server in instances.json:
               ├── Connect via AWS SSM (no SSH)
               ├── Clone repository
               ├── Run setup-production.ps1
               │     ├── Install Python 3.13, Git, Nginx, NSSM
               │     ├── Copy project to C:\production
               │     └── Install requirements.txt
               └── Unicorn starts workers → Nginx load balances → App is live ✅
```
---

## ✨ What You Get

| Feature | Details |
|---|---|
| 🚀 **Auto-deploy** | Triggers on every `git push` |
| ⚖️ **Load balancing** | Round-robin across multiple workers |
| 🔄 **Auto-restart** | Crashed workers restart in seconds |
| 🟢 **Zero downtime** | Rolling deployments |
| 🔐 **No SSH needed** | Uses AWS SSM |
| 🪟 **Windows EC2** | Full Windows Server support |

---

## 📚 File Reference

<details>
<summary><b>🔒 setup-production.ps1</b> — runs on every deploy</summary>

- Installs Python 3.13, Git, Nginx, NSSM
- Copies project to `C:\production`
- Creates Python virtual environment
- Installs packages from `requirements.txt`
- Opens Windows Firewall port 80
- Creates Windows services for auto-start

**Change this?** ❌ Never — it's universal

</details>

<details>
<summary><b>🔒 unicorn_master.py</b> — always running as a Windows service</summary>

- Reads `unicorn_config.json` on startup
- Starts all enabled worker processes
- Sets `PORT` environment variable per worker
- Monitors workers every 10 seconds
- Auto-restarts crashed workers
- Logs each worker to `logs/worker_name.log`

**Change this?** ❌ Never — it's universal

</details>

<details>
<summary><b>🔒 deploy.yml</b> — triggered on git push</summary>

- Connects to every server in `instances.json` via AWS SSM
- Downloads your repository
- Runs `setup-production.ps1`
- Cleans up temporary files

**Change this?** ❌ Never — auto-detects your repo

</details>

<details>
<summary><b>⚙️ unicorn_config.json</b> — define workers & ports</summary>

**API + Background Worker example:**
```json
{
  "services": [
    {"name": "api_0",   "script": "api.py",    "port": 5000, "enabled": true},
    {"name": "api_1",   "script": "api.py",    "port": 5001, "enabled": true},
    {"name": "worker",  "script": "worker.py", "port": 5100, "enabled": true}
  ],
  "restart_delay": 10
}
```

**Change this?** ✅ Yes — this is your main configuration

</details>

<details>
<summary><b>⚙️ nginx.conf</b> — load balancer config</summary>

Only change the `upstream` block to match your worker ports:
```nginx
upstream app_servers {
    server 127.0.0.1:5000;
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
    server 127.0.0.1:5003;
}
```

**Change this?** ✅ Yes — keep ports in sync with `unicorn_config.json`

</details>

<details>
<summary><b>⚙️ instances.json</b> — your EC2 server list</summary>

```json
{
  "instances": [
    {"name": "production", "instance_id": "i-0abc123", "server_ip": "13.1.1.1"},
    {"name": "staging",    "instance_id": "i-0def456", "server_ip": "13.2.2.2"},
    {"name": "dev",        "instance_id": "i-0ghi789", "server_ip": "13.3.3.3"}
  ]
}
```

**Change this?** ✅ Yes — add all environments you want to deploy to

</details>

---

## 🐛 Troubleshooting

<details>
<summary><b>App not accessible</b></summary>

```powershell
# 1. Check Windows Firewall
Get-NetFirewallRule -DisplayName "Allow HTTP Port 80"

# 2. Check services are running
Get-Service UnicornMaster, NginxService

# 3. Verify AWS Security Group has port 80 open
```

</details>

<details>
<summary><b>Workers keep crashing</b></summary>

```powershell
# 1. Check worker logs
Get-Content C:\production\logs\worker_0.log

# 2. Verify your app reads PORT from environment
PORT = int(os.getenv("PORT", 5000))

# 3. Check all packages are in requirements.txt
```

</details>

<details>
<summary><b>502 Bad Gateway</b></summary>

- Workers aren't starting — check logs above
- Port mismatch — verify ports in `nginx.conf` match `unicorn_config.json`

</details>

---

## ❓ FAQ

**Do I need to change the universal files?**
No. `setup-production.ps1`, `unicorn_master.py`, and `deploy.yml` work with any project as-is.

**Works with Django / FastAPI?**
Yes — any Python web framework. Just point `unicorn_config.json` to your entry file and make sure it reads `PORT` from the environment.

**How do I scale up workers?**
Add more entries to `unicorn_config.json` with unique ports, then add matching lines to `nginx.conf` upstream.

**What if a worker crashes?**
Unicorn automatically restarts it after `restart_delay` seconds (default: 5).

**Do I need SSH?**
No. Everything goes through AWS SSM — no open SSH port needed.

**Can I deploy to staging + production?**
Yes — add both to `instances.json` and every `git push` deploys to all of them.

**My app uses a database — any special setup?**
Add an `init_database.py` file. The setup script runs it automatically on first deployment.

---


