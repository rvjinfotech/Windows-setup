# Universal Windows Deployment Kit for Python (Unicorn + Nginx + Celery)
Deploy Python web apps on Windows EC2 using GitHub Actions + AWS SSM, with:
- Nginx reverse proxy and load balancing
- Unicorn process supervision (web + worker modes)
- Optional Celery workers for background jobs

This repository is meant to be a reusable template/tutorial.

## What this system is (and is not)
- **Unicorn in this repo** is a custom Python process supervisor (`unicorn_master.py`), not the Ruby Unicorn server.
- It provides **process management**, not thread-pool management like Puma.
- Request concurrency comes from:
  - Nginx distributing traffic across multiple web worker processes
  - your Python app server behavior inside each process
- Background job concurrency comes from Celery worker settings (`CELERY_POOL`, `CELERY_CONCURRENCY`, queues, etc).

## How it works end-to-end
1. You push code to `main` (or run workflow manually).
2. `.github/workflows/deploy.yml` runs and sends an AWS SSM command to each server in `instances.json`.
3. SSM command clones repo on the server and runs `setup-production-REPO.ps1`.
4. Setup script installs dependencies, copies files to `C:\production`, and configures Windows services:
   - `UnicornMaster` (`MODE=web`)
   - `UnicornWorker` (`MODE=worker`)
   - `NginxService`
5. `unicorn_master.py` reads `unicorn_config.json`, launches and monitors enabled services for its mode.
6. Nginx receives public traffic on port 80 and forwards to your internal app worker ports.

## Files: universal vs project-specific
### Universal files (usually keep as-is)
- `.github/workflows/deploy.yml`
- `setup-production-REPO.ps1`
- `unicorn_master.py`

### Project-specific files (you must customize)
- `unicorn_config.json`
- `nginx.conf`
- `instances.json`
- `requirements.txt`
- your app entry scripts referenced by `unicorn_config.json`
- optional `celery_worker.py` and your Celery app module

### Optional templates
- `templates/nginx-TEMPLATE.conf`
- `templates/instances-TEMPLATE.json`

## Minimal integration checklist for any Python project
1. Copy universal files into your project.
2. Add/update `unicorn_config.json` with correct script paths and unique ports.
3. Add/update `nginx.conf` to match your routing model and worker ports.
4. Ensure your web app entrypoint reads `PORT` from environment.
5. Add all dependencies to `requirements.txt`.
6. Fill `instances.json` with your EC2 instance IDs and public IPs.
7. Add GitHub Secrets:
   - `AK` (AWS access key)
   - `SAK` (AWS secret access key)
8. Push to `main` and monitor Actions logs.

## File-by-file: what to change and when
### 1) `unicorn_config.json` (always change)
Defines what Unicorn starts.

Example (single app scale-out + one Celery worker):
```json
{
  "services": [
    {"name": "api_0", "script": "app.py", "port": 5000, "enabled": true},
    {"name": "api_1", "script": "app.py", "port": 5001, "enabled": true},
    {"name": "api_2", "script": "app.py", "port": 5002, "enabled": true},
    {"name": "worker_0", "script": "celery_worker.py", "port": 5100, "mode": "worker", "enabled": true}
  ],
  "restart_delay": 5
}
```

Rules:
- Web services: omit `mode` or set `mode: "web"`.
- Background workers: set `mode: "worker"`.
- Every `port` must be unique.
- Every `script` path must exist in repo.

### 2) `nginx.conf` (always review/change)
Must align with your app topology.

Common patterns:
- **Single app scaling**: one upstream with many ports, `location /` to that upstream.
- **Microservices**: separate upstreams and path-based routing (`/products`, `/orders`, `/users`).

Important:
- If Nginx points to wrong ports/scripts, you get `502 Bad Gateway`.
- If you keep default Nginx config, you’ll see default welcome page instead of your app.

### 3) `instances.json` (always change)
Set deploy targets:
```json
{
  "instances": [
    {"name": "production", "instance_id": "i-xxxxxxxx", "server_ip": "13.xxx.xxx.xxx"}
  ]
}
```

### 4) `requirements.txt` (always change)
Include all runtime dependencies your workers need.

At minimum for this tutorial setup:
```txt
flask==3.0.3
celery==5.4.0
```

### 5) App entry scripts (always change)
Each web script referenced in `unicorn_config.json` must:
- exist
- bind to env port

Pattern:
```python
import os
PORT = int(os.getenv("PORT", 5000))
```

### 6) `celery_worker.py` + Celery app module (if using background tasks)
`celery_worker.py` in this repo launches real Celery worker command via env.
It requires:
- `CELERY_APP` (required)
- broker/backend and optional tuning vars (recommended)

## Celery configuration in this setup
`setup-production-REPO.ps1` configures `UnicornWorker` with:
- `MODE=worker` (always)
- optional propagation of:
  - `CELERY_APP`
  - `CELERY_BROKER_URL`
  - `CELERY_RESULT_BACKEND`
  - `CELERY_LOGLEVEL`
  - `CELERY_POOL`
  - `CELERY_CONCURRENCY`
  - `CELERY_QUEUES`
  - `CELERY_EXTRA_ARGS`

If `CELERY_APP` is missing, worker service starts but Celery process exits with error until configured.

## Deploy steps
```bash
git add .
git commit -m "Configure windows deployment"
git push origin main
```

Workflow behavior:
- triggers on push to `main` (and manual dispatch)
- bootstraps Git on instance if missing
- runs setup script
- prints SSM stdout/stderr on failures

## Verify after deployment (SSM / PowerShell)
Check services:
```powershell
Get-Service UnicornMaster, UnicornWorker, NginxService
```

Check Unicorn mode values:
```powershell
& C:\nssm\nssm.exe get UnicornMaster AppEnvironmentExtra
& C:\nssm\nssm.exe get UnicornWorker AppEnvironmentExtra
```

Check worker processes:
```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'unicorn_master\.py|celery_worker\.py|celery(\.exe)?\s+worker' } |
  Select-Object ProcessId, CommandLine
```

Check logs:
```powershell
Get-Content C:\production\logs\products_0.log -Tail 80
Get-Content C:\production\logs\worker_0.log -Tail 80
```

## Troubleshooting quick map
### Nginx default page appears
- `nginx.conf` not copied/updated in `C:\nginx\conf\nginx.conf`
- restart Nginx service and validate config

### 502 Bad Gateway
- script path in `unicorn_config.json` does not exist
- app crashes on startup (check `C:\production\logs\*.log`)
- Nginx upstream ports do not match Unicorn web worker ports

### UnicornWorker running but no tasks executed
- `CELERY_APP` missing/incorrect
- broker URL/backend invalid
- wrong queue binding (`CELERY_QUEUES`)

### Deployment says success but app not updated
- confirm workflow target instance in `instances.json`
- inspect SSM output in Actions (stdout/stderr now printed on failure)

## When to edit universal files
### Edit rarely
- `setup-production-REPO.ps1`: only for installer/service behavior changes
- `unicorn_master.py`: only for supervisor logic changes

### Edit when your infrastructure differs
- `.github/workflows/deploy.yml`:
  - branch trigger rules
  - AWS region
  - custom clone/auth strategy
  - multi-account or environment-specific deploy logic

## Recommended usage model
For most teams:
1. keep universal files stable
2. change only config files and app code per project
3. scale by adding/removing entries in `unicorn_config.json`
4. keep `nginx.conf` synchronized with your selected topology

This gives a reusable Windows deployment pattern for almost any Python project with minimal per-project changes.
