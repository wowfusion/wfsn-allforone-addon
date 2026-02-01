# AllforOne Addon Install Script
# Copies the addon to your World of Warcraft AddOns folder

param(
    [string]$WoWPath = "D:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns",
    [string]$SourcePath
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonSource = if ($SourcePath) { Resolve-Path $SourcePath } else { Join-Path $ScriptDir "AllforOne" }
$AddonDestination = Join-Path $WoWPath "AllforOne"

# Check if WoW AddOns folder exists
if (-not (Test-Path $WoWPath)) {
    Write-Error "WoW AddOns folder not found: $WoWPath"
    Write-Host "Please update the `$WoWPath variable in this script to match your WoW installation." -ForegroundColor Yellow
    exit 1
}

# Check if source addon exists
if (-not (Test-Path $AddonSource)) {
    Write-Error "Addon source folder not found: $AddonSource"
    exit 1
}

# Remove existing addon installation
if (Test-Path $AddonDestination) {
    Write-Host "Removing existing installation..."
    Remove-Item -Recurse -Force $AddonDestination
}

# Copy addon to WoW folder
Write-Host "Installing AllforOne addon..."
Copy-Item -Path $AddonSource -Destination $AddonDestination -Recurse -Force

if (Test-Path $AddonDestination) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "Successfully installed AllforOne to: $AddonDestination" -ForegroundColor Green
    Write-Host "Installed: $timestamp" -ForegroundColor Yellow
} else {
    Write-Error "Failed to install addon"
    exit 1
}
