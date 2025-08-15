# PowerShell script to update version before building
$timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$buildHash = (Get-Random).ToString("X8")
$version = "$timestamp-$buildHash"

# Create version.json in web directory
$versionJson = @{
    version = $version
    buildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    buildHash = $buildHash
} | ConvertTo-Json

Set-Content -Path "build\web\version.json" -Value $versionJson

Write-Host "Build version: $version"