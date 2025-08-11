@echo off
REM PWA Local Build and Test Script for Windows
REM This script builds the Flutter web app as a PWA and serves it locally

echo.
echo ========================================
echo 🚀 Building Flutter PWA for iOS Testing
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed. Please install Flutter first.
    pause
    exit /b 1
)

REM Check Flutter version
echo 📋 Flutter Version:
call flutter --version
echo.

REM Clean previous builds
echo 🧹 Cleaning previous builds...
call flutter clean
echo.

REM Get dependencies
echo 📦 Getting dependencies...
call flutter pub get
echo.

REM Build for web with PWA optimizations
echo 🔨 Building PWA...
call flutter build web --release --pwa-strategy=offline-first --web-renderer=html --no-tree-shake-icons

REM Check if build was successful
if not exist "build\web" (
    echo ❌ Build failed. Please check the error messages above.
    pause
    exit /b 1
)

echo ✅ Build successful!
echo.

REM Verify PWA configuration
echo 📝 Verifying PWA configuration...
if exist "build\web\manifest.json" (
    echo ✅ manifest.json found
) else (
    echo ❌ manifest.json not found
)

if exist "build\web\flutter_service_worker.js" (
    echo ✅ Service worker found
) else (
    echo ⚠️  Service worker not found - offline mode may not work
)
echo.

REM Get local IP address
echo 🌐 Getting your local IP address...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" ^| findstr /v "127.0.0.1"') do (
    for /f "tokens=*" %%b in ("%%a") do set LOCAL_IP=%%b
)

echo.
echo ================================
echo 📱 To test on your iOS device:
echo ================================
echo 1. Make sure your iOS device is on the same Wi-Fi network
echo 2. Open Safari on your iOS device
if defined LOCAL_IP (
    echo 3. Go to: http://%LOCAL_IP%:8080
) else (
    echo 3. Find your IP: Run 'ipconfig' and look for IPv4 Address
    echo    Then go to: http://YOUR_IP:8080
)
echo 4. Tap the Share button (square with arrow up)
echo 5. Select "Add to Home Screen"
echo 6. Tap "Add" to install
echo ================================
echo.
echo The app will now work like a native iOS app!
echo.
echo Press Ctrl+C to stop the server when done
echo.

REM Start local server
cd build\web

REM Check if Python is available
where python >nul 2>nul
if %errorlevel% equ 0 (
    echo Starting Python HTTP server on port 8080...
    python -m http.server 8080
) else (
    REM Try using PowerShell to create a simple server
    echo Starting PowerShell HTTP server on port 8080...
    powershell -ExecutionPolicy Bypass -Command "& { $listener = New-Object System.Net.HttpListener; $listener.Prefixes.Add('http://+:8080/'); $listener.Start(); Write-Host 'Server running on http://localhost:8080'; Write-Host 'Press Ctrl+C to stop'; while ($listener.IsListening) { $context = $listener.GetContext(); $request = $context.Request; $response = $context.Response; $path = if ($request.Url.LocalPath -eq '/') { '/index.html' } else { $request.Url.LocalPath }; $fullPath = Join-Path $pwd $path; if (Test-Path $fullPath) { $content = [System.IO.File]::ReadAllBytes($fullPath); $response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($fullPath); $response.ContentLength64 = $content.Length; $response.OutputStream.Write($content, 0, $content.Length); } else { $response.StatusCode = 404; } $response.Close(); } }"
)

pause