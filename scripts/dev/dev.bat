@echo off
setlocal enabledelayedexpansion

REM Flutter Development Helper Script
REM Usage: scripts\dev.bat [command]

REM Check command
if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="setup" goto setup
if "%1"=="clean" goto clean
if "%1"=="format" goto format
if "%1"=="analyze" goto analyze
if "%1"=="test" goto test
if "%1"=="coverage" goto coverage
if "%1"=="build" goto build
if "%1"=="run" goto run
if "%1"=="doctor" goto doctor
if "%1"=="upgrade" goto upgrade
if "%1"=="pre-commit" goto precommit

echo Unknown command: %1
goto help

:help
echo Flutter Development Helper
echo.
echo Usage: %0 [command]
echo.
echo Commands:
echo   setup       - Initial project setup
echo   clean       - Clean and rebuild project
echo   format      - Format all Dart files
echo   analyze     - Run static analysis
echo   test        - Run all tests
echo   coverage    - Generate test coverage report
echo   build       - Build for all platforms
echo   run         - Run on available devices
echo   doctor      - Check Flutter environment
echo   upgrade     - Upgrade dependencies
echo   pre-commit  - Run pre-commit checks
echo   help        - Show this help
goto end

:setup
echo Setting up Flutter project...

REM Check Flutter installation
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Flutter is not installed!
    exit /b 1
)

REM Get dependencies
echo Getting dependencies...
call flutter pub get

REM Setup git hooks
if exist "scripts\setup-hooks.bat" (
    echo Setting up Git hooks...
    call scripts\setup-hooks.bat
)

REM Create .env file if not exists
if not exist ".env" (
    echo Creating .env file...
    (
        echo # Environment variables for local development
        echo FIREBASE_PROJECT_ID=your-project-id
    ) > .env
    echo Please update .env file with your Firebase project ID
)

echo Project setup complete!
goto end

:clean
echo Cleaning project...
call flutter clean
call flutter pub get
echo Project cleaned!
goto end

:format
echo Formatting Dart code...
call dart format . --line-length=80
echo Code formatted!
goto end

:analyze
echo Analyzing code...
call flutter analyze --no-fatal-infos
echo Analysis complete!
goto end

:test
echo Running tests...
call flutter test
echo Tests complete!
goto end

:coverage
echo Generating test coverage...
call flutter test --coverage
echo Coverage data generated at coverage\lcov.info
goto end

:build
echo Building for all platforms...

echo Building Android APK...
call flutter build apk --release

echo Building Web...
call flutter build web --release

echo Building Windows...
call flutter build windows --release

echo Build complete!
goto end

:run
echo Checking available devices...
call flutter devices

echo.
set /p device_id="Enter device ID (or press Enter for default): "

if "%device_id%"=="" (
    call flutter run
) else (
    call flutter run -d %device_id%
)
goto end

:doctor
echo Checking Flutter environment...
call flutter doctor -v
goto end

:upgrade
echo Upgrading dependencies...
call flutter pub upgrade --major-versions
echo Dependencies upgraded!
goto end

:precommit
echo Running pre-commit checks...

echo Checking formatting...
call dart format . --set-exit-if-changed
if %errorlevel% neq 0 (
    echo Error: Code is not properly formatted!
    exit /b 1
)

echo Running analysis...
call flutter analyze --no-fatal-infos
if %errorlevel% neq 0 (
    echo Error: Analysis failed!
    exit /b 1
)

echo Running tests...
call flutter test
if %errorlevel% neq 0 (
    echo Error: Tests failed!
    exit /b 1
)

echo All pre-commit checks passed!
goto end

:end
endlocal