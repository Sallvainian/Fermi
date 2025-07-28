@echo off

echo Setting up Git hooks with Husky...

REM Check if npm is installed
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: npm is not installed. Please install Node.js and npm first.
    exit /b 1
)

REM Install npm dependencies
echo Installing npm dependencies...
call npm install

REM Initialize husky
echo Initializing Husky...
call npx husky install

echo Git hooks setup complete!
echo.
echo The following hooks are now active:
echo   - pre-commit: Runs linting and formatting checks
echo   - commit-msg: Validates commit message format
echo   - pre-push: Runs tests and security checks
echo.
echo To bypass hooks in emergency (use sparingly):
echo   git commit --no-verify
echo   git push --no-verify

pause