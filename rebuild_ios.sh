#!/bin/bash

# iOS Rebuild Script for Fermi Flutter App
# This script cleans and rebuilds the iOS app with fresh dependencies

echo "🧹 Cleaning Flutter project..."
cd apps/fermi && flutter clean

echo "📦 Getting Flutter dependencies..."
cd apps/fermi && flutter pub get

echo "🍎 Installing iOS CocoaPods..."
cd apps/fermi/ios && pod install

echo "✅ Done!"
