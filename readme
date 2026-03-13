# 🚀 Universal Python Deployment System

**Deploy any Python web application to Windows servers with zero hassle.**

Copy these files to your project, configure 3 settings, push to GitHub → Automatically deploys to all servers!

---

## 📦 What You Get

A complete deployment system that works with:
- ✅ Flask
- ✅ Django  
- ✅ FastAPI
- ✅ Any Python web framework

**Features:**
- ✅ Auto-deployment on `git push`
- ✅ Load balancing across multiple workers
- ✅ Auto-restart crashed workers
- ✅ Zero downtime deployments
- ✅ No SSH needed (uses AWS SSM)
- ✅ Works on Windows Server EC2

---

## 🎯 Quick Start (5 Minutes)

### Step 1: Copy Files to Your Project

Copy these 6 files from this repo to your project:

```
your-project/
├── .github/workflows/
│   └── deploy.yml                 ← Copy this
├── setup-production.ps1           ← Copy this
├── unicorn_master.py              ← Copy this
├── unicorn_config.json            ← Copy this (then configure)
├── nginx.conf                     ← Copy this (then configure)
└── instances.json                 ← Copy this (then configure)
```

### Step 2: Configure 3 Files

#### **A. unicorn_config.json** - Define Your Workers

**For simple app (one Python file):**
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

**For microservices (multiple apps):**
```json
{
  "services": [
    {"name": "products_0", "script": "app/products/app.py", "port": 5010, "enabled": true},
    {"name": "products_1", "script": "app/products/app.py", "port": 5011, "enabled": true},
    {"name": "orders_0", "script": "app/orders/app.py", "port": 5020, "enabled": true},
    {"name": "orders_1", "script": "app/orders/app.py", "port": 5021, "enabled": true}
  ],
  "restart_delay": 5
}
```

**What to configure:**
- `name`: Worker identifier (used in logs)
- `script`: Path to your Python file
- `port`: Port number (must be unique per worker)
- `enabled`: true/false to enable/disable worker

---

#### **B. nginx.conf** - Match Ports to Workers

Update the `upstream app_servers` section to match your worker ports:

**Example for 4 workers:**
```nginx
upstream app_servers {
    server 127.0.0.1:5000;  # ← Match these to ports
    server 127.0.0.1:5001;  #    in unicorn_config.json
    server 127.0.0.1:5002;
    server 127.0.0.1:5003;
}
```

**Example for microservices:**
```nginx
upstream app_servers {
    server 127.0.0.1:5010;  # products workers
    server 127.0.0.1:5011;
    server 127.0.0.1:5020;  # orders workers
    server 127.0.0.1:5021;
}
```

---

#### **C. instances.json** - Add Your Servers

```json
{
  "instances": [
    {
      "name": "production",
      "instance_id": "i-0xxxxxxxxxxxxx",
      "server_ip": "13.xxx.xxx.xxx"
    }
  ]
}
```

**How to find these values:**
1. Go to AWS Console → EC2 → Instances
2. Click your instance
3. Copy:
   - **Instance ID** (looks like: i-0abc123def456)
   - **Public IPv4 address** (looks like: 13.234.78.215)

**For multiple servers:**
```json
{
  "instances": [
    {"name": "production", "instance_id": "i-0abc123", "server_ip": "13.1.1.1"},
    {"name": "staging", "instance_id": "i-0def456", "server_ip": "13.2.2.2"},
    {"name": "dev", "instance_id": "i-0ghi789", "server_ip": "13.3.3.3"}
  ]
}
```

---

### Step 3: Modify Your App (1 Line Change)

**In your main Python file (app.py, main.py, etc.):**

**Add at the top:**
```python
import os
PORT = int(os.getenv("PORT", 5000))  # Read port from environment
```

**Change at the bottom:**
```python
# BEFORE:
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)  # ❌ Hardcoded

# AFTER:
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT)  # ✅ Uses environment
```

**That's it!** This one change lets Unicorn run multiple copies on different ports.

---

### Step 4: Setup GitHub Secrets

1. Go to your GitHub repo → Settings → Secrets → Actions
2. Add these 2 secrets:
   - `AK` = Your AWS Access Key ID
   - `SAK` = Your AWS Secret Access Key

**How to get AWS keys:**
- AWS Console → IAM → Users → Your user → Security credentials → Create access key

---

### Step 5: Deploy!

```bash
git add .
git commit -m "Add deployment system"
git push origin main
```

**GitHub Actions will automatically:**
1. Connect to your EC2 instances
2. Install Python, Git, Nginx, NSSM
3. Clone your repository
4. Install dependencies
5. Start workers
6. Configure load balancer
7. Open firewall

**Your app will be live in ~5 minutes!** 🎉

---

## 📚 What Each File Does

### **Universal Files (Never Change These)**

#### **1. setup-production.ps1**
**What it does:**
- Installs Python 3.13
- Installs Git
- Copies your project to `C:\production`
- Creates Python virtual environment
- Installs packages from `requirements.txt`
- Sets up NSSM (Windows service manager)
- Installs Nginx web server
- Opens Windows Firewall port 80
- Creates Windows services for auto-start

**When it runs:** Every deployment (GitHub Actions calls it)

**Change this?** ❌ Never - it's universal

---

#### **2. unicorn_master.py**
**What it does:**
- Reads `unicorn_config.json`
- Starts multiple worker processes
- Sets `PORT` environment variable for each worker
- Monitors workers every 10 seconds
- Auto-restarts crashed workers
- Logs each worker to `logs/worker_name.log`

**When it runs:** Always running as Windows service

**Change this?** ❌ Never - it's universal

---

#### **3. .github/workflows/deploy.yml**
**What it does:**
- Triggered when you `git push`
- Connects to servers via AWS SSM (no SSH)
- For each server in `instances.json`:
  - Downloads your repository
  - Runs `setup-production.ps1`
  - Cleans up temporary files

**When it runs:** On every push to main branch

**Change this?** ❌ Never - auto-detects your repo

---

### **Configuration Files (Customize Per Project)**

#### **4. unicorn_config.json**
**What it does:**
- Tells Unicorn which workers to start
- Defines ports for each worker
- Sets restart delay

**When it runs:** Read by `unicorn_master.py` on startup

**Change this?** ✅ Yes - define your workers and ports

**Example configurations:**

**Simple blog (4 workers):**
```json
{
  "services": [
    {"name": "web_0", "script": "app.py", "port": 5000, "enabled": true},
    {"name": "web_1", "script": "app.py", "port": 5001, "enabled": true},
    {"name": "web_2", "script": "app.py", "port": 5002, "enabled": true},
    {"name": "web_3", "script": "app.py", "port": 5003, "enabled": true}
  ],
  "restart_delay": 5
}
```

**API + Background Worker:**
```json
{
  "services": [
    {"name": "api_0", "script": "api.py", "port": 5000, "enabled": true},
    {"name": "api_1", "script": "api.py", "port": 5001, "enabled": true},
    {"name": "worker", "script": "worker.py", "port": 5100, "enabled": true}
  ],
  "restart_delay": 10
}
```

---

#### **5. nginx.conf**
**What it does:**
- Load balances requests across workers
- Listens on port 80 (public internet)
- Distributes traffic round-robin
- Handles SSL/HTTPS (if configured)

**When it runs:** Always running as Windows service

**Change this?** ✅ Yes - update `upstream` ports to match workers

**What to change:**
```nginx
# ONLY CHANGE THIS SECTION:
upstream app_servers {
    server 127.0.0.1:5000;  # ← Match these to your
    server 127.0.0.1:5001;  #    worker ports from
    server 127.0.0.1:5002;  #    unicorn_config.json
    server 127.0.0.1:5003;
}
```

---

#### **6. instances.json**
**What it does:**
- Lists all servers to deploy to
- Provides instance IDs for AWS SSM connection
- Shows public IPs for access

**When it runs:** Read by GitHub Actions workflow

**Change this?** ✅ Yes - add your EC2 instance details

**Fields explained:**
```json
{
  "name": "production",              // Friendly name (for logs)
  "instance_id": "i-0xxxxxxxxxxxxx", // AWS EC2 Instance ID
  "server_ip": "13.xxx.xxx.xxx"      // Public IP address
}
```

---

## 🔧 Your App Files

### **7. requirements.txt** (Your Dependencies)
List your Python packages:
```txt
Flask==3.0.0
SQLAlchemy==2.0.0
requests==2.31.0
```

### **8. init_database.py** (Optional - Database Setup)
Initializes your database on first deployment:
```python
from app import app, db

with app.app_context():
    db.create_all()
    print("Database created!")
```

---

## 🎓 How It Works

```
Developer pushes code
        ↓
GitHub Actions triggered
        ↓
For each server in instances.json:
  1. Connect via AWS SSM
  2. Clone repository
  3. Run setup-production.ps1
     - Install Python, Git, Nginx, NSSM
     - Copy project files
     - Install dependencies
     - Create services
  4. Unicorn starts workers
  5. Nginx load balances
        ↓
App is live!
```

---

## 📊 Architecture

```
Internet → Port 80 → Nginx → Round-robin → Worker 0 (Port 5000)
                                         → Worker 1 (Port 5001)
                                         → Worker 2 (Port 5002)
                                         → Worker 3 (Port 5003)

Unicorn Master monitors all workers
  - Worker crashes? → Restart in 5 seconds
  - Logs to: logs/worker_0.log, logs/worker_1.log, etc.
```

---

## ❓ FAQ

**Q: Do I need to change anything in the universal files?**  
A: No! `setup-production.ps1`, `unicorn_master.py`, and `deploy.yml` work with any project.

**Q: What if I have a Django app?**  
A: Same process! Just update `unicorn_config.json` to point to your Django app and ensure it reads `PORT` from environment.

**Q: Can I use this with FastAPI?**  
A: Yes! Works with any Python web framework.

**Q: What if my app uses a database?**  
A: Add `init_database.py` to initialize it. Setup script runs it automatically on first deployment.

**Q: How do I add more servers?**  
A: Add them to `instances.json` - workflow will deploy to all of them.

**Q: How do I increase workers?**  
A: Add more entries to `unicorn_config.json` with unique ports, then update `nginx.conf` upstream.

**Q: What if a worker crashes?**  
A: Unicorn automatically restarts it after 5 seconds (configurable via `restart_delay`).

**Q: Do I need SSH access?**  
A: No! Uses AWS SSM for serverless access.

**Q: Can I deploy to multiple environments?**  
A: Yes! Add staging/dev servers to `instances.json`.

---

## 🐛 Troubleshooting

**App not accessible:**
1. Check Windows Firewall: `Get-NetFirewallRule -DisplayName "Allow HTTP Port 80"`
2. Check AWS Security Group: Port 80 must be open
3. Check services: `Get-Service UnicornMaster, NginxService`

**Workers keep crashing:**
1. Check logs: `Get-Content C:\production\logs\worker_0.log`
2. Verify app reads PORT: `PORT = int(os.getenv("PORT", 5000))`
3. Check dependencies: All packages in `requirements.txt`?

**502 Bad Gateway:**
1. Workers not starting - check logs
2. Nginx can't connect - verify ports in `nginx.conf` match `unicorn_config.json`

---

## ✅ Checklist for New Project

- [ ] Copy 6 files to your project
- [ ] Configure `unicorn_config.json` (workers & ports)
- [ ] Configure `nginx.conf` (upstream ports)
- [ ] Configure `instances.json` (server IDs & IPs)
- [ ] Modify `app.py` to read PORT from environment
- [ ] Create `requirements.txt` with dependencies
- [ ] Set GitHub Secrets (AK, SAK)
- [ ] Push to GitHub
- [ ] Wait 5 minutes
- [ ] Access your app at http://YOUR_SERVER_IP

---

## 📝 Summary

**Universal Files (3):**
- setup-production.ps1 ✅
- unicorn_master.py ✅
- deploy.yml ✅

**Configuration Files (3):**
- unicorn_config.json ⚙️
- nginx.conf ⚙️
- instances.json ⚙️

**Your Files (2+):**
- app.py (add 1 line) 🔧
- requirements.txt 📝
- init_database.py (optional) 🗄️

**Total setup time: ~5 minutes per project**

---

## 🚀 Ready to Deploy?

1. Copy these files to your project
2. Configure the 3 settings files
3. Add PORT reading to your app
4. Push to GitHub
5. Your app is live!

**Questions? Issues? Open an issue in this repo!**
