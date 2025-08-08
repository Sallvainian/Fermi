@echo off
REM Wrapper to run the PowerShell setup for gcloud impersonation on Windows
setlocal
set "SCRIPT_DIR=%~dp0"

if not exist "%SCRIPT_DIR%setup-gcloud-impersonation.ps1" (
  echo [ERROR] Cannot find PowerShell script: %SCRIPT_DIR%setup-gcloud-impersonation.ps1
  echo.
  echo Press any key to close this window...
  pause >nul
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-gcloud-impersonation.ps1" %*
set "EC=%ERRORLEVEL%"

if %EC% EQU 0 (
  echo.
  echo [SUCCESS] gcloud impersonation setup finished successfully.
) else (
  echo.
  echo [ERROR] gcloud impersonation setup failed with exit code %EC%.
)

echo.
echo Press any key to close this window...
pause >nul

endlocal & exit /b %EC%
