# AllforOne Addon Build Script
# Creates a ZIP file with version number from the AllforOne.toc

param(
    [string]$Version,
    [string]$OutputDir = "Releases"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddonDir = Join-Path $ScriptDir "AllforOne"
$TocFile = Join-Path $AddonDir "AllforOne.toc"
$ReleaseDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $ScriptDir $OutputDir
}

# Ensure Releases directory exists
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

# Resolve version (CLI override beats toc)
if (-not $Version) {
    if (-not (Test-Path $TocFile)) {
        Write-Error "Could not find AllforOne.toc at $TocFile"
        exit 1
    }

    $TocContent = Get-Content $TocFile -Raw
    if ($TocContent -match '##\s*Version:\s*(.+)') {
        $Version = $Matches[1].Trim()
    } else {
        Write-Error "Could not find version in AllforOne.toc"
        exit 1
    }
}

$ZipFileName = "AllforOne-$Version.zip"
$ZipFilePath = Join-Path $ReleaseDir $ZipFileName

# Remove existing zip if it exists
if (Test-Path $ZipFilePath) {
    Remove-Item $ZipFilePath -Force
}

# Create ZIP file with forward slashes for cross-platform compatibility (Linux/Mac)
Write-Host "Creating $ZipFileName (Output: $ReleaseDir)..."

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

try {
    # Create ZIP archive manually with forward slashes
    $zipStream = [System.IO.File]::Create($ZipFilePath)
    $archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    
    # Get all files in the addon directory
    $files = Get-ChildItem -Path $AddonDir -Recurse -File
    
    foreach ($file in $files) {
        # Create relative path with forward slashes
        $relativePath = $file.FullName.Substring($AddonDir.Length + 1)
        $entryName = "AllforOne/" + ($relativePath -replace '\\', '/')
        
        # Add file to archive
        $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $fileStream = [System.IO.File]::OpenRead($file.FullName)
        $fileStream.CopyTo($entryStream)
        $fileStream.Close()
        $entryStream.Close()
    }
    
    $archive.Dispose()
    $zipStream.Close()
    
    Write-Host "Successfully created: $ZipFilePath" -ForegroundColor Green
    Write-Host "ZIP contains forward-slash paths for Linux/Mac compatibility" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to create ZIP file: $_"
    exit 1
}
