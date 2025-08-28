#!/bin/bash

# Fix CocoaPods for Flutter build by ensuring correct Ruby environment
echo "Setting up correct Ruby environment for CocoaPods..."

# Use Homebrew's Ruby and CocoaPods
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
export GEM_HOME="/opt/homebrew/lib/ruby/gems/3.4.0"
export GEM_PATH="/opt/homebrew/lib/ruby/gems/3.4.0"

# Navigate to macos directory
cd "$(dirname "$0")"

# Clean and reinstall pods
echo "Cleaning pods..."
rm -rf Pods
rm -f Podfile.lock

echo "Installing pods with Homebrew's CocoaPods..."
/opt/homebrew/bin/pod install --repo-update

echo "Pod installation complete!"