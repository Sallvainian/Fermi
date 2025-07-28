# Scripts Directory

This directory contains various scripts for development, setup, and CI/CD workflows.

## Directory Structure

### `/dev`
Development scripts for running the project locally.
- `dev.bat` - Windows development script
- `dev.sh` - Unix/Linux development script

### `/setup`
Setup and configuration scripts.
- `setup-hooks.bat` - Windows Git hooks setup
- `setup-hooks.sh` - Unix/Linux Git hooks setup
- `fetch_secrets.ps1` - PowerShell script to fetch secrets
- `fetch_secrets.sh` - Shell script to fetch secrets
- `setup_secrets.ps1` - PowerShell script to setup secrets

### `/zep`
Zep Cloud integration scripts and configurations.
- `test_zep_cloud_mcp.py` - Zep Cloud MCP test script
- `zep_dev_context.py` - Zep development context script
- `zep_flutter_integration_example.py` - Flutter integration example
- `zep_cloud_config.py` - Zep Cloud configuration
- `zep_code_tracking_complete.md` - Zep code tracking documentation
- `README_ZEP_CLOUD.md` - Zep Cloud documentation

### `/ci`
CI/CD related scripts (currently empty, for future use).

### Root Scripts
- `generate-firebase-config.js` - Generates web/firebase-config.js from .env file
- `parse_inspection_errors.py` - Parse inspection errors

## Firebase Configuration for Web

When building for web, you need to generate the Firebase configuration file:

```bash
node scripts/generate-firebase-config.js
```

This script reads values from your `.env` file and creates `web/firebase-config.js` which is used by the Firebase service worker. Run this:
- Before building for web production
- After updating Firebase configuration in `.env`
- When setting up a new development environment

**Note:** The generated `web/firebase-config.js` file is gitignored and should not be committed.

## Usage

Refer to individual script files for specific usage instructions.