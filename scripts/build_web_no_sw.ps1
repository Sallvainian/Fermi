#!/usr/bin/env pwsh
# Build Flutter web WITHOUT service worker for better cache control

Write-Host "Building Flutter web without service worker..." -ForegroundColor Green

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Build without service worker
Write-Host "Building Flutter web app without PWA..." -ForegroundColor Yellow
flutter build web --pwa-strategy=none --release

# Generate build ID from git commit or timestamp
try {
    $BUILD_ID = git rev-parse --short HEAD
} catch {
    $BUILD_ID = [DateTimeOffset]::Now.ToUnixTimeSeconds()
}

Write-Host "Build ID: $BUILD_ID" -ForegroundColor Cyan

# Update index.html to add version query string to flutter_bootstrap.js
$indexFile = "build/web/index.html"
if (Test-Path $indexFile) {
    Write-Host "Adding version stamp to flutter_bootstrap.js in index.html..." -ForegroundColor Yellow
    
    $content = Get-Content $indexFile -Raw
    
    # Replace flutter_bootstrap.js with flutter_bootstrap.js?v=BUILD_ID
    $content = $content -replace 'flutter_bootstrap\.js', "flutter_bootstrap.js?v=$BUILD_ID"
    
    Set-Content -Path $indexFile -Value $content -NoNewline
    
    Write-Host "Stamped bootstrap script with version: $BUILD_ID" -ForegroundColor Green
} else {
    Write-Host "Error: index.html not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "Build ID: $BUILD_ID" -ForegroundColor Cyan
Write-Host "`nTo deploy, run: firebase deploy --only hosting" -ForegroundColor Yellow