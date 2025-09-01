#!/bin/bash

# Fix CocoaPods installation issues for iOS build
set -e

echo "=== Fixing CocoaPods Installation ==="

# Navigate to ios directory
cd "$(dirname "$0")"

# Clean existing installations
echo "Cleaning existing pod installations..."
rm -rf Pods
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clean CocoaPods cache
echo "Cleaning CocoaPods cache..."
pod cache clean --all 2>/dev/null || true

# Deintegrate pods from project
echo "Deintegrating pods from project..."
pod deintegrate 2>/dev/null || true

# Update CocoaPods repo
echo "Updating CocoaPods repository..."
pod repo update

# Install pods with verbose output
echo "Installing pods..."
pod install --repo-update --verbose

# Verify installation
if [ -d "Pods" ]; then
    echo "✓ Pods directory created successfully"
    echo "Installed pods:"
    ls -1 Pods/ | head -20
else
    echo "✗ Pod installation failed"
    exit 1
fi

echo "=== Pod Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Run: flutter clean"
echo "2. Run: flutter pub get"
echo "3. Run: flutter build ios --release --no-codesign"