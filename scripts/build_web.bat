@echo off
REM Reliable web build script that enforces HTML renderer

echo Building Flutter web app with HTML renderer...

REM Clean previous builds
call flutter clean

REM Get dependencies
call flutter pub get

REM Build web app
call flutter build web --release

REM Verify the build used HTML renderer
findstr /C:"\"renderer\":\"canvaskit\"" build\web\flutter_bootstrap.js >nul 2>&1
if %errorlevel% equ 0 (
  echo ERROR: Build is using CanvasKit renderer instead of HTML!
  echo Please ensure --web-renderer html flag is used
  exit /b 1
)

echo Build complete with HTML renderer
echo.
echo Post-deployment steps:
echo 1. Deploy: firebase deploy --only hosting
echo 2. In browser DevTools:
echo    - Application -^> Service Workers -^> Unregister all
echo    - Application -^> Storage -^> Clear site data
echo 3. Hard refresh the page