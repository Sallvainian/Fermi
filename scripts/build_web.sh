#!/bin/bash
# Reliable web build script that enforces HTML renderer

echo "🔨 Building Flutter web app with HTML renderer..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build with HTML renderer (REQUIRED - do not change)
flutter build web --release --web-renderer html

# Verify the build used HTML renderer
if grep -q '"renderer":"canvaskit"' build/web/flutter_bootstrap.js 2>/dev/null; then
  echo "❌ ERROR: Build is using CanvasKit renderer instead of HTML!"
  echo "Please ensure --web-renderer html flag is used"
  exit 1
fi

echo "✅ Build complete with HTML renderer"
echo ""
echo "📝 Post-deployment steps:"
echo "1. Deploy: firebase deploy --only hosting"
echo "2. In browser DevTools:"
echo "   - Application → Service Workers → Unregister all"
echo "   - Application → Storage → Clear site data"
echo "3. Hard refresh the page"