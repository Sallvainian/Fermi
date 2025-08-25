# Windows Release Guide

## Overview
This guide covers the Windows release process for the Fermi education platform, including building, packaging, and distributing the application.

## Release Formats

### 1. Portable ZIP
- **What**: Standalone executable with all dependencies
- **Use Case**: Users who want to run without installation
- **Size**: ~100-150 MB
- **Pros**: No admin rights needed, portable
- **Cons**: No Start Menu integration, manual updates

### 2. Installer (Inno Setup)
- **What**: Traditional Windows installer
- **Use Case**: Standard desktop installation
- **Size**: ~80-120 MB (compressed)
- **Pros**: Start Menu shortcuts, uninstaller, automatic file associations
- **Cons**: Requires admin rights for Program Files installation

### 3. MSIX Package
- **What**: Modern Windows app package
- **Use Case**: Microsoft Store or enterprise deployment
- **Size**: ~100-150 MB
- **Pros**: Auto-updates, sandboxed, Store distribution
- **Cons**: Windows 10 1809+ only, sideloading restrictions

## Automated Release Process

### Triggering a Release

#### Option 1: Git Tag
```bash
# Create and push a version tag
git tag -a windows-v1.0.0 -m "Windows Release 1.0.0"
git push origin windows-v1.0.0

# Or use a general version tag (triggers all platforms)
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

#### Option 2: Manual Workflow
1. Go to Actions tab in GitHub
2. Select "Windows Release" workflow
3. Click "Run workflow"
4. Enter version number and release notes
5. Click "Run workflow"

### What Happens Automatically
1. Builds Windows desktop app
2. Creates three packages (ZIP, Installer, MSIX)
3. Uploads artifacts to GitHub
4. Creates GitHub Release with all packages
5. Publishes release with download links

## Local Building

### Prerequisites
```bash
# Install Flutter
flutter channel stable
flutter upgrade

# Verify Windows desktop support
flutter doctor
flutter config --enable-windows-desktop
```

### Build Commands

#### Standard Build
```bash
# Debug build
flutter build windows --debug

# Release build
flutter build windows --release

# With version info
flutter build windows --release --build-name=1.0.0 --build-number=1
```

#### Create Portable ZIP
```powershell
# After building
cd build\windows\x64\runner\Release
Compress-Archive -Path * -DestinationPath "..\..\..\..\Fermi-Portable.zip"
```

#### Create MSIX Package
```bash
# Install MSIX tool
flutter pub global activate msix

# Create MSIX
flutter pub run msix:create
```

## Code Signing (Future)

### Why Sign?
- Removes SmartScreen warnings
- Establishes publisher trust
- Required for Microsoft Store
- Better enterprise deployment

### Certificate Options

#### 1. Self-Signed (Development)
```powershell
# Create self-signed certificate
New-SelfSignedCertificate -Type CodeSigningCert `
  -Subject "CN=Fermi Education Dev" `
  -KeyExportPolicy Exportable `
  -KeySpec Signature `
  -KeyLength 2048 `
  -KeyAlgorithm RSA `
  -HashAlgorithm SHA256 `
  -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
  -CertStoreLocation Cert:\CurrentUser\My

# Sign executable
signtool sign /fd SHA256 /a fermi.exe
```

#### 2. EV Certificate (Production)
- **Cost**: $200-500/year
- **Providers**: DigiCert, Sectigo, GlobalSign
- **Benefits**: Instant SmartScreen reputation
- **Process**: 
  1. Purchase EV certificate
  2. Store in GitHub Secrets
  3. Add signing step to workflow

### Adding Signing to CI/CD

Add to `.github/workflows/04_windows_release.yml`:

```yaml
- name: Sign Windows Executable
  if: env.WINDOWS_CERTIFICATE != ''
  env:
    WINDOWS_CERTIFICATE: ${{ secrets.WINDOWS_CERTIFICATE }}
    WINDOWS_CERTIFICATE_PASSWORD: ${{ secrets.WINDOWS_CERTIFICATE_PASSWORD }}
  shell: pwsh
  run: |
    # Decode certificate from base64
    $cert = [System.Convert]::FromBase64String($env:WINDOWS_CERTIFICATE)
    $certPath = "cert.pfx"
    [System.IO.File]::WriteAllBytes($certPath, $cert)
    
    # Sign all executables
    & "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" `
      sign /f $certPath /p $env:WINDOWS_CERTIFICATE_PASSWORD `
      /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
      build\windows\x64\runner\Release\fermi.exe
    
    Remove-Item $certPath
```

## GitHub Secrets Required

### Firebase Configuration
- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_DATABASE_URL`
- `FIREBASE_APP_ID_WINDOWS`
- `FIREBASE_VAPID_KEY`

### Optional (for signing)
- `WINDOWS_CERTIFICATE` - Base64 encoded .pfx file
- `WINDOWS_CERTIFICATE_PASSWORD` - Certificate password

## Distribution Channels

### 1. GitHub Releases
- **Automatic**: Created by CI/CD
- **URL**: https://github.com/Sallvainian/Fermi/releases
- **Best for**: Direct downloads, power users

### 2. Microsoft Store (Future)
Requirements:
- MSIX package ✅
- Code signing certificate
- Microsoft Partner Center account
- Store listing assets

Process:
1. Sign up for Microsoft Partner Center ($19 one-time)
2. Create app listing
3. Upload MSIX package
4. Submit for review

### 3. Website Download
- Host installer on project website
- Use CDN for better download speeds
- Provide hash verification

### 4. Winget (Future)
```yaml
# winget-manifests submission
PackageIdentifier: Fermi.Education
PackageVersion: 1.0.0
DefaultLocale: en-US
ManifestType: singleton
ManifestVersion: 1.0.0
```

## Testing Release Builds

### Local Testing
```bash
# Run release build locally
flutter run -d windows --release

# Test installer in VM
# 1. Build installer
# 2. Copy to Windows VM
# 3. Test installation process
# 4. Verify shortcuts and uninstaller
```

### Test Checklist
- [ ] App launches successfully
- [ ] Google Sign-In works
- [ ] Apple Sign-In works  
- [ ] File upload/download works
- [ ] Notifications appear
- [ ] Offline mode functions
- [ ] Updates can be installed
- [ ] Uninstaller removes all files

## Troubleshooting

### Common Issues

#### 1. SmartScreen Warning
**Problem**: "Windows protected your PC" warning
**Solution**: Sign executable with EV certificate

#### 2. Missing Visual C++ Runtime
**Problem**: App won't start, missing DLL errors
**Solution**: Bundle Visual C++ redistributables or use static linking

#### 3. Firewall Blocking
**Problem**: Network features don't work
**Solution**: Add firewall exception during installation

#### 4. High DPI Issues
**Problem**: Blurry text on high DPI displays
**Solution**: Already handled by Flutter, verify manifest settings

### Debug Commands
```powershell
# Check certificate
signtool verify /pa fermi.exe

# Check dependencies
dumpbin /dependents fermi.exe

# Event log errors
Get-EventLog -LogName Application -Newest 10 | Where {$_.Source -like "*Fermi*"}
```

## Version Management

### Semantic Versioning
- **Format**: MAJOR.MINOR.PATCH
- **Example**: 1.2.3
- **Windows Build**: Add fourth number for builds (1.2.3.456)

### Update pubspec.yaml
```yaml
version: 1.0.0+1  # version+build
```

### Update Windows Runner
Edit `windows/runner/Runner.rc`:
```rc
#define VERSION_AS_NUMBER 1,0,0,0
#define VERSION_AS_STRING "1.0.0"
```

## Release Notes Template

```markdown
## Fermi Windows v1.0.0

### ✨ New Features
- Feature 1
- Feature 2

### 🐛 Bug Fixes
- Fix 1
- Fix 2

### 🔧 Improvements
- Improvement 1
- Improvement 2

### 📦 Installation
- **Installer**: Recommended for most users
- **Portable**: No installation needed
- **MSIX**: For Microsoft Store

### 🖥️ System Requirements
- Windows 10 1809 or later
- 200 MB disk space
```

## Security Considerations

1. **Code Signing**: Plan to implement EV certificate signing
2. **Auto-Updates**: Implement secure update mechanism
3. **Secrets Management**: Never commit sensitive data
4. **Network Security**: All API calls use HTTPS
5. **Local Storage**: Encrypt sensitive local data

## Future Enhancements

1. **Auto-updater**: Implement Sparkle or similar
2. **Microsoft Store**: Submit MSIX package
3. **Winget**: Submit to Windows Package Manager
4. **Chocolatey**: Create Chocolatey package
5. **Silent Install**: Add silent install options
6. **Group Policy**: Enterprise deployment templates
7. **ARM64 Support**: Build for Windows on ARM