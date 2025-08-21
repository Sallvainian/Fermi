# CallKit Implementation & China Compliance

## Overview

This document describes the CallKit implementation in the Fermi app and how it handles China region compliance requirements.

## Implementation Architecture

### 1. Region Detection Layer

The app uses a multi-layered approach to detect if it's running in China:

```
┌─────────────────────────────────┐
│     Build Configuration         │ ← Compile-time flags
├─────────────────────────────────┤
│     Native iOS Detection        │ ← Runtime iOS checks
├─────────────────────────────────┤
│     Flutter Detection           │ ← Cross-platform checks
├─────────────────────────────────┤
│     Fallback Behavior           │ ← Safe defaults
└─────────────────────────────────┘
```

### 2. Detection Methods

#### Build-Time Configuration
- `FORCE_CHINA_MODE`: Forces China restrictions (for China-specific builds)
- `FORCE_ENABLE_CALLKIT`: Overrides restrictions (for testing only)
- `VERBOSE_REGION_LOGGING`: Enables detailed logging

#### Runtime Detection (iOS Native)
1. Locale region code check
2. Timezone identification  
3. App Store country detection
4. CallKit availability check (`CXProvider.isSupported()`)

#### Flutter Layer Detection
1. Platform locale check
2. Method channel communication with native layer
3. Cached results for performance

### 3. Feature Behavior by Region

| Feature | Non-China Regions | China Region |
|---------|------------------|--------------|
| CallKit UI | ✅ Enabled | ❌ Disabled |
| VoIP Push | ✅ Enabled | ❌ Disabled |
| PushKit | ✅ Registered | ❌ Not registered |
| Standard Push | Optional | ✅ Required |
| Call Notifications | Native UI | Standard alerts |

## Code Organization

### Flutter/Dart Files
```
lib/
├── shared/
│   ├── services/
│   │   └── region_detector_service.dart  # Main detection logic
│   └── config/
│       └── region_config.dart            # Configuration flags
└── features/
    └── notifications/
        └── data/services/
            ├── notification_service.dart  # Notification handling
            └── voip_token_service.dart   # VoIP token management
```

### iOS Native Files
```
ios/Runner/
└── AppDelegate.swift  # Native detection & CallKit management
```

### Documentation & Scripts
```
docs/
├── CHINA_COMPLIANCE.md        # Compliance documentation
├── CALLKIT_IMPLEMENTATION.md  # This file
scripts/
├── build_china.sh             # China-specific build
└── build_standard.sh          # Standard build
```

## Building for Different Regions

### Standard Build (Most Regions)
```bash
./scripts/build_standard.sh --ios --release
```
- Full CallKit support
- VoIP push notifications
- Native call UI

### China Build
```bash
./scripts/build_china.sh --ios --release
```
- CallKit disabled
- Standard push notifications only
- Compliant with MIIT requirements

### Testing Builds
```bash
# Force enable CallKit for testing
flutter build ios --dart-define=FORCE_ENABLE_CALLKIT=true

# Force China mode for testing
flutter build ios --dart-define=FORCE_CHINA_MODE=true

# Enable verbose logging
flutter build ios --dart-define=VERBOSE_REGION_LOGGING=true
```

## Testing Region Detection

### Unit Tests
```bash
flutter test test/region_detection_test.dart
```

### iOS Simulator Testing
```bash
# Set simulator to China region
xcrun simctl spawn booted defaults write -g AppleLocale "zh_CN"

# Reset simulator region
xcrun simctl spawn booted defaults delete -g AppleLocale
```

### Manual Testing Checklist

#### China Region Testing
- [ ] Set device/simulator to China region
- [ ] Verify CallKit is not initialized
- [ ] Verify incoming calls show as notifications
- [ ] Verify no VoIP token registration in logs
- [ ] Verify fallback notifications work

#### Non-China Region Testing  
- [ ] Set device to US/EU region
- [ ] Verify CallKit initializes
- [ ] Verify native call UI appears
- [ ] Verify VoIP push works
- [ ] Verify PushKit token is registered

## App Store Submission

### For Worldwide Release (Including China)

1. **Use China Build** for China App Store:
   ```bash
   ./scripts/build_china.sh --ios --release
   ```

2. **App Store Connect Settings**:
   - Select China as available territory
   - Note CallKit is disabled in build
   - Comply with MIIT requirements

3. **Metadata**:
   - Don't mention CallKit in China descriptions
   - Focus on messaging and collaboration features

### For Non-China Release Only

1. **Use Standard Build**:
   ```bash
   ./scripts/build_standard.sh --ios --release
   ```

2. **App Store Connect Settings**:
   - Exclude China from territories
   - Highlight CallKit features in description

## Troubleshooting

### CallKit Not Working
1. Check region detection: 
   ```dart
   final status = RegionDetectorService().getRegionStatus();
   print(status);
   ```

2. Verify iOS configuration:
   - Check `AppDelegate.swift` logs
   - Ensure PushKit certificates are valid

3. Test with force flags:
   ```bash
   flutter run --dart-define=FORCE_ENABLE_CALLKIT=true
   ```

### China Compliance Issues
1. Ensure CallKit is fully disabled:
   - No VoIP registration
   - No CallKit UI calls
   - No PushKit usage

2. Verify with China build:
   ```bash
   ./scripts/build_china.sh --ios --debug
   ```

3. Check logs for region detection:
   ```bash
   flutter run --dart-define=VERBOSE_REGION_LOGGING=true
   ```

## Maintenance

### Regular Tasks
- Test with each iOS update
- Monitor Apple guideline changes
- Update detection logic as needed
- Verify China compliance

### When Apple Guidelines Change
1. Review new requirements
2. Update detection logic if needed
3. Test thoroughly
4. Update documentation
5. Submit new build if required

## References

- [App Store Review Guidelines 5.0](https://developer.apple.com/app-store/review/guidelines/#legal)
- [CallKit Documentation](https://developer.apple.com/documentation/callkit)
- [China App Store Requirements](https://developer.apple.com/support/china/)
- [MIIT Regulations](http://www.miit.gov.cn/)