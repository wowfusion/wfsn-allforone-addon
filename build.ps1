# AllforOne Addon Build Script
# Creates a ZIP file with version number from the AllforOne.toc

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonDir = Join-Path $ScriptDir "AllforOne"
$ReleaseDir = Join-Path $ScriptDir "Releases"
$TocFile = Join-Path $AddonDir "AllforOne.toc"

# Ensure Releases directory exists
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

# Read version from .toc file
$TocContent = Get-Content $TocFile -Raw
if ($TocContent -match '##\s*Version:\s*(.+)') {
    $Version = $Matches[1].Trim()
} else {
    Write-Error "Could not find version in AllforOne.toc"
    exit 1
}

$ZipFileName = "AllforOne-$Version.zip"
$ZipFilePath = Join-Path $ReleaseDir $ZipFileName

# Remove existing zip if it exists
if (Test-Path $ZipFilePath) {
    Remove-Item $ZipFilePath -Force
}

# Create ZIP file
Write-Host "Creating $ZipFileName..."
Compress-Archive -Path $AddonDir -DestinationPath $ZipFilePath -CompressionLevel Optimal

if (Test-Path $ZipFilePath) {
    Write-Host "Successfully created: $ZipFilePath" -ForegroundColor Green
} else {
    Write-Error "Failed to create ZIP file"
    exit 1
}
