#!/bin/bash

# 🔥 Firebase Secrets Setup Script for NutriSync CI/CD
# This script helps you generate the required secrets for GitHub Actions

echo "🔥 Firebase Secrets Setup for NutriSync CI/CD"
echo "=============================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    echo "Run: npm install -g firebase-tools"
    echo "Then run this script again."
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Please login to Firebase first:"
    echo "firebase login"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ Firebase authentication verified"
echo ""

# List available projects
echo "📋 Available Firebase projects:"
firebase projects:list
echo ""

# Get project ID
read -p "Enter your Firebase project ID (e.g., nutrisyncapp-97089): " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID cannot be empty"
    exit 1
fi

echo ""
echo "🔧 Setting up secrets for project: $PROJECT_ID"
echo ""

# Method 1: Generate CI Token
echo "📝 Method 1: Generate Firebase CI Token"
echo "======================================="
echo ""
echo "Generating CI token..."

TOKEN=$(firebase login:ci --no-localhost 2>/dev/null | grep -o '1//[^[:space:]]*' | head -1)

if [ -n "$TOKEN" ]; then
    echo "✅ Firebase CI Token generated successfully!"
    echo ""
    echo "🔐 Add this secret to GitHub:"
    echo "Secret Name: FIREBASE_TOKEN"
    echo "Secret Value: $TOKEN"
    echo ""
else
    echo "⚠️  Could not generate token automatically."
    echo "Please run manually: firebase login:ci"
    echo "Then copy the token to GitHub secrets as FIREBASE_TOKEN"
    echo ""
fi

# Method 2: Service Account Instructions
echo "📝 Method 2: Service Account (Alternative)"
echo "=========================================="
echo ""
echo "If the token method doesn't work, use service accounts:"
echo ""
echo "1. Go to Firebase Console → Project Settings → Service Accounts"
echo "2. Click 'Generate new private key'"
echo "3. Download the JSON file"
echo "4. Convert to base64:"
echo "   - Linux/Mac: cat service-account.json | base64 -w 0"
echo "   - Windows: certutil -encode service-account.json temp.b64 && findstr /v /c:- temp.b64"
echo "5. Add to GitHub as: FIREBASE_SERVICE_ACCOUNT_PROD"
echo ""

# GitHub repository info
echo "🔗 GitHub Repository Setup"
echo "=========================="
echo ""
echo "Add secrets at: https://github.com/Aisenh037/nutrisync-app/settings/secrets/actions"
echo ""
echo "Required secrets for web deployment:"
echo "- FIREBASE_TOKEN (from above) OR"
echo "- FIREBASE_SERVICE_ACCOUNT_PROD (service account method)"
echo ""

# Test deployment
echo "🚀 Test Your Setup"
echo "=================="
echo ""
echo "After adding secrets, test deployment:"
echo ""
echo "# Create a test branch and push"
echo "git checkout -b test-deployment"
echo "git commit --allow-empty -m 'test: trigger CI/CD pipeline'"
echo "git push origin test-deployment"
echo ""
echo "# Or create a release"
echo "git tag -a v1.0.0 -m 'First release'"
echo "git push origin v1.0.0"
echo ""

echo "✅ Setup complete! Check GitHub Actions for deployment status."
echo "🌐 Your app will be live at: https://$PROJECT_ID.web.app"