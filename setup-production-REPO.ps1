#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Universal Windows Production Server Setup Script
.DESCRIPTION
    Installs and configures Python, Git, Nginx, NSSM, and services.
    Designed to run from within the cloned repository.
#>

$ErrorActionPreference = "Stop"
Set-Location "C:\temp\project"
$INSTALL_PATH = "C:\production"
$REPO_PATH = Get-Location
Start-Transcript -Path "C:\deployment.log" -Append

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

function Get-CeleryConfigObject {
    param([string]$ConfigPath)

    if (!(Test-Path $ConfigPath)) {
        return $null
    }

    try {
        $rawConfig = Get-Content $ConfigPath -Raw
        if ([string]::IsNullOrWhiteSpace($rawConfig)) {
            return $null
        }
        return $rawConfig | ConvertFrom-Json
    } catch {
        Write-Host "  [WARN] Failed to parse celery_config.json. Falling back to environment values." -ForegroundColor Yellow
        return $null
    }
}

function Get-CeleryConfigValue {
    param(
        $Config,
        [string]$PropertyName
    )

    if ($null -eq $Config) {
        return $null
    }

    $property = $Config.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    $value = $property.Value
    if ($null -eq $value) {
        return $null
    }

    if ($value -is [System.Array]) {
        $joinedValue = ($value | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) }) -join ","
        if ([string]::IsNullOrWhiteSpace($joinedValue)) {
            return $null
        }
        return $joinedValue
    }

    $textValue = [string]$value
    if ([string]::IsNullOrWhiteSpace($textValue)) {
        return $null
    }

    return $textValue.Trim()
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
# ===========================================================================
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
        Write-Host "  NSSM not found in project. Installing -- "
        $nssmUrl = "https://github.com/imvickykumar999/Non-Sucking-Service-Manager/releases/download/nssm-2.24/nssm-2.24.zip"
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
    if (Test-Path "C:\nginx") {
        Write-Host "  [WARN] Existing C:\nginx directory found without nginx.exe. Removing stale directory..." -ForegroundColor Yellow
        Remove-Item "C:\nginx" -Recurse -Force
    }

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
$rule443 = Get-NetFirewallRule -DisplayName "Allow HTTPS Port 443" -ErrorAction SilentlyContinue
if (!$rule443) {
    New-NetFirewallRule -DisplayName "Allow HTTPS Port 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow | Out-Null
    Write-Host "  [OK] Port 443 firewall rule added" -ForegroundColor Green
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

    $celeryConfigPath = "$INSTALL_PATH\celery_config.json"
    $celeryConfig = Get-CeleryConfigObject -ConfigPath $celeryConfigPath

    if ($null -ne $celeryConfig) {
        Write-Host "  [OK] Loaded celery_config.json from project" -ForegroundColor Green

        $workerEnv = @("MODE=worker")
        $celeryEnvNames = @(
            "CELERY_APP",
            "CELERY_BROKER_URL",
            "CELERY_RESULT_BACKEND",
            "CELERY_LOGLEVEL",
            "CELERY_POOL",
            "CELERY_CONCURRENCY",
            "CELERY_QUEUES",
            "CELERY_EXTRA_ARGS",
            "CELERY_IMPORTS"
        )
        $celeryConfigKeyMap = @{
            "CELERY_APP" = "celery_app"
            "CELERY_BROKER_URL" = "broker_url"
            "CELERY_RESULT_BACKEND" = "result_backend"
            "CELERY_LOGLEVEL" = "loglevel"
            "CELERY_POOL" = "pool"
            "CELERY_CONCURRENCY" = "concurrency"
            "CELERY_QUEUES" = "queues"
            "CELERY_EXTRA_ARGS" = "extra_args"
            "CELERY_IMPORTS" = "imports"
        }

        foreach ($envName in $celeryEnvNames) {
            $configProperty = $celeryConfigKeyMap[$envName]
            $configValue = Get-CeleryConfigValue -Config $celeryConfig -PropertyName $configProperty
            $envValue = $configValue

            if ([string]::IsNullOrWhiteSpace($envValue)) {
                $envValue = Get-FirstAvailableEnvValue -Name $envName
            }

            if (![string]::IsNullOrWhiteSpace($envValue)) {
                $workerEnv += "$envName=$envValue"
            }
        }

        if (($workerEnv | Where-Object { $_ -like "CELERY_APP=*" }).Count -eq 0) {
            $workerEnv += "CELERY_APP=celery_app:celery"
            Write-Host "  [OK] CELERY_APP not set. Using default celery_app:celery" -ForegroundColor Yellow
        }
        Write-Host "  [OK] Celery settings prepared for UnicornWorker" -ForegroundColor Green

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
    } else {
        Write-Host "  [SKIP] celery_config.json not found. Skipping UnicornWorker." -ForegroundColor Yellow
    }
}
    


# Setup/restart Nginx with final config (SSL if cert exists, HTTP if not)
$nginxService = Get-Service NginxService -ErrorAction SilentlyContinue
if (!$nginxService) {
    & C:\nssm\nssm.exe install NginxService "C:\nginx\nginx.exe"
    & C:\nssm\nssm.exe set NginxService AppDirectory "C:\nginx"
    & C:\nssm\nssm.exe set NginxService Start SERVICE_AUTO_START
    & C:\nssm\nssm.exe start NginxService
    Write-Host "  [OK] Nginx service installed" -ForegroundColor Green
} else {
    & C:\nssm\nssm.exe stop NginxService confirm
    Start-Sleep -Seconds 2

    if (!(Test-Path "C:\nginx\conf\ssl\cert.pem")) {
    Write-Host "  [WARN] SSL cert missing, falling back to HTTP config" -ForegroundColor Yellow
    # Copy HTTP-only nginx config if you have one, or just continue
    } else {
    Write-Host "  [OK] SSL certs present" -ForegroundColor Green
}
    Write-Host "  [OK] SSL certs present" -ForegroundColor Green
    $ErrorActionPreference = "Continue"
    Push-Location "C:\nginx"
    $testResult = & "C:\nginx\nginx.exe" -t 2>&1
    $nginxExitCode = $LASTEXITCODE
    Pop-Location
    $ErrorActionPreference = "Stop"

    Write-Host $testResult
    if ($nginxExitCode -ne 0) {
        Write-Host "  [FAIL] Nginx config test failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] Nginx config valid" -ForegroundColor Green

    & C:\nssm\nssm.exe start NginxService
    Write-Host "  [OK] Nginx service restarted" -ForegroundColor Green
}
# ============================================================================
# STEP 09: Verification
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
Write-Host "Access your app at: https://YOUR_DOMAIN or http://YOUR_SERVER_IP"
Write-Host ""
Stop-Transcript