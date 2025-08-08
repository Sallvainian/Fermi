#!/bin/bash

# GitHub Secrets Setup Script for Teacher Dashboard Flutter Firebase
# Run this script to set up all required secrets for GitHub Actions

echo "🔧 Setting up GitHub Secrets for Teacher Dashboard Flutter Firebase"
echo "=================================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it first:"
    echo "   https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    echo "❌ Please authenticate with GitHub CLI first:"
    echo "   gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is ready"

# Read the .env file and set GitHub secrets
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please ensure you're in the project root directory."
    exit 1
fi

echo "📖 Reading configuration from .env file..."

# Function to set GitHub secret from env variable
set_secret() {
    local key=$1
    local value=$2
    
    if [ -n "$value" ]; then
        echo "Setting secret: $key"
        gh secret set "$key" --body "$value"
    else
        echo "⚠️  Warning: $key is empty, skipping..."
    fi
}

# Read .env file and extract values
source .env

echo "🔐 Setting Firebase configuration secrets..."
set_secret "FIREBASE_API_KEY" "$FIREBASE_API_KEY"
set_secret "FIREBASE_PROJECT_ID" "$FIREBASE_PROJECT_ID"
set_secret "FIREBASE_MESSAGING_SENDER_ID" "$FIREBASE_MESSAGING_SENDER_ID"
set_secret "FIREBASE_STORAGE_BUCKET" "$FIREBASE_STORAGE_BUCKET"
set_secret "FIREBASE_AUTH_DOMAIN" "$FIREBASE_AUTH_DOMAIN"
set_secret "FIREBASE_APP_ID_WEB" "$FIREBASE_APP_ID_WEB"
set_secret "FIREBASE_APP_ID_ANDROID" "$FIREBASE_APP_ID_ANDROID"
set_secret "FIREBASE_APP_ID_IOS" "$FIREBASE_APP_ID_IOS"
set_secret "IOS_BUNDLE_ID" "$IOS_BUNDLE_ID"
set_secret "GOOGLE_CLOUD_PROJECT" "$GOOGLE_CLOUD_PROJECT"
set_secret "FIREBASE_VAPID_KEY" "$FIREBASE_VAPID_KEY"

echo ""
echo "🚨 IMPORTANT: You need to manually set the FIREBASE_TOKEN secret"
echo "Run the following command to generate a Firebase CI token:"
echo "   firebase login:ci"
echo ""
echo "Then set it as a GitHub secret:"
echo "   gh secret set FIREBASE_TOKEN --body \"your-generated-token\""
echo ""

echo "✅ Basic secrets setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Generate Firebase CI token (see above)"
echo "2. Commit and push your changes to test the workflows"
echo "3. Check GitHub Actions tab for build status"
echo "4. For production: Set up Android signing keys (see .github/ENVIRONMENT_SETUP.md)"
echo ""
echo "🔍 To verify secrets are set correctly:"
echo "   gh secret list"