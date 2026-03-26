<#
.SYNOPSIS
Extracts a NuGet package and unblocks all DLLs within it.
.DESCRIPTION
This script downloads a specified NuGet package, extracts it to a designated directory, and unblocks all DLL files within the extracted content.
.EXAMPLE

#>
Param(
    [Parameter(Mandatory = $true)]
    [string]$packageName,

    [Parameter(Mandatory = $true)]
    [string]$version,

    [Parameter(Mandatory = $true)]
    [string]$url
)

# Get the script's directory and build absolute paths
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$packageUrl = "$url/$packageName/$version"
$downloadPath = Join-Path $scriptDir "package\$packageName\downloaded\$packageName.$version.nupkg"
$extractPath = Join-Path $scriptDir "package\$packageName\extracted\$version"

#write-host "extractPath: $extractPath"

# Create directories if they don't exist
$downloadDir = Split-Path -Path $downloadPath -Parent
if (-not (Test-Path -Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    Write-Host "Created download directory: $downloadDir"
}

if (-not (Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    Write-Host "Created extract directory: $extractPath"
}

# Download the NuGet package
Write-Host "Downloading package from: $packageUrl"
Invoke-WebRequest -Uri $packageUrl -OutFile $downloadPath
Write-Host "Package downloaded to: $downloadPath"

# Extract the .nupkg
Write-Host "Extracting package to: $extractPath"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath)
Write-Host "Package extracted successfully"

# Unblock all DLLs
Write-Host "Unblocking DLL files..."
$dllFiles = Get-ChildItem -Path $extractPath -Recurse -Include *.dll
if ($dllFiles) {
    $dllFiles | Unblock-File
    Write-Host "Unblocked $($dllFiles.Count) DLL file(s)"
}
else {
    Write-Host "No DLL files found to unblock"
}

Write-Host "Package extracted to: $extractPath"
