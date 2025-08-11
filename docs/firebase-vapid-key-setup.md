# Firebase VAPID Key Setup Guide

## What is a VAPID Key?

The VAPID (Voluntary Application Server Identification) key is required for Firebase Cloud Messaging (FCM) to work on web platforms. It's used for web push notifications and is a public key that identifies your application server to web push services.

## How to Get Your VAPID Key

1. **Open Firebase Console**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `teacher-dashboard-flutterfire`

2. **Navigate to Project Settings**
   - Click the gear icon (⚙️) in the left sidebar
   - Select "Project settings"

3. **Go to Cloud Messaging Tab**
   - Click on the "Cloud Messaging" tab
   - Scroll down to "Web configuration" section

4. **Find Web Push Certificates**
   - Look for "Web Push certificates" section
   - You'll see a field labeled "Key pair" or "Voluntary Application Server Identification"

5. **Generate or Copy the Key**
   - If no key exists, click "Generate key pair"
   - Once generated, copy the long string (starts with something like `BK...`)
   - This is your VAPID key

## How to Set the VAPID Key

### Option 1: Set as GitHub Secret (Recommended for CI/CD)

```bash
# Set the VAPID key as a GitHub secret
gh secret set FIREBASE_VAPID_KEY
# Then paste your VAPID key when prompted
```

### Option 2: Set in Local Environment (For Local Development)

#### Windows (Command Prompt)
```cmd
set FIREBASE_VAPID_KEY=your_vapid_key_here
flutter run
```

#### Windows (PowerShell)
```powershell
$env:FIREBASE_VAPID_KEY="your_vapid_key_here"
flutter run
```

#### Linux/Mac
```bash
export FIREBASE_VAPID_KEY="your_vapid_key_here"
flutter run
```

### Option 3: Add to .env File (Local Development Only)

Create a `.env` file in your project root:
```env
FIREBASE_VAPID_KEY=your_vapid_key_here
```

**Note**: Never commit the `.env` file to version control!

### Option 4: Pass as Build Argument

```bash
flutter run --dart-define=FIREBASE_VAPID_KEY=your_vapid_key_here
```

Or for web builds:
```bash
flutter build web --dart-define=FIREBASE_VAPID_KEY=your_vapid_key_here
```

## Update Your Code (Already Done)

The code in `firebase_messaging_service.dart` is already set up to use the VAPID key:

```dart
// Web requires VAPID key
const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
if (vapidKey.isEmpty) {
  LoggerService.error('FIREBASE_VAPID_KEY not found in environment variables');
  // Fallback to try without VAPID key (development only)
  currentToken = await _messaging.getToken();
} else {
  // Use VAPID key for web FCM token generation
  currentToken = await _messaging.getToken(vapidKey: vapidKey);
}
```

## Why This Error Occurs

The error "FIREBASE_VAPID_KEY not found in environment variable" occurs because:
1. The app is trying to initialize Firebase Cloud Messaging for web
2. Web FCM requires a VAPID key for security
3. The key is not set in your environment variables or GitHub secrets

## Impact of Missing VAPID Key

- **Web Platform**: Push notifications won't work properly on web
- **Mobile Platforms**: No impact - Android and iOS don't use VAPID keys
- **Development**: You can still develop without it, but will see warning messages

## Security Notes

- The VAPID key is a **public** key, not a secret
- It's safe to include in client-side code
- However, it's better to inject it at build time for flexibility
- Different environments (dev/staging/prod) might use different keys

## Verification

After setting the VAPID key, verify it works:

1. Run the app on web: `flutter run -d chrome`
2. Check browser console for FCM token generation
3. No more "VAPID_KEY not found" errors should appear
4. Test push notifications on web platform

## Additional Resources

- [Firebase Cloud Messaging for Web](https://firebase.google.com/docs/cloud-messaging/js/client)
- [Web Push Protocol](https://developers.google.com/web/fundamentals/push-notifications/web-push-protocol)
- [VAPID Specification](https://datatracker.ietf.org/doc/html/rfc8292)