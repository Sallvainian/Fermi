#!/bin/bash

# Script to add GitHub secrets for Firebase deployment using GitHub CLI
# Run this script to configure all required secrets

echo ""
echo "====================================="
echo "📝 Adding GitHub Secrets for PWA Deployment"
echo "====================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not authenticated.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is ready!${NC}"
echo ""

# Firebase configuration values from firebase_options.dart
echo "🔐 Adding Firebase configuration secrets..."
echo ""

# Add Firebase configuration secrets
gh secret set FIREBASE_API_KEY --body="AIzaSyD_nLVRdyd6ZlIyFrRGCW5IStXnM2-uUac"
echo -e "${GREEN}✅ Added FIREBASE_API_KEY${NC}"

gh secret set FIREBASE_PROJECT_ID --body="teacher-dashboard-flutterfire"
echo -e "${GREEN}✅ Added FIREBASE_PROJECT_ID${NC}"

gh secret set FIREBASE_MESSAGING_SENDER_ID --body="218352465432"
echo -e "${GREEN}✅ Added FIREBASE_MESSAGING_SENDER_ID${NC}"

gh secret set FIREBASE_STORAGE_BUCKET --body="teacher-dashboard-flutterfire.firebasestorage.app"
echo -e "${GREEN}✅ Added FIREBASE_STORAGE_BUCKET${NC}"

gh secret set FIREBASE_DATABASE_URL --body="https://teacher-dashboard-flutterfire-default-rtdb.firebaseio.com"
echo -e "${GREEN}✅ Added FIREBASE_DATABASE_URL${NC}"

gh secret set FIREBASE_APP_ID_WEB --body="1:218352465432:web:6e1c0fa4f21416df38b56d"
echo -e "${GREEN}✅ Added FIREBASE_APP_ID_WEB${NC}"

gh secret set FIREBASE_APP_ID_IOS --body="1:218352465432:ios:5lt4mte28dqof4ae3igmi6m8i261jh99"
echo -e "${GREEN}✅ Added FIREBASE_APP_ID_IOS${NC}"

gh secret set IOS_BUNDLE_ID --body="com.teacherdashboard.teacherDashboardFlutter"
echo -e "${GREEN}✅ Added IOS_BUNDLE_ID${NC}"

echo ""
echo "====================================="
echo -e "${YELLOW}⚠️  IMPORTANT: Service Account Setup${NC}"
echo "====================================="
echo ""
echo "You need to manually add the Firebase service account:"
echo ""
echo "1. Go to Firebase Console:"
echo "   https://console.firebase.google.com/project/teacher-dashboard-flutterfire/settings/serviceaccounts/adminsdk"
echo ""
echo "2. Click 'Generate new private key'"
echo ""
echo "3. Download the JSON file"
echo ""
echo "4. Run this command with the path to your JSON file:"
echo "   gh secret set FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE < path/to/your/service-account.json"
echo ""
echo "   Example:"
echo "   gh secret set FIREBASE_SERVICE_ACCOUNT_TEACHER_DASHBOARD_FLUTTERFIRE < ~/Downloads/teacher-dashboard-firebase-adminsdk.json"
echo ""
echo "====================================="
echo ""

# List all secrets to verify
echo "📋 Current GitHub Secrets:"
echo ""
gh secret list

echo ""
echo "====================================="
echo -e "${GREEN}✅ Basic secrets added successfully!${NC}"
echo ""
echo "📌 Next steps:"
echo "1. Add the service account secret (see instructions above)"
echo "2. Push your code to trigger deployment:"
echo "   git push origin main"
echo "3. Check deployment at:"
echo "   https://github.com/Sallvainian/teacher-dashboard-flutter-firebase/actions"
echo "====================================="
echo ""