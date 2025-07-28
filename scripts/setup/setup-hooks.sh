#!/bin/bash

echo "🔧 Setting up Git hooks with Husky..."

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Install npm dependencies
echo "📦 Installing npm dependencies..."
npm install

# Initialize husky
echo "🐶 Initializing Husky..."
npx husky install

# Make hooks executable
chmod +x .husky/pre-commit
chmod +x .husky/commit-msg
chmod +x .husky/pre-push

echo "✅ Git hooks setup complete!"
echo ""
echo "The following hooks are now active:"
echo "  - pre-commit: Runs linting and formatting checks"
echo "  - commit-msg: Validates commit message format"
echo "  - pre-push: Runs tests and security checks"
echo ""
echo "To bypass hooks in emergency (use sparingly):"
echo "  git commit --no-verify"
echo "  git push --no-verify"