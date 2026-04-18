#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Universal Windows Production Server Setup Script
.DESCRIPTION
    Installs and configures Python, Git, Nginx, NSSM, and services.
    Designed to run from within the cloned repository.
#>

$ErrorActionPreference = "Stop"
$INSTALL_PATH = "C:\production"
$REPO_PATH = Get-Location

function Get-FirstAvailableEnvValue {
    param([string]$Name)

    $processValue = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (![string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }

    $machineValue = [Environment]::GetEnvironmentVariable($Name, "Machine")
    if (![string]::IsNullOrWhiteSpace($machineValue)) {
        return $machineValue
    }

    $userValue = [Environment]::GetEnvironmentVariable($Name, "User")
    if (![string]::IsNullOrWhiteSpace($userValue)) {
        return $userValue
    }

    return $null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Universal Production Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Repository: $REPO_PATH"
Write-Host "Install Path: $INSTALL_PATH"
Write-Host ""

# ============================================================================
# STEP 1: Install Python
# ============================================================================
Write-Host "[1/9] Installing Python 3.13..." -ForegroundColor Yellow
if (!(Test-Path "C:\Python313\python.exe")) {
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.13.0/python-3.13.0-amd64.exe" -OutFile "C:\python.exe" -UseBasicParsing
    Start-Process "C:\python.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=C:\Python313" -Wait
    Remove-Item "C:\python.exe" -Force
    Write-Host "  [OK] Python installed" -ForegroundColor Green
} else {
    Write-Host "  [OK] Python already installed" -ForegroundColor Green
}

# ============================================================================
# STEP 2: Install Git
# ============================================================================
Write-Host "[2/9] Installing Git..." -ForegroundColor Yellow
if (!(Test-Path "C:\Program Files\Git\bin\git.exe")) {
    Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe" -OutFile "C:\git.exe" -UseBasicParsing
    Start-Process "C:\git.exe" -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait
    Remove-Item "C:\git.exe" -Force
    Write-Host "  [OK] Git installed" -ForegroundColor Green
} else {
    Write-Host "  [OK] Git already installed" -ForegroundColor Green
}

# ============================================================================
# STEP 3: Copy Project to Production Directory
# ============================================================================
Write-Host "[3/9] Setting up production directory..." -ForegroundColor Yellow
if (!(Test-Path $INSTALL_PATH)) {
    New-Item -ItemType Directory -Path $INSTALL_PATH -Force | Out-Null
}

# Copy all files from current repo to production
Copy-Item -Path "$REPO_PATH\*" -Destination $INSTALL_PATH -Recurse -Force
Write-Host "  [OK] Project files copied to $INSTALL_PATH" -ForegroundColor Green

# ============================================================================
# STEP 4: Setup Python Virtual Environment
# ============================================================================
Write-Host "[4/9] Setting up Python environment..." -ForegroundColor Yellow
if (!(Test-Path "$INSTALL_PATH\venv")) {
    & C:\Python313\python.exe -m venv "$INSTALL_PATH\venv"
}

& "$INSTALL_PATH\venv\Scripts\pip.exe" install --upgrade pip -q
& "$INSTALL_PATH\venv\Scripts\pip.exe" install -r "$INSTALL_PATH\requirements.txt" -q
& "$INSTALL_PATH\venv\Scripts\pip.exe" install --upgrade sqlalchemy flask-sqlalchemy -q
Write-Host "  [OK] Dependencies installed" -ForegroundColor Green

# Initialize database if init script exists
if (Test-Path "$INSTALL_PATH\init_database.py") {
    if (!(Test-Path "$INSTALL_PATH\database\ecommerce.db")) {
        & "$INSTALL_PATH\venv\Scripts\python.exe" "$INSTALL_PATH\init_database.py"
        Write-Host "  [OK] Database initialized" -ForegroundColor Green
    }
}

# ============================================================================
# STEP 5: Install NSSM
# ============================================================================
Write-Host "[5/9] Installing NSSM..." -ForegroundColor Yellow
if (!(Test-Path "C:\nssm\nssm.exe")) {
    if (Test-Path "$INSTALL_PATH\tools\nssm.exe") {
        New-Item -ItemType Directory -Path C:\nssm -Force | Out-Null
        Copy-Item "$INSTALL_PATH\tools\nssm.exe" "C:\nssm\nssm.exe" -Force
        Write-Host "  [OK] NSSM installed from project" -ForegroundColor Green
    } else {
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        Invoke-WebRequest -Uri $nssmUrl -OutFile "C:\nssm.zip" -UseBasicParsing
        Expand-Archive "C:\nssm.zip" -DestinationPath C:\temp_nssm -Force
        New-Item -ItemType Directory -Path C:\nssm -Force | Out-Null
        Copy-Item "C:\temp_nssm\nssm-2.24\win64\nssm.exe" "C:\nssm\nssm.exe" -Force
        Remove-Item C:\temp_nssm -Recurse -Force
        Remove-Item "C:\nssm.zip" -Force
        Write-Host "  [OK] NSSM downloaded and installed" -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] NSSM already installed" -ForegroundColor Green
}

# ============================================================================
# STEP 6: Install Nginx
# ============================================================================
Write-Host "[6/9] Installing Nginx..." -ForegroundColor Yellow
if (!(Test-Path "C:\nginx\nginx.exe")) {
    Invoke-WebRequest -Uri "http://nginx.org/download/nginx-1.24.0.zip" -OutFile "C:\nginx.zip" -UseBasicParsing
    Expand-Archive "C:\nginx.zip" -DestinationPath C:\ -Force
    Rename-Item "C:\nginx-1.24.0" "C:\nginx" -Force
    Remove-Item "C:\nginx.zip" -Force
    Write-Host "  [OK] Nginx installed" -ForegroundColor Green
} else {
    Write-Host "  [OK] Nginx already installed" -ForegroundColor Green
}

# Copy nginx.conf from project if exists
if (Test-Path "$INSTALL_PATH\nginx.conf") {
    Copy-Item "$INSTALL_PATH\nginx.conf" "C:\nginx\conf\nginx.conf" -Force
    Write-Host "  [OK] Nginx config updated" -ForegroundColor Green
}

# ============================================================================
# STEP 7: Configure Windows Firewall
# ============================================================================
Write-Host "[7/9] Configuring firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -DisplayName "Allow HTTP Port 80" -ErrorAction SilentlyContinue
if (!$firewallRule) {
    New-NetFirewallRule -DisplayName "Allow HTTP Port 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow | Out-Null
    Write-Host "  [OK] Firewall configured" -ForegroundColor Green
} else {
    Write-Host "  [OK] Firewall already configured" -ForegroundColor Green
}

# ============================================================================
# STEP 8: Setup Windows Services
# ============================================================================
Write-Host "[8/9] Setting up services..." -ForegroundColor Yellow

# Setup UnicornMaster service (web mode)
if (Test-Path "$INSTALL_PATH\unicorn_master.py") {
    $unicornService = Get-Service UnicornMaster -ErrorAction SilentlyContinue
    if (!$unicornService) {
        & C:\nssm\nssm.exe install UnicornMaster "$INSTALL_PATH\venv\Scripts\python.exe" "$INSTALL_PATH\unicorn_master.py"
        & C:\nssm\nssm.exe set UnicornMaster AppDirectory $INSTALL_PATH
        & C:\nssm\nssm.exe set UnicornMaster AppEnvironmentExtra MODE=web
        & C:\nssm\nssm.exe set UnicornMaster Start SERVICE_AUTO_START
        & C:\nssm\nssm.exe start UnicornMaster
        Write-Host "  [OK] UnicornMaster (web) installed" -ForegroundColor Green
    } else {
        & C:\nssm\nssm.exe set UnicornMaster AppEnvironmentExtra MODE=web
        & C:\nssm\nssm.exe restart UnicornMaster
        Write-Host "  [OK] UnicornMaster (web) restarted" -ForegroundColor Green
    }

    $workerEnv = @("MODE=worker")
    $celeryEnvNames = @(
        "CELERY_APP",
        "CELERY_BROKER_URL",
        "CELERY_RESULT_BACKEND",
        "CELERY_LOGLEVEL",
        "CELERY_POOL",
        "CELERY_CONCURRENCY",
        "CELERY_QUEUES",
        "CELERY_EXTRA_ARGS"
    )

    foreach ($envName in $celeryEnvNames) {
        $envValue = Get-FirstAvailableEnvValue -Name $envName
        if (![string]::IsNullOrWhiteSpace($envValue)) {
            $workerEnv += "$envName=$envValue"
        }
    }

    if (($workerEnv | Where-Object { $_ -like "CELERY_APP=*" }).Count -eq 0) {
        Write-Host "  [WARN] CELERY_APP not found in Process/Machine/User environment. Worker will exit until set." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] Celery environment detected for UnicornWorker" -ForegroundColor Green
    }
    
    # Setup Worker service
    $workerService = Get-Service UnicornWorker -ErrorAction SilentlyContinue
    if (!$workerService) {
        & C:\nssm\nssm.exe install UnicornWorker "$INSTALL_PATH\venv\Scripts\python.exe" "$INSTALL_PATH\unicorn_master.py"
        & C:\nssm\nssm.exe set UnicornWorker AppDirectory $INSTALL_PATH
        & C:\nssm\nssm.exe set UnicornWorker AppEnvironmentExtra $workerEnv
        & C:\nssm\nssm.exe set UnicornWorker Start SERVICE_AUTO_START
        & C:\nssm\nssm.exe start UnicornWorker
        Write-Host "  [OK] UnicornWorker installed" -ForegroundColor Green
    } else {
        & C:\nssm\nssm.exe set UnicornWorker AppEnvironmentExtra $workerEnv
        & C:\nssm\nssm.exe restart UnicornWorker
        Write-Host "  [OK] UnicornWorker restarted" -ForegroundColor Green
    }
}

# Setup Nginx service
$nginxService = Get-Service NginxService -ErrorAction SilentlyContinue
if (!$nginxService) {
    & C:\nssm\nssm.exe install NginxService "C:\nginx\nginx.exe"
    & C:\nssm\nssm.exe set NginxService AppDirectory "C:\nginx"
    & C:\nssm\nssm.exe set NginxService Start SERVICE_AUTO_START
    & C:\nssm\nssm.exe start NginxService
    Write-Host "  [OK] Nginx service installed" -ForegroundColor Green
} else {
    & C:\nssm\nssm.exe restart NginxService
    Write-Host "  [OK] Nginx service restarted" -ForegroundColor Green
}

# ============================================================================
# STEP 9: Verification
# ============================================================================
Write-Host "[9/9] Verifying installation..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$unicorn = Get-Service UnicornMaster -ErrorAction SilentlyContinue
$worker = Get-Service UnicornWorker -ErrorAction SilentlyContinue
$nginx = Get-Service NginxService -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

if ($unicorn) {
    Write-Host "UnicornMaster: $($unicorn.Status)" -ForegroundColor $(if($unicorn.Status -eq 'Running'){'Green'}else{'Red'})
}
if ($worker) {
    Write-Host "UnicornWorker: $($worker.Status)" -ForegroundColor $(if($worker.Status -eq 'Running'){'Green'}else{'Red'})
}
if ($nginx) {
    Write-Host "NginxService: $($nginx.Status)" -ForegroundColor $(if($nginx.Status -eq 'Running'){'Green'}else{'Red'})
}

Write-Host ""
Write-Host "Project installed at: $INSTALL_PATH"
Write-Host "Access your app at: http://YOUR_SERVER_IP"
Write-Host ""