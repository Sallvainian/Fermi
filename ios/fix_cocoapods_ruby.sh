#!/bin/bash

# Fix CocoaPods Ruby issues on macOS
set -e

echo "=== Fixing CocoaPods Ruby Issues ==="

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew is required. Please install from https://brew.sh"
    exit 1
fi

echo "Installing/updating Ruby via Homebrew..."
brew install ruby 2>/dev/null || brew upgrade ruby

# Add Ruby to PATH
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

echo "Installing CocoaPods with gem..."
gem install cocoapods --user-install

# Add gem bin directory to PATH
export PATH="$HOME/.gem/ruby/3.0.0/bin:$PATH"

# Verify installation
echo "Verifying CocoaPods installation..."
which pod
pod --version

echo "=== CocoaPods Fixed ==="
echo ""
echo "Add the following to your ~/.zshrc or ~/.bash_profile:"
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"'
echo 'export PATH="$HOME/.gem/ruby/3.0.0/bin:$PATH"'