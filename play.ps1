# Bad Apple Player for Windows PowerShell
# This script runs the bash script on Windows systems

param(
    [switch]$Help,
    [switch]$Clean,
    [switch]$Fresh
)

Write-Host "🍎 Bad Apple ASCII Animation Player for Windows" -ForegroundColor Yellow
Write-Host ""

# Check if we're on Windows
if ($env:OS -notlike "*Windows*") {
    Write-Host "❌ This script is for Windows only!" -ForegroundColor Red
    exit 1
}

# Check for bash
$bashAvailable = $null
try {
    $bashAvailable = Get-Command bash -ErrorAction Stop
} catch {
    $bashAvailable = $null
}

if (-not $bashAvailable) {
    Write-Host "❌ Bash not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install one of the following:" -ForegroundColor Yellow
    Write-Host "  1. Git for Windows (includes Git Bash)" -ForegroundColor Cyan
    Write-Host "     Download: https://gitforwindows.org/" -ForegroundColor Cyan
    Write-Host "  2. Windows Subsystem for Linux (WSL)" -ForegroundColor Cyan
    Write-Host "     Run in PowerShell (Admin): wsl --install" -ForegroundColor Cyan
    Write-Host "  3. MSYS2 or Cygwin" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then run this script again." -ForegroundColor Green
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✅ Bash found! Starting Bad Apple Player..." -ForegroundColor Green
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir "play.sh"

# Build arguments
$args = @()
if ($Clean) { $args += "--clean" }
if ($Fresh) { $args += "--fresh" }
if ($Help) { $args += "--help" }

# Run the bash script
try {
    & bash $bashScript @args
    $exitCode = $LASTEXITCODE
} catch {
    Write-Host "❌ Failed to run bash script: $_" -ForegroundColor Red
    $exitCode = 1
}

# Handle exit code
if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "❌ Script exited with error code $exitCode" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}

exit $exitCode