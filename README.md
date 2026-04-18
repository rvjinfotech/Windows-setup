# Windows Python Deployment (Universal Web Workers + Celery)
This kit is designed to run Python apps on Windows EC2 in a universal config-driven model:
- Nginx in front
- multiple web workers behind it
- automatic worker restart
- optional Celery worker service for background jobs/concurrency

The goal is simple: copy the deployment kit files into your Python project, change a few config values, deploy.
Setup Instance: 
### SSM access — attach IAM role to your EC2
 
For `deploy.yml` to send SSM commands to your instance, the EC2 must have an IAM role with SSM permissions.
 
**Step 1 — Create IAM Role (one-time)**
1. Go to **IAM → Roles → Create role**
2. Trusted entity: `AWS service` → `EC2`
3. Attach policy: `AmazonSSMManagedInstanceCore`
4. Name it e.g. `EC2SSMRole` → Create
**Step 2 — Attach role to your EC2**
1. Go to **EC2 → Instances** → create new instance → choose all the configurations
2. **Advance options → IAM instance profile → Select the role we created**
3. Select `EC2SSMRole` → create instance

**If already created Instance**

1. Go to **EC2 → Instances** → select your instance
2. **Actions → Security → Modify IAM role**
3. Select `EC2SSMRole` → Update
**Step 3 — Verify SSM can see the instance**
```bash
aws ssm describe-instance-information --region YOUR_REGION
# your instance should appear with PingStatus: Online
```
 
**Step 4 — GitHub Actions also needs AWS access**
Add these secrets to your repo (**Settings → Secrets → Actions**):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
The IAM user for those keys and to deploy needs this policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:ListCommandInvocations",
        "ssm:DescribeInstanceInformation"
      ],
      "Resource": "*"
    }
  ]
}
```
**These are the basic permission, if the project uses any other services, the permissions will update accordingly**
 
> ℹ️ SSM Agent must be running on the EC2. It comes pre-installed on Windows Server 2016+ AMIs. Verify with: `Get-Service AmazonSSMAgent` in PowerShell.
 
## 0) How the full project works (workflow)

```
GitHub push
    │
    ▼
deploy.yml (GitHub Actions)
    │  sends SSM command to EC2
    ▼
setup-production-REPO.ps1 (runs on Windows EC2)
    │  installs Python, Nginx, NSSM services
    │  reads unicorn_config.json → registers UnicornMaster + UnicornWorker services
    │  reads celery_config.json  → attaches Celery env vars to UnicornWorker (if used)
    ▼
UnicornMaster (Windows service, MODE=web)
    │  unicorn_master.py → spawns web worker processes on ports 5000, 5001, 5002...
    │  each process runs YOUR app.py, auto-restarts on crash
    ▼
Nginx (Windows service)
    │  nginx.conf → load-balances HTTP traffic across web worker ports
    ▼
UnicornWorker (Windows service, MODE=worker)       [only if Celery is enabled]
    │  unicorn_master.py → spawns celery_worker.py
    │  celery_worker.py reads celery_config.json → starts Celery worker
    ▼
Redis / RabbitMQ broker                            [only if Celery is enabled]
    │  queues background tasks from your app
    ▼
Celery executes tasks from your task modules
```

**Key rule:** Nginx ports ↔ `unicorn_config.json` web worker ports must always match.

## 0.1) File roles at a glance

| File | Type | Change? |
|---|---|---|
| `unicorn_master.py` | Universal | ❌ Never |
| `celery_worker.py` | Universal | ❌ Never |
| `celery_app.py` | Universal | ❌ Never |
| `setup-production-REPO.ps1` | Universal | 🔧 Only for infra changes (Python/Nginx version, install path) |
| `.github/workflows/deploy.yml` | Universal | 🔧 Only `AWS_REGION` and trigger branch |
| `unicorn_config.json` | Config | ✅ Every project — set your script path + ports |
| `nginx.conf` | Config | ✅ Every project — match ports to workers |
| `instances.json` | Config | ✅ Every project — set your EC2 instance ID + IP |
| `celery_config.json` | Config | ✅ If using Celery — set broker URL + app path |
| `app/your_app.py` | **Your code** | ✅ This is your Python entry script |
| `your_tasks.py` | **Your code** | ✅ Your Celery task definitions (if using Celery) |

## 0.2) What's included as an example
The repo ships with a minimal working example in `app/orders/app.py` (a Flask app with `/` and `/health` routes).
**This is a reference only — replace it with your own app code.**
The `unicorn_config.json` and `nginx.conf` already point to it so you can see the full setup end-to-end before swapping in your own project.

## 1) Files to copy into every project
Do **not** copy the example app (`app/` folder). Use your own app code.

### Core deployment kit (copy in every project)
1. `.github/workflows/deploy.yml`
2. `setup-production-REPO.ps1`
3. `unicorn_master.py`
4. `unicorn_config.json`
5. `nginx.conf`
6. `instances.json`

### Add this only if you use Celery
7. `celery_worker.py`
8. `celery_app.py`
9. `celery_config.json`

### Optional reference files
- `templates/nginx-TEMPLATE.conf`
- `templates/instances-TEMPLATE.json`

## 2) Quick “what to edit” map
### Usually copy as-is (minor optional edits)
- `.github/workflows/deploy.yml`
- `setup-production-REPO.ps1`
- `unicorn_master.py`
- `celery_worker.py` (if using Celery)
- `celery_app.py` (if using Celery)

### Always edit per project
- `unicorn_config.json`
- `nginx.conf`
- `instances.json`
- `celery_config.json` (if using Celery)

## 3) How the flow works
1. Workflow sends SSM command to Windows EC2.
2. `setup-production-REPO.ps1` installs runtime + services.
3. Two Windows services run Unicorn in separate modes:
   - `UnicornMaster` → `MODE=web`
   - `UnicornWorker` → `MODE=worker`
4. `unicorn_master.py` reads `unicorn_config.json`, starts matching services for that mode.
5. Nginx routes incoming HTTP traffic to configured web worker ports.
6. Celery worker runs separately (if configured).
7. Default routing pattern is one shared upstream pool (no app-path routing required).

## 4) Per-file instructions (exactly what to change)
### 4.1 `unicorn_config.json` (main scaling file)
This file controls:
- number of workers
- script path per worker
- port per worker
- mode (`web` or `worker`)

> ℹ️ The repo ships with `"script": "app/orders/app.py"` pointing to the example app. **Change this to your own entry script path before deploying.**

### Fields you edit
- `services[].name`: any readable name (`api_0`, `api_1`, etc.)
- `services[].script`: path to your real Python entry script
- `services[].port`: unique internal port
- `services[].mode`:
  - omit or `web` for HTTP workers
  - `worker` for Celery/background workers
- `services[].enabled`: true/false
- `restart_delay`: restart wait seconds

### Example A: single API app with 3 web workers + 1 Celery worker
```json
{
  "services": [
    {"name": "api_0", "script": "main.py", "port": 5000, "enabled": true},
    {"name": "api_1", "script": "main.py", "port": 5001, "enabled": true},
    {"name": "api_2", "script": "main.py", "port": 5002, "enabled": true},
    {"name": "worker_0", "script": "celery_worker.py", "port": 5100, "mode": "worker", "enabled": true}
  ],
  "restart_delay": 5
}
```

### Required rule
Every `script` path in `unicorn_config.json` must exist in your project.

### 4.2 `nginx.conf` (routing + load balancing)
Nginx must match the web ports in `unicorn_config.json`.
Default universal routing pattern:
```nginx
upstream app_servers {
    server 127.0.0.1:5000;
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://app_servers;
    }
}
```

### Required rule
Nginx upstream ports must match **enabled web workers** exactly.

### 4.3 `instances.json` (deploy targets)
Set the EC2 instances to deploy to.

> ⚠️ The repo currently contains a real instance ID and IP (`i-04ef5305404485929` / `13.201.79.36`). **Replace both with your own before committing.**

```json
{
  "instances": [
    {"name": "production", "instance_id": "i-xxxxxxxxxxxxxxxxx", "server_ip": "YOUR.EC2.IP.HERE"}
  ]
}
```

### 4.4 `.github/workflows/deploy.yml` (usually keep, optional edits)
Usually you only edit:
- `env.AWS_REGION`
- trigger branches under `on.push.branches`

Everything else can stay as provided.

### 4.5 `setup-production-REPO.ps1` (usually keep, edit only if needed)
Most projects keep this file as-is. Edit only when needed:
- change install directory: `$INSTALL_PATH`
- change Python version URL/path
- change Nginx version
- add extra install steps specific to your org

### 4.6 Celery universal setup (Redis / Sidekiq-style)
If you want background jobs, keep these three files:
- `celery_worker.py` (starts the worker process)
- `celery_app.py` (default universal Celery app)
- `celery_config.json` (the only file you usually edit)

### Edit only `celery_config.json`
```json
{
  "celery_app": "celery_app:celery",
  "broker_url": "redis://127.0.0.1:6379/0",
  "result_backend": "redis://127.0.0.1:6379/1",
  "loglevel": "info",
  "pool": "solo",
  "concurrency": "",
  "queues": "",
  "extra_args": "",
  "imports": []
}
```

### Required values
- `celery_app`: Celery app path (default is `celery_app:celery`, already included in this kit)
- `broker_url`: your queue broker URL (Redis/RabbitMQ)
- `result_backend`: where task results are stored

### Optional values
- `loglevel`, `pool`, `concurrency`, `queues`, `extra_args`, `imports`

### How it works
1. `setup-production-REPO.ps1` reads `celery_config.json` and attaches those values to `UnicornWorker`.
2. `celery_worker.py` also reads `celery_config.json` as fallback.
3. Worker starts with: `python -m celery -A <CELERY_APP> worker ...`

No manual machine-level Celery env setup is required for normal usage.

### If you later create your own Celery app module
Only update `celery_config.json`:
- set `celery_app` to your module path (example: `myproject.celery_app:celery`)
- set `imports` with your task modules (example: `["myproject.tasks"]`)

### Project-specific Celery changes checklist
- set `broker_url`
- set `result_backend`
- optionally set `imports`, `queues`, and `concurrency`
- only change `celery_app` if you use a custom Celery app module

## 5) What not to change often
- `unicorn_master.py`: core supervisor logic
- most of `setup-production-REPO.ps1`: installer/service boilerplate
- most of workflow internals in `deploy.yml`

Scale and route by changing `unicorn_config.json` and `nginx.conf`, not by rewriting the core scripts.

## 6) Validation commands (SSM PowerShell)
### Check services
```powershell
Get-Service UnicornMaster, UnicornWorker, NginxService
```

### Check mode/env on services
```powershell
& C:\nssm\nssm.exe get UnicornMaster AppEnvironmentExtra
& C:\nssm\nssm.exe get UnicornWorker AppEnvironmentExtra
```

### Check running worker processes
```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'unicorn_master\.py|celery_worker\.py|-m\s+celery.*\sworker' } |
  Select-Object ProcessId, CommandLine
```

### Check logs
```powershell
Get-Content C:\production\logs\api_0.log -Tail 80
Get-Content C:\production\logs\worker_0.log -Tail 80
```

## 7) Troubleshooting (by symptom)
### 502 Bad Gateway
- script path in `unicorn_config.json` is wrong/missing
- app crashes at startup (check `C:\production\logs\*.log`)
- Nginx ports and Unicorn ports mismatch

### Nginx default welcome page
- your project `nginx.conf` was not copied to `C:\nginx\conf\nginx.conf`
- Nginx service not restarted after config update

### Requests not balancing across workers
- `nginx.conf` upstream ports do not match enabled web workers
- one or more web workers are crashing (check logs)

### Celery service running but no jobs execute
- `celery_config.json` has wrong `celery_app` / broker / backend
- broker/backend not reachable
- `imports` or queue names mismatch with your task code

## 8) Practical usage pattern
For each new Python project:
1. Copy the kit files listed in section 1.
2. Add your own app code (do **not** copy `app/orders/app.py` — that's the example).
3. Edit the three core configs:
   - `unicorn_config.json` — point `script` to your entry file
   - `nginx.conf` — match upstream ports to your workers
   - `instances.json` — set your EC2 `instance_id` and `server_ip`
4. Add Celery only if needed (`celery_worker.py` + `celery_app.py` + `celery_config.json`).
5. Keep core universal scripts stable unless you have infra-level reasons to change them.

This keeps deployment setup repeatable across projects while still giving flexible worker/routing control.