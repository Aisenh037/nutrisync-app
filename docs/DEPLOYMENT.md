# Deployment Guide

This guide covers deploying NutriSync to various platforms using the automated CI/CD pipeline.

## 🌐 Web Deployment (Firebase Hosting)

### Automatic Deployment

Web deployment happens automatically through GitHub Actions:

- **Staging**: Deploys on push to `develop` branch
- **Production**: Deploys on release creation

### Manual Deployment

```bash
# Build the web app
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting

# Deploy to specific project
firebase deploy --only hosting --project your-project-id
```

### Environment Configuration

Web deployments use environment-specific Firebase projects:

- **Development**: `nutrisync-dev`
- **Staging**: `nutrisync-staging`
- **Production**: `nutrisync-prod`

## 📱 Android Deployment (Google Play Store)

### Automatic Deployment

Android deployment is triggered by:

1. **Release Creation**: Automatically deploys to internal testing
2. **Manual Workflow**: Use GitHub Actions workflow dispatch

### Manual Deployment Steps

1. **Prepare Signing**:
   ```bash
   # Generate keystore (one-time setup)
   keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nutrisync
   
   # Create key.properties
   cp config/secrets/key.properties.example android/key.properties
   # Fill in your actual values
   ```

2. **Build Release**:
   ```bash
   # Build App Bundle (recommended)
   flutter build appbundle --release
   
   # Build APK
   flutter build apk --release
   ```

3. **Upload to Play Console**:
   - Go to [Google Play Console](https://play.google.com/console)
   - Upload the AAB file from `build/app/outputs/bundle/release/`
   - Fill in release notes and submit for review

### Play Store Tracks

- **Internal**: For team testing (automatic from CI/CD)
- **Alpha**: For closed testing with specific users
- **Beta**: For open testing with larger audience
- **Production**: For public release

## 🍎 iOS Deployment (App Store)

### Automatic Deployment

iOS deployment is triggered by:

1. **Release Creation**: Automatically builds and uploads to TestFlight
2. **Manual Workflow**: Use GitHub Actions workflow dispatch with environment selection

### Prerequisites

- macOS with Xcode 15.0+
- iOS Developer Account ($99/year)
- App Store Connect access
- Valid certificates and provisioning profiles

### Setup iOS Certificates

1. **Create App ID**:
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Create App ID with bundle identifier: `com.example.nutrisync`
   - Enable required capabilities (Push Notifications, etc.)

2. **Generate Certificates**:
   ```bash
   # Create certificate signing request
   # Use Keychain Access > Certificate Assistant > Request Certificate from CA
   
   # Download and install distribution certificate
   # Double-click to install in Keychain
   ```

3. **Create Provisioning Profiles**:
   - Create App Store provisioning profile
   - Download and install in Xcode

### Manual Deployment Steps

1. **Build iOS App**:
   ```bash
   # Using the build script (recommended)
   ./scripts/build_ios.sh -e production -t release -m app-store
   
   # Manual build
   flutter build ios --release --no-codesign
   cd ios
   xcodebuild -workspace Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     -destination generic/platform=iOS \
     -archivePath ../build/ios/NutriSync.xcarchive \
     archive
   ```

2. **Export IPA**:
   ```bash
   # Export for App Store
   xcodebuild -exportArchive \
     -archivePath build/ios/NutriSync.xcarchive \
     -exportOptionsPlist ios/ExportOptions.plist \
     -exportPath build/ios/
   ```

3. **Upload to App Store Connect**:
   ```bash
   # Using altool (command line)
   xcrun altool --upload-app \
     --type ios \
     --file "build/ios/NutriSync.ipa" \
     --username "your@email.com" \
     --password "app-specific-password"
   
   # Or use Xcode Organizer
   # Window > Organizer > Archives > Upload to App Store
   ```

### iOS Environment Configuration

The iOS build supports multiple environments with different bundle identifiers:

- **Development**: `com.example.nutrisync.dev`
- **Staging**: `com.example.nutrisync.staging`
- **Production**: `com.example.nutrisync`

Each environment uses its own:
- Firebase configuration (`GoogleService-Info.plist`)
- Bundle identifier
- App name and display settings
- Build configuration

### TestFlight Beta Testing

1. **Upload to TestFlight**:
   - Automatic via CI/CD on release creation
   - Manual upload via Xcode or altool

2. **Configure Beta Testing**:
   - Add internal testers (up to 100)
   - Add external testers (up to 10,000)
   - Set up beta app review if needed

3. **Distribute to Testers**:
   - Send invitations via email
   - Testers install TestFlight app
   - Download and test your app

### App Store Submission

1. **Prepare App Store Listing**:
   - App name, description, keywords
   - Screenshots for all device sizes
   - App icon (1024x1024)
   - Privacy policy URL

2. **Submit for Review**:
   - Upload build via TestFlight
   - Complete App Store Connect listing
   - Submit for App Store review
   - Respond to review feedback if needed

3. **Release Management**:
   - Choose manual or automatic release
   - Set release date if scheduled
   - Monitor app performance post-launch

## 🔧 Firebase Functions Deployment

### Automatic Deployment

Functions deploy automatically with web deployment.

### Manual Deployment

```bash
cd functions

# Install dependencies
npm install

# Deploy functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:functionName
```

### Environment Variables

Set environment variables for functions:

```bash
# Set config
firebase functions:config:set api.key="your-api-key"

# Get config
firebase functions:config:get

# Deploy with new config
firebase deploy --only functions
```

## 🗄️ Database Deployment

### Firestore Rules and Indexes

```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes

# Deploy both
firebase deploy --only firestore
```

### Data Seeding

After deploying functions, seed the database:

```bash
# Call the seeding function (requires admin authentication)
curl -X POST https://your-region-your-project.cloudfunctions.net/initializeDatabase \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json"
```

## 🔐 Secrets Management

### GitHub Secrets

Configure these secrets in your GitHub repository:

#### Firebase Secrets
```
FIREBASE_SERVICE_ACCOUNT_DEV=<base64-encoded-service-account>
FIREBASE_SERVICE_ACCOUNT_STAGING=<base64-encoded-service-account>
FIREBASE_SERVICE_ACCOUNT_PROD=<base64-encoded-service-account>
FIREBASE_TOKEN=<firebase-ci-token>
```

#### Android Secrets
```
ANDROID_KEYSTORE=<base64-encoded-keystore-file>
ANDROID_KEYSTORE_PASSWORD=<keystore-password>
ANDROID_KEY_ALIAS=<key-alias>
ANDROID_KEY_PASSWORD=<key-password>
GOOGLE_PLAY_SERVICE_ACCOUNT=<base64-encoded-service-account>
```

#### iOS Secrets
```
IOS_CERTIFICATE_BASE64=<base64-encoded-p12-certificate>
IOS_CERTIFICATE_PASSWORD=<certificate-password>
IOS_PROVISIONING_PROFILE_BASE64=<base64-encoded-mobileprovision>
IOS_TEAM_ID=<apple-team-id>
APPLE_ID=<apple-id-email>
APPLE_APP_SPECIFIC_PASSWORD=<app-specific-password>
KEYCHAIN_PASSWORD=<temporary-keychain-password>
```

#### Notification Secrets
```
SLACK_WEBHOOK_URL=<slack-webhook-url>
```

### Encoding Files for Secrets

```bash
# Encode keystore for GitHub secrets
base64 -i keystore.jks | pbcopy

# Encode service account JSON
base64 -i service-account.json | pbcopy

# Encode iOS certificate (P12 format)
base64 -i certificate.p12 | pbcopy

# Encode iOS provisioning profile
base64 -i profile.mobileprovision | pbcopy
```

## 🚀 Release Process

### Creating a Release

1. **Prepare Release**:
   - Update version in `pubspec.yaml`
   - Update `CHANGELOG.md`
   - Ensure all tests pass
   - Update documentation if needed

2. **Create Release**:
   ```bash
   # Create and push tag
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   
   # Or create release through GitHub UI
   ```

3. **Monitor Deployment**:
   - Check GitHub Actions for deployment status
   - Verify web deployment at staging/production URLs
   - Check Play Console for Android upload status

### Version Management

Version format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes
- **BUILD**: Build number (auto-incremented by CI/CD)

Example: `1.2.3+45`

## 🔍 Monitoring and Troubleshooting

### Deployment Status

- **GitHub Actions**: Check workflow status in Actions tab
- **Firebase Console**: Monitor hosting and functions
- **Play Console**: Check app review status

### Common Issues

#### Web Deployment Failures
```bash
# Check Firebase project access
firebase projects:list

# Verify hosting configuration
firebase hosting:sites:list

# Check build output
flutter build web --verbose
```

#### Android Build Failures
```bash
# Clean build
flutter clean
cd android && ./gradlew clean && cd ..

# Check signing configuration
cd android && ./gradlew signingReport

# Verbose build
flutter build appbundle --verbose
```

#### iOS Build Failures
```bash
# Clean build
flutter clean
cd ios && xcodebuild clean -workspace Runner.xcworkspace -scheme Runner && cd ..

# Check certificates and provisioning profiles
security find-identity -v -p codesigning

# Check Xcode project settings
open ios/Runner.xcworkspace

# Verbose build
flutter build ios --verbose
```

#### Functions Deployment Issues
```bash
# Check functions logs
firebase functions:log

# Test functions locally
cd functions && npm run serve

# Check TypeScript compilation
cd functions && npm run build
```

### Rollback Procedures

#### Web Rollback
```bash
# List hosting releases
firebase hosting:releases:list

# Rollback to previous version
firebase hosting:rollback
```

#### Android Rollback
- Use Play Console to halt rollout
- Increase rollout percentage of previous version
- Or upload new version with fixes

#### iOS Rollback
- Use App Store Connect to remove from sale
- Submit previous version for expedited review
- Or submit hotfix version with critical fixes

#### Functions Rollback
```bash
# Deploy previous version from git
git checkout previous-tag
firebase deploy --only functions
```

## 📊 Performance Monitoring

### Web Performance
- Firebase Performance Monitoring
- Google Analytics
- Lighthouse CI in GitHub Actions

### Android Performance
- Firebase Performance Monitoring
- Play Console vitals
- Crashlytics for error tracking

### iOS Performance
- Firebase Performance Monitoring
- App Store Connect analytics
- Xcode Organizer crash reports
- TestFlight feedback and metrics

### Functions Performance
- Firebase Functions logs and metrics
- Cloud Monitoring dashboards
- Error reporting through Crashlytics

## 🔄 Environment Promotion

### Development → Staging
1. Merge feature branch to `develop`
2. Automatic deployment to staging
3. Test in staging environment
4. Verify all functionality works

### Staging → Production
1. Create release from `develop` branch
2. Automatic deployment to production
3. Monitor deployment metrics
4. Verify production functionality

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] All tests pass locally
- [ ] Code review completed
- [ ] Version updated in pubspec.yaml
- [ ] Release notes prepared
- [ ] Environment configurations verified

### Post-Deployment
- [ ] Web app accessible and functional
- [ ] Android app uploaded to Play Store
- [ ] iOS app uploaded to TestFlight/App Store
- [ ] Firebase Functions responding correctly
- [ ] Database rules and indexes deployed
- [ ] Monitoring and alerts configured
- [ ] Team notified of deployment

### Production Release
- [ ] Staging deployment successful
- [ ] User acceptance testing completed
- [ ] Performance metrics acceptable
- [ ] Security scan passed
- [ ] Rollback plan prepared
- [ ] Support team notified