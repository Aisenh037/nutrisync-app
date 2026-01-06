# 🚀 NutriSync Deployment Checklist

This is your complete guide to deploy NutriSync to Web, Android, and iOS platforms.

## 📋 Pre-Deployment Setup

### 1. Firebase Projects Setup
Create three Firebase projects for different environments:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init
```

**Required Firebase Projects:**
- `nutrisync-dev` (Development)
- `nutrisync-staging` (Staging) 
- `nutrisyncapp-97089` (Production - or your preferred name)

**Enable these Firebase services for each project:**
- ✅ Authentication (Email/Password, Google Sign-In)
- ✅ Firestore Database
- ✅ Cloud Storage
- ✅ Cloud Functions
- ✅ Firebase Hosting

### 2. GitHub Repository Setup
Push your code to GitHub and configure secrets:

**Required GitHub Secrets:**
```
# Firebase Secrets
FIREBASE_SERVICE_ACCOUNT_DEV=<base64-service-account-dev>
FIREBASE_SERVICE_ACCOUNT_STAGING=<base64-service-account-staging>
FIREBASE_SERVICE_ACCOUNT_PROD=<base64-service-account-prod>

# Android Secrets (for Play Store)
ANDROID_KEYSTORE=<base64-keystore-file>
ANDROID_KEYSTORE_PASSWORD=<your-keystore-password>
ANDROID_KEY_ALIAS=<your-key-alias>
ANDROID_KEY_PASSWORD=<your-key-password>
GOOGLE_PLAY_SERVICE_ACCOUNT=<base64-service-account>

# iOS Secrets (for App Store)
IOS_CERTIFICATE_BASE64=<base64-p12-certificate>
IOS_CERTIFICATE_PASSWORD=<certificate-password>
IOS_PROVISIONING_PROFILE_BASE64=<base64-mobileprovision>
IOS_TEAM_ID=<apple-team-id>
APPLE_ID=<apple-id-email>
APPLE_APP_SPECIFIC_PASSWORD=<app-specific-password>
KEYCHAIN_PASSWORD=<temporary-keychain-password>

# Optional: Notifications
SLACK_WEBHOOK_URL=<slack-webhook-url>
```

## 🌐 Web Deployment (Easiest - Start Here!)

### Option 1: Automatic Deployment (Recommended)
1. **Push to develop branch** for staging deployment:
   ```bash
   git checkout develop
   git add .
   git commit -m "Deploy to staging"
   git push origin develop
   ```

2. **Create a release** for production deployment:
   ```bash
   git checkout main
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```
   Or create release through GitHub UI.

### Option 2: Manual Deployment
```bash
# Build and deploy to Firebase
flutter build web --release
firebase deploy --only hosting --project nutrisyncapp-97089
```

**✅ Web deployment is complete when:**
- Your app is accessible at `https://nutrisyncapp-97089.web.app`
- All Firebase services are working
- Authentication and database are functional

## 📱 Android Deployment

### Step 1: Google Play Console Setup
1. Create a [Google Play Console](https://play.google.com/console) account ($25 one-time fee)
2. Create a new app in the console
3. Fill in app details, screenshots, and store listing

### Step 2: Generate Android Signing Key
```bash
# Generate keystore (one-time setup)
keytool -genkey -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nutrisync

# Create key.properties file
echo "storePassword=YOUR_KEYSTORE_PASSWORD" > android/key.properties
echo "keyPassword=YOUR_KEY_PASSWORD" >> android/key.properties
echo "keyAlias=nutrisync" >> android/key.properties
echo "storeFile=keystore.jks" >> android/key.properties
```

### Step 3: Build and Upload
**Option 1: Automatic (Recommended)**
```bash
# Create a release - Android will build automatically
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

**Option 2: Manual Build**
```bash
# Build App Bundle for Play Store
flutter build appbundle --release

# Upload the AAB file from build/app/outputs/bundle/release/ to Play Console
```

### Step 4: Play Store Submission
1. Upload AAB to Google Play Console
2. Fill in release notes
3. Submit for internal testing first
4. After testing, promote to production

## 🍎 iOS Deployment (Requires macOS)

### Step 1: Apple Developer Account Setup
1. Enroll in [Apple Developer Program](https://developer.apple.com) ($99/year)
2. Create App ID with bundle identifier: `com.example.nutrisync`
3. Generate distribution certificates and provisioning profiles

### Step 2: App Store Connect Setup
1. Create app in [App Store Connect](https://appstoreconnect.apple.com)
2. Fill in app metadata, screenshots, and descriptions
3. Set up TestFlight for beta testing

### Step 3: Build and Upload
**Option 1: Automatic (Recommended)**
```bash
# Create a release - iOS will build automatically
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

**Option 2: Manual Build (macOS only)**
```bash
# Build iOS app
./scripts/build_ios.sh -e production -t release -m app-store

# Upload to TestFlight
xcrun altool --upload-app --type ios --file "build/ios/NutriSync.ipa" --username "your@email.com" --password "app-specific-password"
```

### Step 4: TestFlight and App Store
1. Upload builds to TestFlight for beta testing
2. Test with internal and external testers
3. Submit for App Store review
4. Release to production after approval

## 🎯 Quick Start Deployment (Recommended Order)

### Phase 1: Web Deployment (Start Here)
1. ✅ Set up Firebase projects
2. ✅ Configure GitHub secrets for Firebase
3. ✅ Push to `develop` branch → Staging deployment
4. ✅ Create release tag → Production deployment
5. ✅ Test web app functionality

### Phase 2: Android Deployment
1. ✅ Set up Google Play Console account
2. ✅ Generate Android signing key
3. ✅ Configure Android GitHub secrets
4. ✅ Create release → Automatic Android build
5. ✅ Upload to Play Store and submit

### Phase 3: iOS Deployment (Requires macOS)
1. ✅ Set up Apple Developer account
2. ✅ Create certificates and provisioning profiles
3. ✅ Configure iOS GitHub secrets
4. ✅ Create release → Automatic iOS build
5. ✅ Upload to TestFlight and App Store

## 🔧 Configuration Files You Need

### Firebase Configuration
Copy and configure these files with your Firebase project details:
```
# Web
web/firebase-config.js

# Android
android/app/google-services.json

# iOS
ios/Runner/GoogleService-Info.plist
```

### Environment Configuration
Update these files with your specific settings:
```
assets/config/environments/development.json
assets/config/environments/staging.json
assets/config/environments/production.json
```

## 🚨 Common Issues & Solutions

### Web Deployment Issues
```bash
# If Firebase deployment fails
firebase login --reauth
firebase use nutrisyncapp-97089
firebase deploy --only hosting
```

### Android Build Issues
```bash
# Clean build if issues occur
flutter clean
cd android && ./gradlew clean && cd ..
flutter build appbundle --release
```

### iOS Build Issues (macOS)
```bash
# Clean iOS build
flutter clean
cd ios && xcodebuild clean -workspace Runner.xcworkspace -scheme Runner && cd ..
flutter build ios --release
```

## 📊 Monitoring Your Deployments

### Check Deployment Status
- **GitHub Actions**: Monitor workflow status in your repository's Actions tab
- **Firebase Console**: Check hosting, functions, and database status
- **Play Console**: Monitor Android app review and rollout status
- **App Store Connect**: Check iOS app review and TestFlight status

### Success Indicators
- ✅ Web app accessible and functional
- ✅ Android app uploaded to Play Store
- ✅ iOS app uploaded to TestFlight/App Store
- ✅ All Firebase services working
- ✅ User authentication functional
- ✅ Database operations working

## 🎉 You're Done!

Once all three platforms are deployed:
1. **Web**: Users can access your app at `https://nutrisyncapp-97089.web.app`
2. **Android**: Users can download from Google Play Store
3. **iOS**: Users can download from App Store

Your NutriSync app is now live on all platforms with automatic CI/CD deployment! 🚀

## 📞 Need Help?

If you encounter issues:
1. Check the detailed guides in `docs/DEPLOYMENT.md`
2. Review GitHub Actions logs for specific error messages
3. Run the security audit: `dart run scripts/security_audit.dart`
4. Validate your configuration: `flutter test test/integration/pipeline_validation_test.dart`