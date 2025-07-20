# GitHub Actions iOS Build Workflows

This directory contains GitHub Actions workflows for building the Flutter iOS app with modern Xcode versions.

## Available Workflows

### 1. iOS Build (`ios-build.yml`)
- **Trigger**: Push to main/develop or pull requests
- **Purpose**: Basic CI/CD build for iOS
- **Features**:
  - Builds iOS app without code signing
  - Uploads build artifacts
  - Runs on latest macOS/Xcode

### 2. iOS Development Build (`ios-development.yml`)
- **Trigger**: Manual (workflow_dispatch)
- **Purpose**: Development builds with options
- **Features**:
  - Choose Flutter version
  - Choose Xcode version
  - Select build type (debug/profile/release)
  - Detailed logging
  - Workspace archiving for debugging

### 3. iOS Compatibility Test (`ios-compatibility-test.yml`)
- **Trigger**: Manual or weekly schedule
- **Purpose**: Test compatibility across Xcode versions
- **Features**:
  - Tests multiple Xcode versions (14.0 - latest)
  - Creates compatibility reports
  - Identifies which Xcode versions work

## Usage

### Running a Basic Build
1. Push to `main` or `develop` branch
2. Or go to Actions tab → iOS Build → Run workflow

### Running a Development Build
1. Go to Actions tab → iOS Development Build
2. Click "Run workflow"
3. Select options:
   - Flutter version (default: 3.24.0)
   - Xcode version (default: latest)
   - Build type (debug/profile/release)

### Testing Xcode Compatibility
1. Go to Actions tab → iOS Compatibility Test
2. Click "Run workflow"
3. Check artifacts for compatibility reports

## Viewing Results

- **Build artifacts**: Available in Actions → Select run → Artifacts
- **Logs**: Click on any job to see detailed logs
- **Build status**: Shown in PR checks and Actions tab

## Costs

- **Public repo**: Unlimited free minutes
- **Private repo**: 2,000 minutes/month (200 actual macOS minutes)
- **macOS runners**: Use 10x multiplier for minutes

## Tips

1. Use `workflow_dispatch` for development to save minutes
2. Download artifacts to debug build issues locally
3. Use compatibility test to find working Xcode versions
4. Cancel long-running builds to save minutes