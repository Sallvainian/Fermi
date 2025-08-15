# PowerShell script for building Flutter web with proper cache busting
Write-Host "Building Flutter web app with cache busting..." -ForegroundColor Green

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Build the web app
Write-Host "Building web app..." -ForegroundColor Yellow
flutter build web --release --no-tree-shake-icons

# Generate version info
$timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$buildHash = (Get-Random).ToString("X8")
$version = "$timestamp-$buildHash"

# Create version.json
$versionJson = @{
    version = $version
    buildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    buildHash = $buildHash
} | ConvertTo-Json

Set-Content -Path "build\web\version.json" -Value $versionJson

# Update index.html with new service worker version
$indexPath = "build\web\index.html"
$indexContent = Get-Content $indexPath -Raw
$indexContent = $indexContent -replace 'serviceWorkerVersion = "\d+"', "serviceWorkerVersion = `"$timestamp`""
Set-Content -Path $indexPath -Value $indexContent

Write-Host "Build complete! Version: $version" -ForegroundColor Green
Write-Host "Ready to deploy with: firebase deploy --only hosting" -ForegroundColor Cyan