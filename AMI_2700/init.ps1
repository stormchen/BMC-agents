# ==============================================================================
# OpenBMC OneTree Harness - Environment Init and Verification (PowerShell)
# ==============================================================================
# Usage: .\init.ps1
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
# 0. Pre-check
# ==============================================================================
Write-Header "OpenBMC OneTree Environment Init"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $SCRIPT_DIR

Write-Info "Working directory: $(Get-Location)"
Write-Info "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info "User: $env:USERNAME"

# ==============================================================================
# 1. Git Status Check
# ==============================================================================
Write-Header "1. Git Status Check"

try {
    $null = git rev-parse --is-inside-work-tree 2>$null
    Write-Pass "Valid Git repository"

    $BRANCH = git branch --show-current
    Write-Info "Current branch: $BRANCH"

    $COMMIT = git log --oneline -1
    Write-Info "Latest commit: $COMMIT"

    $STATUS = git status --porcelain 2>$null
    if ($STATUS) {
        Write-Warn "Working directory has uncommitted changes"
        $STATUS | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
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

    git submodule sync --recursive 2>$null
    Write-Pass "Submodules synced"

    $UNINIT_STATUS = git submodule status 2>$null | Select-String "^-"
    if ($UNINIT_STATUS) {
        $UNINIT_COUNT = ($UNINIT_STATUS | Measure-Object).Count
        Write-Warn "$UNINIT_COUNT submodule(s) not initialized"
        Write-Info "Running: git submodule update --init --recursive"
        try { git submodule update --init --recursive } catch { }
    } else {
        Write-Pass "All submodules initialized"
    }
} else {
    Write-Info "No .gitmodules file (normal)"
}

# ==============================================================================
# 3. Essential Files Check
# ==============================================================================
Write-Header "3. Essential Files Check"

$ESSENTIAL_FILES = @(
    "oe-init-build-env"
    "openbmc-env"
    "poky"
    "meta-core"
    "meta-ami"
    "meta-aspeed"
)

foreach ($file in $ESSENTIAL_FILES) {
    if (Test-Path $file) {
        Write-Pass "Exists: $file"
    } else {
        Write-Fail "Missing: $file"
    }
}

# BitBake path check - root bitbake/ is a Git symlink -> poky/bitbake/
# Windows does not natively support symlinks, so check both paths
$BITBAKE_PATH = $null
if (Test-Path "bitbake/bin/bitbake") {
    $BITBAKE_PATH = "bitbake/bin/bitbake"
} elseif (Test-Path "poky/bitbake/bin/bitbake") {
    $BITBAKE_PATH = "poky/bitbake/bin/bitbake"
}

if ($BITBAKE_PATH) {
    if ($BITBAKE_PATH -ne "bitbake/bin/bitbake") {
        Write-Info "bitbake/ is a symlink, actual path: $BITBAKE_PATH"
    }
    Write-Pass "Exists: bitbake/bin/bitbake"
} else {
    Write-Fail "Missing: bitbake/bin/bitbake"
}

# ==============================================================================
# 4. Harness Files Check
# ==============================================================================
Write-Header "4. Harness Files Check"

$HARNESS_FILES = @(
    "AGENTS.md"
    "feature_list.json"
    "harness-progress.md"
)

foreach ($file in $HARNESS_FILES) {
    if (Test-Path $file) {
        Write-Pass "Exists: $file"
    } else {
        Write-Warn "Missing: $file (recommended to create)"
    }
}

# ==============================================================================
# 5. BitBake Environment Check
# ==============================================================================
Write-Header "5. BitBake Environment Check"

if ($BITBAKE_PATH) {
    Write-Pass "BitBake exists ($BITBAKE_PATH)"

    # Try to show bitbake version (on Windows, bitbake is a Python script, may not run directly)
    try {
        $BB_VERSION = & ./$BITBAKE_PATH --version 2>$null | Select-Object -First 1
        if ($BB_VERSION) {
            Write-Pass "BitBake version: $BB_VERSION"
        } else {
            Write-Warn "Cannot run BitBake (may need build environment)"
        }
    } catch {
        Write-Warn "Cannot run BitBake (may need build environment)"
    }
} else {
    Write-Fail "BitBake not found"
}

# ==============================================================================
# 6. Meta Layers Check
# ==============================================================================
Write-Header "6. Meta Layers Check"

$META_LAYERS = @(
    "meta-core"
    "meta-ami"
    "meta-aspeed"
    "meta-phosphor"
    "meta-openembedded"
    "poky/meta"
)

foreach ($layer in $META_LAYERS) {
    if (Test-Path $layer -PathType Container) {
        if (Test-Path "$layer/conf/layer.conf") {
            Write-Pass "Layer OK: $layer"
        } else {
            Write-Warn "Layer exists but missing conf/layer.conf: $layer"
        }
    } else {
        Write-Warn "Layer missing: $layer (may be optional)"
    }
}

# ==============================================================================
# 7. Build Directory Check (if exists)
# ==============================================================================
Write-Header "7. Build Directory Check"

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
        Write-Warn "bblayers.conf not found (may need initialization)"
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
        Write-Warn "local.conf not found (may need initialization)"
    }
} else {
    Write-Info "Build directory does not exist"
    Write-Info "Recommend running: source openbmc-env to initialize build environment"
}

# ==============================================================================
# 8. System Resources Check
# ==============================================================================
Write-Header "8. System Resources Check"

# Disk space
$DRIVE_LETTER = (Get-Location).Drive.Name
$DISK_AVAIL = (Get-Volume -DriveLetter $DRIVE_LETTER).SizeRemaining
if ($DISK_AVAIL) {
    $UNIT = if ($DISK_AVAIL -gt 1TB) { 'TB' }
           elseif ($DISK_AVAIL -gt 1GB) { 'GB' }
           elseif ($DISK_AVAIL -gt 1MB) { 'MB' }
           else { 'GB' }

    $DISPLAY = if ($UNIT -eq 'TB') { [math]::Round($DISK_AVAIL / 1TB, 2) }
               elseif ($UNIT -eq 'GB') { [math]::Round($DISK_AVAIL / 1GB, 2) }
               elseif ($UNIT -eq 'MB') { [math]::Round($DISK_AVAIL / 1MB, 2) }
               else { [math]::Round($DISK_AVAIL / 1GB, 2) }

    Write-Info "Available disk space: ${DISPLAY}${UNIT}"
} else {
    Write-Info "Available disk space: unable to determine"
}

# Memory
try {
    $MEM = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $MEM_TOTAL = [math]::Round($MEM.TotalVisibleMemorySize / 1MB, 2)
    $MEM_FREE  = [math]::Round($MEM.FreePhysicalMemory / 1MB, 2)
    Write-Info "Memory: ${MEM_FREE} GB / ${MEM_TOTAL} GB available"
} catch {
    Write-Info "Memory: unable to determine"
}

# CPU
try {
    $LOGICAL_PROCESSORS = [Environment]::ProcessorCount
    Write-Info "CPU cores: $LOGICAL_PROCESSORS"
} catch {
    Write-Info "CPU cores: $([Environment]::ProcessorCount)"
}

# ==============================================================================
# 9. Summary
# ==============================================================================
Write-Header "Initialization Check Complete"

Write-Host ""
Write-Host "Result Summary:"
Write-Host "  Passed: $PASS" -ForegroundColor Green
Write-Host "  Failed: $FAIL" -ForegroundColor Red
Write-Host "  Warning: $WARN" -ForegroundColor Yellow
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
