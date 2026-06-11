# ==============================================================================
# OpenBMC - Environment Init and Verification (PowerShell)
# ==============================================================================
# Usage: .\init.ps1
# Config priority: env vars > harness.conf > built-in defaults
# ==============================================================================

$ErrorActionPreference = 'Stop'

# Register Big5 encoding provider (PowerShell 7 requires this)
try {
    if (-not ([System.Text.Encoding]::CodePageFallback -is [System.Text.CodePagesEncodingProvider])) {
        [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
    }
} catch {
    # Big5 encoding provider not available in this PowerShell version - skip
}

# Color output helpers
function Write-Log {
    param(
        [string]$Tag,
        [string]$Message,
        [ConsoleColor]$Color
    )
    Write-Host "[$Tag] $Message" -ForegroundColor $Color
}

function Write-Info  { Write-Log -Tag 'INFO'  -Message $args[0] -Color Blue   }
function Write-Pass  {
    Write-Log -Tag 'PASS' -Message $args[0] -Color Green
    $script:PASS++
}
function Write-Fail  {
    Write-Log -Tag 'FAIL' -Message $args[0] -Color Red
    $script:FAIL++
}
function Write-Warn  {
    Write-Log -Tag 'WARN' -Message $args[0] -Color Yellow
    $script:WARN++
}

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host " $args" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}

# Counters
$script:PASS = 0
$script:FAIL = 0
$script:WARN = 0

# ==============================================================================
# Config Loading — priority: env vars > harness.conf > built-in defaults
# ==============================================================================
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Built-in defaults
$DefaultProjectName  = "OpenBMC"
$DefaultMachine      = ""
$DefaultImage        = ""
$DefaultSetupCmd     = ""
$DefaultRequiredFiles = @("AGENTS.md", "feature_list.json", "claude-progress.md")
$DefaultKeyLayers    = @()

# Load harness.conf if it exists
$ConfPath = Join-Path $SCRIPT_DIR "harness.conf"
if (Test-Path $ConfPath) {
    Write-Info "[harness] Loaded harness.conf"
    $ConfLines = Get-Content $ConfPath
    foreach ($line in $ConfLines) {
        $line = $line.Trim()
        # Skip comments and empty lines
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        # Parse KEY=VALUE (strip quotes)
        if ($line -match '^(\w+)="(.*)"') {
            $key = $matches[1]
            $val = $matches[2]
            Set-Variable -Name $key -Value $val -Scope Script
        } elseif ($line -match "^(\w+)=(.+)$") {
            $key = $matches[1]
            $val = $matches[2]
            Set-Variable -Name $key -Value $val -Scope Script
        }
    }
}

# Environment variable override (env vars take precedence over harness.conf)
$ProjectName  = $env:HARNESS_PROJECT_NAME  ?? ${HARNESS_PROJECT_NAME}  ?? $DefaultProjectName
$Machine      = $env:HARNESS_MACHINE       ?? ${HARNESS_MACHINE}        ?? $DefaultMachine
$ImageTarget  = $env:HARNESS_IMAGE         ?? ${HARNESS_IMAGE}          ?? $DefaultImage
$SetupCmd     = $env:HARNESS_SETUP_CMD     ?? ${HARNESS_SETUP_CMD}      ?? $DefaultSetupCmd

# Parse space-separated lists into arrays
$RequiredFiles = ($env:HARNESS_REQUIRED_FILES ?? ${HARNESS_REQUIRED_FILES} ?? "") -split '\s+' | Where-Object { $_.Length -gt 0 }
if ($RequiredFiles.Count -eq 0 -or ($RequiredFiles.Count -eq 1 -and [string]::IsNullOrWhiteSpace($RequiredFiles[0]))) {
    $RequiredFiles = $DefaultRequiredFiles
}

$KeyLayers = ($env:HARNESS_KEY_LAYERS ?? ${HARNESS_KEY_LAYERS} ?? "") -split '\s+' | Where-Object { $_.Length -gt 0 }
if ($KeyLayers.Count -eq 0 -or ($KeyLayers.Count -eq 1 -and [string]::IsNullOrWhiteSpace($KeyLayers[0]))) {
    $KeyLayers = $DefaultKeyLayers
}

# ==============================================================================
# 0. Pre-check
# ==============================================================================
Write-Header "$ProjectName Environment Init"

Set-Location $SCRIPT_DIR

Write-Info "Working directory: $(Get-Location)"
Write-Info "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info "User: $env:USERNAME"

# ==============================================================================
# 1. Git Status Check
# ==============================================================================
Write-Header "1. Git Status Check"

try {
    $PROJECT_ROOT = git rev-parse --show-toplevel 2>$null
    if ($PROJECT_ROOT) {
        Write-Pass "Valid Git repository"
        Write-Info "Project root: $PROJECT_ROOT"

        if ($PROJECT_ROOT -ne (Get-Location).Path) {
            Write-Warn "Recommended to run this script from the project root directory"
        }
    }

    $BRANCH = git branch --show-current
    Write-Info "Current branch: $BRANCH"

    git log --oneline -5 | ForEach-Object { Write-Info "  $_" }

    $STATUS = git status --porcelain 2>$null
    if ($STATUS) {
        Write-Warn "Working directory has uncommitted changes"
        $STATUS | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Pass "Working directory is clean"
    }
} catch {
    Write-Fail "Not a valid Git repository"
}

# ==============================================================================
# 2. Submodule Check
# ==============================================================================
Write-Header "2. Submodule Check"

if (Test-Path ".gitmodules") {
    $SUBMODULE_COUNT = (git config --file .gitmodules --get-regexp path 2>$null).Count
    Write-Info "Found $SUBMODULE_COUNT submodule(s)"

    $UNINIT_STATUS = git submodule status 2>$null | Select-String "^-"
    if ($UNINIT_STATUS) {
        $UNINIT_COUNT = ($UNINIT_STATUS | Measure-Object).Count
        Write-Warn "$UNINIT_COUNT submodule(s) not initialized"
        Write-Info "Recommend running: git submodule update --init --recursive"
    } else {
        Write-Pass "All submodules initialized"
    }
} else {
    Write-Info "No .gitmodules file"
}

# ==============================================================================
# 3. Essential Files Check
# ==============================================================================
Write-Header "3. Essential Files Check"

$REQUIRED_FILES = $RequiredFiles

$all_present = $true
foreach ($file in $REQUIRED_FILES) {
    if (Test-Path $file) {
        Write-Pass "Exists: $file"
    } else {
        Write-Fail "Missing: $file"
        $all_present = $false
    }
}

# ==============================================================================
# 4. Meta Layers Check
# ==============================================================================
Write-Header "4. Meta Layers Check"

$KEY_LAYERS_ARR = $KeyLayers

if ($KEY_LAYERS_ARR.Count -gt 0) {
    foreach ($layer in $KEY_LAYERS_ARR) {
        if (Test-Path $layer -PathType Container) {
            Write-Pass "Exists: $layer"
        } else {
            Write-Warn "$layer not found (may be a submodule, needs initialization)"
        }
    }
} else {
    Write-Info "Skipped meta-layer check (not configured)"
}

# ==============================================================================
# 5. Build Directory Check
# ==============================================================================
Write-Header "5. Build Directory Check"

if (Test-Path "build" -PathType Container) {
    Write-Pass "Build directory exists"

    if (Test-Path "build/conf/bblayers.conf") {
        Write-Pass "bblayers.conf exists"

        # Show configured layers
        Write-Info "Configured Layers:"
        $LAYER_CONTENT = Get-Content "build/conf/bblayers.conf" -Raw
        if ($LAYER_CONTENT -match 'BBLAYERS\s*\??=\s*\{([^}]+)\}') {
            $matches[1] -split "`n" | Where-Object { $_.Trim().StartsWith('"') } | ForEach-Object {
                $layerPath = $_ -replace '.*"([^"]+)".*', '$1'
                Write-Host "  - $layerPath"
            }
        }
    } else {
        if ($SetupCmd) {
            Write-Warn "bblayers.conf not found - need to run: $SetupCmd"
        } else {
            Write-Warn "bblayers.conf not found - need to initialize build environment"
        }
    }

    if (Test-Path "build/conf/local.conf") {
        Write-Pass "local.conf exists"

        # Show MACHINE setting
        $LOCAL_CONTENT = Get-Content "build/conf/local.conf" -Raw
        if ($LOCAL_CONTENT -match '^MACHINE\s*\??=\s*"([^"]+)"') {
            Write-Info "MACHINE: ${matches[1]}"
        } else {
            Write-Info "MACHINE: unknown"
        }
    } else {
        if ($SetupCmd) {
            Write-Warn "local.conf not found - need to run: $SetupCmd"
        } else {
            Write-Warn "local.conf not found - need to initialize build environment"
        }
    }
} else {
    Write-Info "Build directory does not exist"
    if ($SetupCmd) {
        Write-Info "Recommend running: $SetupCmd"
    } else {
        Write-Info "Recommend initializing build environment"
    }
}

# ==============================================================================
# 6. Summary
# ==============================================================================
Write-Header "Initialization Check Complete"

Write-Host ""
Write-Host "Result Summary:"
Write-Host "  Passed: $PASS" -ForegroundColor Green
Write-Host "  Failed: $FAIL" -ForegroundColor Red
Write-Host "  Warning: $WARN" -ForegroundColor Yellow
Write-Host ""

if (-not $all_present) {
    Write-Warn "Some required files are missing. Please create or copy the missing files."
}

Write-Host ""
Write-Host "Next Steps:"
if ($SetupCmd) {
    Write-Host "  1. If build environment is not initialized, run: $SetupCmd"
}
if ($ImageTarget) {
    Write-Host "  2. To build image, run: bitbake $ImageTarget"
}
Write-Host "  3. To start development, read claude-progress.md and feature_list.json"
Write-Host ""

if ($FAIL -gt 0) {
    Write-Host "[!] $FAIL check(s) failed. Please resolve these before starting development." -ForegroundColor Red
    exit 1
} else {
    Write-Host "[OK] All required checks passed. Environment is ready." -ForegroundColor Green
    if ($WARN -gt 0) {
        Write-Host "[*] $WARN warning(s). Recommended to review and address." -ForegroundColor Yellow
    }
    exit 0
}
