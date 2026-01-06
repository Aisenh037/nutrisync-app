# 🔥 Firebase Secrets Setup Script for NutriSync CI/CD (Windows PowerShell)
# This script helps you generate the required secrets for GitHub Actions

Write-Host "🔥 Firebase Secrets Setup for NutriSync CI/CD" -ForegroundColor Cyan
Write-Host "==============================================`n" -ForegroundColor Cyan

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version 2>$null
    Write-Host "✅ Firebase CLI found: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not found. Installing..." -ForegroundColor Red
    Write-Host "Run: npm install -g firebase-tools" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Check if user is logged in
try {
    $projects = firebase projects:list 2>$null
    Write-Host "✅ Firebase authentication verified" -ForegroundColor Green
} catch {
    Write-Host "🔐 Please login to Firebase first:" -ForegroundColor Yellow
    Write-Host "firebase login" -ForegroundColor Cyan
    Write-Host "`nThen run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# List available projects
Write-Host "📋 Available Firebase projects:" -ForegroundColor Cyan
firebase projects:list
Write-Host ""

# Get project ID
$PROJECT_ID = Read-Host "Enter your Firebase project ID (e.g., nutrisyncapp-97089)"

if ([string]::IsNullOrWhiteSpace($PROJECT_ID)) {
    Write-Host "❌ Project ID cannot be empty" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔧 Setting up secrets for project: $PROJECT_ID" -ForegroundColor Cyan
Write-Host ""

# Method 1: Generate CI Token
Write-Host "📝 Method 1: Generate Firebase CI Token" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Generating CI token..." -ForegroundColor Cyan

try {
    # Try to get existing token or generate new one
    Write-Host "Please follow the browser authentication flow..." -ForegroundColor Yellow
    Write-Host "After authentication, copy the token from the terminal output." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run this command manually:" -ForegroundColor Cyan
    Write-Host "firebase login:ci" -ForegroundColor White
    Write-Host ""
    Write-Host "Then copy the token (starts with '1//') to GitHub secrets as FIREBASE_TOKEN" -ForegroundColor Yellow
} catch {
    Write-Host "⚠️  Please run manually: firebase login:ci" -ForegroundColor Yellow
}

Write-Host ""

# Method 2: Service Account Instructions
Write-Host "📝 Method 2: Service Account (Alternative)" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "If the token method doesn't work, use service accounts:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to Firebase Console → Project Settings → Service Accounts" -ForegroundColor White
Write-Host "2. Click 'Generate new private key'" -ForegroundColor White
Write-Host "3. Download the JSON file" -ForegroundColor White
Write-Host "4. Convert to base64:" -ForegroundColor White
Write-Host "   certutil -encode service-account.json temp.b64" -ForegroundColor Cyan
Write-Host "   Get-Content temp.b64 | Where-Object { $_ -notmatch '^-' } | Out-String" -ForegroundColor Cyan
Write-Host "5. Add to GitHub as: FIREBASE_SERVICE_ACCOUNT_PROD" -ForegroundColor White
Write-Host ""

# GitHub repository info
Write-Host "🔗 GitHub Repository Setup" -ForegroundColor Yellow
Write-Host "==========================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Add secrets at: https://github.com/Aisenh037/nutrisync-app/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "Required secrets for web deployment:" -ForegroundColor White
Write-Host "- FIREBASE_TOKEN (from above) OR" -ForegroundColor Green
Write-Host "- FIREBASE_SERVICE_ACCOUNT_PROD (service account method)" -ForegroundColor Green
Write-Host ""

# Test deployment
Write-Host "🚀 Test Your Setup" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
Write-Host ""
Write-Host "After adding secrets, test deployment:" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Create a test branch and push" -ForegroundColor Gray
Write-Host "git checkout -b test-deployment" -ForegroundColor White
Write-Host "git commit --allow-empty -m 'test: trigger CI/CD pipeline'" -ForegroundColor White
Write-Host "git push origin test-deployment" -ForegroundColor White
Write-Host ""
Write-Host "# Or create a release" -ForegroundColor Gray
Write-Host "git tag -a v1.0.0 -m 'First release'" -ForegroundColor White
Write-Host "git push origin v1.0.0" -ForegroundColor White
Write-Host ""

Write-Host "✅ Setup complete! Check GitHub Actions for deployment status." -ForegroundColor Green
Write-Host "🌐 Your app will be live at: https://$PROJECT_ID.web.app" -ForegroundColor Cyan