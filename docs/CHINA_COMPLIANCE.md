# China App Store Compliance - CallKit Restrictions

## Overview

This document describes the implementation of China region restrictions for CallKit functionality in the Fermi app, in compliance with App Store Guideline 5.0 and Chinese Ministry of Industry and Information Technology (MIIT) requirements.

## Requirements

Per App Store Guideline 5.0 - Legal:
- CallKit functionality must be deactivated for all apps available on the China App Store
- This is a mandatory requirement from the Chinese MIIT
- Apps that don't comply will be rejected from the China App Store

## Implementation

### 1. Region Detection Service

The app implements a comprehensive region detection system (`RegionDetectorService`) that:

- **Multiple Detection Methods**: Uses locale, timezone, and native platform checks
- **Safe Defaults**: Defaults to restricted mode if detection fails
- **Runtime Verification**: Checks if CallKit is actually available at runtime
- **Caching**: Caches detection results for performance

### 2. Detection Methods

#### Primary Detection (iOS Native)
- Locale region code check (CN, CHN, HK, HKG, MO, MAC, TW, TWN)
- Timezone identification (Asia/Shanghai, Asia/Beijing, etc.)
- App Store country detection
- Runtime CallKit availability check using `CXProvider.isSupported()`

#### Flutter Layer Detection
- Platform dispatcher locale check
- Timezone offset analysis
- Native platform channel communication
- Fallback to standard notifications when restricted

### 3. Affected Features

When in China region:
- **Disabled**: CallKit native call UI
- **Disabled**: VoIP push notifications
- **Disabled**: PushKit registration
- **Enabled**: Standard push notifications as fallback
- **Enabled**: Local notifications for call alerts

### 4. Fallback Behavior

When CallKit is restricted:
- Incoming calls use standard push notifications
- Call notifications show as high-priority alerts
- Users can still accept/decline calls through notification actions
- App maintains full calling functionality without native call UI

## Code Structure

### Flutter Components
- `/lib/shared/services/region_detector_service.dart` - Main region detection logic
- `/lib/features/notifications/data/services/notification_service.dart` - Notification handling with fallbacks
- `/lib/features/notifications/data/services/voip_token_service.dart` - VoIP token management with restrictions

### iOS Native Components
- `/ios/Runner/AppDelegate.swift` - Native region detection and CallKit management
- Method channels for Flutter-native communication
- Runtime CallKit availability checks

## Testing

### Test Scenarios

1. **China Region Device**
   - Set device region to China (CN)
   - Verify CallKit is disabled
   - Verify standard notifications work
   - Verify no VoIP token registration

2. **Non-China Region Device**
   - Set device region to US/EU/other
   - Verify CallKit is enabled
   - Verify VoIP push works
   - Verify native call UI appears

3. **Region Change**
   - Start in non-China region
   - Change to China region
   - Verify CallKit disables dynamically
   - Verify fallback activates

### Testing Commands

```bash
# Test with China region simulation (iOS Simulator)
xcrun simctl spawn booted defaults write -g AppleLocale "zh_CN"
xcrun simctl spawn booted defaults write -g AppleLanguages '("zh-Hans")'

# Reset to default region
xcrun simctl spawn booted defaults delete -g AppleLocale
xcrun simctl spawn booted defaults delete -g AppleLanguages
```

## Server-Side Considerations

The backend should:
1. Store user region information
2. Send regular push notifications (not VoIP) for China users
3. Include region detection in user analytics
4. Handle both CallKit and non-CallKit call flows

## Compliance Checklist

- [x] CallKit disabled for China regions (CN, HK, MO, TW)
- [x] VoIP push notifications disabled in China
- [x] Fallback to standard notifications implemented
- [x] Runtime detection of CallKit availability
- [x] Multiple detection methods for reliability
- [x] Safe defaults (restrict when uncertain)
- [x] No CallKit UI shown in China
- [x] App remains functional without CallKit

## App Store Connect Configuration

When submitting to App Store:

1. **Export Compliance**
   - Mark app as using encryption (HTTPS/TLS)
   - Exempt from export regulations (using standard encryption)

2. **China Availability**
   - App can be made available in China
   - CallKit automatically disabled by region detection

3. **App Description**
   - Note that calling features adapt to local regulations
   - Don't mention CallKit in China-facing descriptions

## Maintenance

### Regular Reviews
- Monitor Apple's guidelines for changes
- Test with each iOS update
- Verify detection methods remain accurate
- Update fallback mechanisms as needed

### Known Limitations
- Detection may not be 100% accurate for VPN users
- Travelers may experience changed functionality
- Some edge cases (Hong Kong, Macau) may need special handling

## References

- [App Store Review Guidelines - 5.0 Legal](https://developer.apple.com/app-store/review/guidelines/#legal)
- [CallKit Framework Documentation](https://developer.apple.com/documentation/callkit)
- [China App Store Requirements](https://developer.apple.com/support/china/)
- [MIIT Regulations](http://www.miit.gov.cn/)