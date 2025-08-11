#!/bin/bash

# PWA Local Build and Test Script
# This script builds the Flutter web app as a PWA and serves it locally

set -e  # Exit on error

echo "🚀 Building Flutter PWA for iOS Testing"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed. Please install Flutter first.${NC}"
    exit 1
fi

# Check Flutter version
echo -e "${YELLOW}📋 Flutter Version:${NC}"
flutter --version

# Clean previous builds
echo -e "\n${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "\n${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Build for web with PWA optimizations
echo -e "\n${YELLOW}🔨 Building PWA...${NC}"
flutter build web --release \
    --pwa-strategy=offline-first \
    --web-renderer=html \
    --no-tree-shake-icons

# Check if build was successful
if [ ! -d "build/web" ]; then
    echo -e "${RED}❌ Build failed. Please check the error messages above.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Enhance PWA manifest if needed
echo -e "\n${YELLOW}📝 Verifying PWA configuration...${NC}"

# Check if manifest.json exists
if [ -f "build/web/manifest.json" ]; then
    echo -e "${GREEN}✅ manifest.json found${NC}"
else
    echo -e "${RED}❌ manifest.json not found${NC}"
fi

# Check if service worker exists
if [ -f "build/web/flutter_service_worker.js" ]; then
    echo -e "${GREEN}✅ Service worker found${NC}"
else
    echo -e "${YELLOW}⚠️  Service worker not found - offline mode may not work${NC}"
fi

# Start local server
echo -e "\n${YELLOW}🌐 Starting local server...${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}📱 To test on iOS device:${NC}"
echo -e "${GREEN}1. Make sure your iOS device is on the same network${NC}"
echo -e "${GREEN}2. Find your computer's IP address:${NC}"

# Try to get local IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    LOCAL_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    LOCAL_IP=$(hostname -I | awk '{print $1}')
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    LOCAL_IP=$(ipconfig | grep -A 10 "Wireless LAN adapter Wi-Fi" | grep "IPv4" | awk '{print $NF}')
fi

if [ -z "$LOCAL_IP" ]; then
    echo -e "${YELLOW}   Run: ipconfig (Windows) or ifconfig (Mac/Linux)${NC}"
    echo -e "${GREEN}3. Open Safari on your iOS device${NC}"
    echo -e "${GREEN}4. Go to: http://YOUR_IP:8080${NC}"
else
    echo -e "${GREEN}   Your IP: ${LOCAL_IP}${NC}"
    echo -e "${GREEN}3. Open Safari on your iOS device${NC}"
    echo -e "${GREEN}4. Go to: http://${LOCAL_IP}:8080${NC}"
fi
echo -e "${GREEN}5. Tap Share → Add to Home Screen${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Serve the build
cd build/web

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Starting Python HTTP server on port 8080...${NC}"
    python3 -m http.server 8080
elif command -v python &> /dev/null; then
    # Try Python 2
    echo -e "${YELLOW}Starting Python HTTP server on port 8080...${NC}"
    python -m SimpleHTTPServer 8080
else
    echo -e "${RED}❌ Python is not installed. Please install Python to run the local server.${NC}"
    echo -e "${YELLOW}Alternatively, you can use any static file server in the build/web directory${NC}"
    exit 1
fi