#!/usr/bin/env pwsh
# Build script that properly updates service worker version for cache busting

Write-Host "Building Flutter web with cache busting..." -ForegroundColor Green

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Build the web app
Write-Host "Building Flutter web app..." -ForegroundColor Yellow
flutter build web --release

# Generate a unique version based on current timestamp
$version = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
Write-Host "Generated version: $version" -ForegroundColor Cyan

# Update serviceWorkerVersion in flutter_bootstrap.js
$bootstrapFile = "build/web/flutter_bootstrap.js"
if (Test-Path $bootstrapFile) {
    Write-Host "Updating service worker version in flutter_bootstrap.js..." -ForegroundColor Yellow
    
    # Read the file content
    $content = Get-Content $bootstrapFile -Raw
    
    # Replace the serviceWorkerVersion with new timestamp
    # Match pattern: serviceWorkerVersion: "any_number"
    $pattern = 'serviceWorkerVersion:\s*"[^"]*"'
    $replacement = "serviceWorkerVersion: `"$version`""
    
    $newContent = $content -replace $pattern, $replacement
    
    # Write back the updated content
    Set-Content -Path $bootstrapFile -Value $newContent -NoNewline
    
    Write-Host "Updated service worker version to: $version" -ForegroundColor Green
} else {
    Write-Host "Error: flutter_bootstrap.js not found!" -ForegroundColor Red
    exit 1
}

# Also update version.json with the same version for consistency
$versionFile = "build/web/version.json"
$versionJson = @{
    version = $version.ToString()
    build_number = $version.ToString()
    package_name = "teacher_dashboard"
} | ConvertTo-Json

Set-Content -Path $versionFile -Value $versionJson
Write-Host "Updated version.json" -ForegroundColor Green

# Update the service worker itself to force cache invalidation
$serviceWorkerFile = "build/web/flutter_service_worker.js"
if (Test-Path $serviceWorkerFile) {
    # Add a comment with the version at the top of the service worker
    $swContent = Get-Content $serviceWorkerFile -Raw
    $swContent = "// Build version: $version`n" + $swContent
    Set-Content -Path $serviceWorkerFile -Value $swContent -NoNewline
    Write-Host "Updated flutter_service_worker.js" -ForegroundColor Green
}

Write-Host "`nBuild complete with cache busting!" -ForegroundColor Green
Write-Host "Service worker version: $version" -ForegroundColor Cyan
Write-Host "`nTo deploy, run: firebase deploy --only hosting" -ForegroundColor Yellow