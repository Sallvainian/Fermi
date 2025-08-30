#!/bin/bash

# iOS Rebuild Script for Fermi Flutter App
# This script cleans and rebuilds the iOS app with fresh dependencies

echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🍎 Installing iOS CocoaPods..."
cd ios && pod install

echo "🚀 Running app on iOS..."
cd ..
flutter run -d ios

echo "✅ Done!"