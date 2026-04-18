# Windows Python Deployment (Manual Rails Unicorn/Puma Style)
This kit is designed to run Python apps on Windows EC2 in a Rails Unicorn/Puma-style operational model (manual, config-driven):
- Nginx in front
- multiple app workers behind it
- automatic worker restart
- optional Celery worker service for background jobs/concurrency

The goal is simple: copy the deployment kit files into your Python project, change a few config values, deploy.

## 1) Files to copy into every project
Do **not** copy tutorial app files. Use your own app code.

### Core deployment kit (copy in every project)
1. `.github/workflows/deploy.yml`
2. `setup-production-REPO.ps1`
3. `unicorn_master.py`
4. `unicorn_config.json`
5. `nginx.conf`
6. `instances.json`

### Add this only if you use Celery
7. `celery_worker.py`

### Optional reference files
- `templates/nginx-TEMPLATE.conf`
- `templates/instances-TEMPLATE.json`

## 2) Quick “what to edit” map
### Usually copy as-is (minor optional edits)
- `.github/workflows/deploy.yml`
- `setup-production-REPO.ps1`
- `unicorn_master.py`
- `celery_worker.py` (if using Celery)

### Always edit per project
- `unicorn_config.json`
- `nginx.conf`
- `instances.json`

## 3) How the flow works
1. Workflow sends SSM command to Windows EC2.
2. `setup-production-REPO.ps1` installs runtime + services.
3. Two Windows services run Unicorn in separate modes:
   - `UnicornMaster` → `MODE=web`
   - `UnicornWorker` → `MODE=worker`
4. `unicorn_master.py` reads `unicorn_config.json`, starts matching services for that mode.
5. Nginx routes incoming HTTP traffic to configured web worker ports.
6. Celery worker runs separately (if configured).

## 4) Per-file instructions (exactly what to change)
### 4.1 `unicorn_config.json` (main scaling file)
This file controls:
- number of workers
- script path per worker
- port per worker
- mode (`web` or `worker`)

### Fields you edit
- `services[].name`: any readable name (`api_0`, `products_1`, etc.)
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

### Example B: microservices routing model
```json
{
  "services": [
    {"name": "products_0", "script": "app/products/app.py", "port": 5010, "enabled": true},
    {"name": "products_1", "script": "app/products/app.py", "port": 5011, "enabled": true},
    {"name": "orders_0", "script": "app/orders/app.py", "port": 5020, "enabled": true},
    {"name": "orders_1", "script": "app/orders/app.py", "port": 5021, "enabled": true},
    {"name": "users_0", "script": "app/users/app.py", "port": 5030, "enabled": true},
    {"name": "users_1", "script": "app/users/app.py", "port": 5031, "enabled": true},
    {"name": "worker_0", "script": "celery_worker.py", "port": 5100, "mode": "worker", "enabled": true}
  ],
  "restart_delay": 5
}
```

### Required rule
Every `script` path in `unicorn_config.json` must exist in your project.

### 4.2 `nginx.conf` (routing + load balancing)
Nginx must match the web ports in `unicorn_config.json`.

### Option A: single app, all traffic to one pool
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

### Option B: microservices path routing
```nginx
upstream products_servers {
    server 127.0.0.1:5010;
    server 127.0.0.1:5011;
}
upstream orders_servers {
    server 127.0.0.1:5020;
    server 127.0.0.1:5021;
}
upstream users_servers {
    server 127.0.0.1:5030;
    server 127.0.0.1:5031;
}

server {
    listen 80;
    server_name _;

    location /products/ { proxy_pass http://products_servers/; }
    location /orders/   { proxy_pass http://orders_servers/; }
    location /users/    { proxy_pass http://users_servers/; }
}
```

### Required rule
Nginx upstream ports must match **enabled web workers** exactly.

### 4.3 `instances.json` (deploy targets)
Set the EC2 instances to deploy to.

```json
{
  "instances": [
    {"name": "production", "instance_id": "i-xxxxxxxxxxxxxxxxx", "server_ip": "13.xxx.xxx.xxx"}
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

### 4.6 `celery_worker.py` (if using Celery)
This launcher starts:
- `python -m celery -A <CELERY_APP> worker ...`

### Environment variables used
- Required:
  - `CELERY_APP`
- Optional:
  - `CELERY_BROKER_URL`
  - `CELERY_RESULT_BACKEND`
  - `CELERY_LOGLEVEL`
  - `CELERY_POOL` (Windows usually `solo`)
  - `CELERY_CONCURRENCY`
  - `CELERY_QUEUES`
  - `CELERY_EXTRA_ARGS`

`setup-production-REPO.ps1` automatically applies these env vars to `UnicornWorker` service if they exist in server environment.

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
  Where-Object { $_.CommandLine -match 'unicorn_master\.py|celery_worker\.py|celery(\.exe)?\s+worker' } |
  Select-Object ProcessId, CommandLine
```

### Check logs
```powershell
Get-Content C:\production\logs\products_0.log -Tail 80
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

### Requests hitting wrong service
- your `location` blocks in `nginx.conf` are too broad
- path routing not separated by service upstreams

### Celery service running but no jobs execute
- `CELERY_APP` incorrect/missing
- broker/backend not reachable
- queue names mismatch

## 8) Practical usage pattern
For each new Python project:
1. Copy the kit files listed in section 1.
2. Edit only the three core configs first:
   - `unicorn_config.json`
   - `nginx.conf`
   - `instances.json`
3. Add Celery only if needed (`celery_worker.py` + env vars).
4. Keep core universal scripts stable unless you have infra-level reasons to change them.

This keeps deployment setup repeatable across projects while still giving flexible worker/routing control.
