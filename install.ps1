# AllforOne Addon Install Script
# Copies the addon to your World of Warcraft AddOns folder

# ============================================================
# CONFIGURE YOUR WOW PATH HERE:
# ============================================================
$WoWPath = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
# ============================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonSource = Join-Path $ScriptDir "AllforOne"
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
Copy-Item -Path $AddonSource -Destination $AddonDestination -Recurse

if (Test-Path $AddonDestination) {
    Write-Host "Successfully installed AllforOne to: $AddonDestination" -ForegroundColor Green
} else {
    Write-Error "Failed to install addon"
    exit 1
}
