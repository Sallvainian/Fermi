# Web Deployment Guide

Complete guide for deploying the Fermi Flutter web application to Firebase Hosting and other platforms.

## Firebase Hosting Deployment

### Prerequisites
- Firebase CLI installed and configured
- Flutter web build working locally
- Firebase project with Hosting enabled
- Proper environment variables configured

### Initial Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting
firebase init hosting
```

### Configuration Files

#### `firebase.json`
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "/index.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "no-cache"
          }
        ]
      }
    ]
  }
}
```

#### `.firebaserc`
```json
{
  "projects": {
    "default": "fermi-education",
    "staging": "fermi-education-staging",
    "production": "fermi-education-prod"
  }
}
```

### Build Script

#### `build-for-web.sh`
```bash
#!/bin/bash
set -e

echo "Building Fermi for Web Deployment..."

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build for web with release mode
flutter build web --release \
  --web-renderer html \
  --tree-shake-icons \
  --dart-define=ENVIRONMENT=production

# Copy custom files if needed
cp web/manifest.json build/web/
cp -r web/icons build/web/

echo "Web build completed successfully!"
```

### Deployment Commands
```bash
# Build the application
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting

# Deploy to specific project
firebase deploy --only hosting --project production

# Deploy with message
firebase deploy --only hosting -m "Release v1.2.3"
```

### Environment Configuration

#### Production Environment Variables
```dart
// lib/config/web_config.dart
class WebConfig {
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'your-production-api-key',
  );
  
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID', 
    defaultValue: 'fermi-education',
  );
  
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: 'your-sender-id',
  );
}
```

#### `web/index.html` Configuration
```html
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Fermi Education Platform">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Fermi">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>Fermi - Education Management Platform</title>
  <link rel="manifest" href="manifest.json">

  <!-- Firebase Configuration -->
  <script type="module">
    import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js';
    import { getAnalytics } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-analytics.js';
    
    const firebaseConfig = {
      apiKey: "your-api-key",
      authDomain: "fermi-education.firebaseapp.com",
      projectId: "fermi-education",
      storageBucket: "fermi-education.appspot.com",
      messagingSenderId: "sender-id",
      appId: "app-id",
      measurementId: "measurement-id"
    };
    
    const app = initializeApp(firebaseConfig);
    const analytics = getAnalytics(app);
  </script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        }
      }).then(function(engineInitializer) {
        return engineInitializer.initializeEngine();
      }).then(function(appRunner) {
        return appRunner.runApp();
      });
    });
  </script>
</body>
</html>
```

## Progressive Web App (PWA) Configuration

### `web/manifest.json`
```json
{
  "name": "Fermi Education Platform",
  "short_name": "Fermi",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "Comprehensive education management platform for teachers and students",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

### Service Worker Configuration
```javascript
// web/sw.js
const CACHE_NAME = 'fermi-v1.0.0';
const urlsToCache = [
  '/',
  '/main.dart.js',
  '/flutter_service_worker.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/manifest.json'
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        return cache.addAll(urlsToCache);
      })
  );
});

self.addEventListener('fetch', function(event) {
  event.respondWith(
    caches.match(event.request)
      .then(function(response) {
        if (response) {
          return response;
        }
        return fetch(event.request);
      }
    )
  );
});
```

## Alternative Deployment Platforms

### Netlify Deployment
```bash
# Build for web
flutter build web --release

# Install Netlify CLI
npm install -g netlify-cli

# Deploy to Netlify
netlify deploy --prod --dir=build/web
```

#### `netlify.toml`
```toml
[build]
  command = "flutter build web --release"
  publish = "build/web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[build.environment]
  FLUTTER_WEB_USE_SKIA = "true"
```

### Vercel Deployment
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy to Vercel
vercel --prod
```

#### `vercel.json`
```json
{
  "builds": [
    {
      "src": "pubspec.yaml",
      "use": "@vercel/static-build"
    }
  ],
  "routes": [
    {
      "handle": "filesystem"
    },
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ],
  "buildCommand": "flutter build web --release"
}
```

### GitHub Pages Deployment
```bash
# Build for web with base href
flutter build web --release --base-href="/fermi/"

# Deploy using gh-pages
npm install -g gh-pages
gh-pages -d build/web
```

## Performance Optimization

### Build Optimizations
```bash
# Optimized production build
flutter build web --release \
  --web-renderer html \
  --tree-shake-icons \
  --source-maps \
  --split-debug-info=debug_symbols
```

### Asset Optimization
```dart
// pubspec.yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
  
  # Image compression
  uses-material-design: true
  generate: true
```

### Code Splitting
```dart
// lib/main.dart
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lazy load heavy dependencies
  await loadCriticalDependencies();
  
  runApp(MyApp());
}

Future<void> loadCriticalDependencies() async {
  // Load Firebase
  await Firebase.initializeApp();
  
  // Preload critical routes
  await precacheRoutes();
}
```

## Monitoring and Analytics

### Firebase Analytics Integration
```dart
// lib/services/analytics_service.dart
class AnalyticsService {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  
  static Future<void> logPageView(String pageName) async {
    await analytics.logEvent(
      name: 'page_view',
      parameters: {'page_name': pageName},
    );
  }
  
  static Future<void> logFeatureUsage(String feature) async {
    await analytics.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': feature},
    );
  }
}
```

### Performance Monitoring
```dart
// lib/services/performance_service.dart
class PerformanceService {
  static Future<void> trackLoadTime(String screenName) async {
    final trace = FirebasePerformance.instance.newTrace('screen_load_$screenName');
    await trace.start();
    
    // Screen loading logic
    
    await trace.stop();
  }
}
```

## Security Configuration

### Content Security Policy
```html
<!-- Add to web/index.html -->
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self' https://fermi-education.firebaseapp.com; 
               script-src 'self' 'unsafe-inline' https://www.gstatic.com; 
               style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;">
```

### HTTPS Configuration
```json
// firebase.json
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "Strict-Transport-Security",
            "value": "max-age=31536000; includeSubDomains"
          },
          {
            "key": "X-Content-Type-Options",
            "value": "nosniff"
          },
          {
            "key": "X-Frame-Options",
            "value": "DENY"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

### Common Build Issues
```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Clear web cache
rm -rf build/web
rm -rf .dart_tool

# Rebuild
flutter build web --release
```

### Firebase Hosting Issues
```bash
# Check Firebase status
firebase projects:list

# Re-authenticate
firebase logout
firebase login

# Check hosting configuration
firebase hosting:sites:list
```

### Performance Issues
- Enable web renderer optimization: `--web-renderer html`
- Use tree shaking: `--tree-shake-icons`
- Optimize images and assets
- Implement lazy loading for routes
- Use service worker caching

### Browser Compatibility
- Test on Chrome, Firefox, Safari, Edge
- Use proper polyfills for older browsers
- Handle web-specific features gracefully
- Provide fallbacks for unsupported features

## CI/CD Integration

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build web
        run: flutter build web --release
        
      - name: Deploy to Firebase
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only hosting
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

[content placeholder]