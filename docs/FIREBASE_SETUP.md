# Firebase Multi-Environment Setup Guide

This guide explains how to set up multiple Firebase environments (development, staging, production) for the NutriSync application.

## Overview

NutriSync uses three separate Firebase projects to ensure proper isolation between environments:

- **Development**: `nutrisync-dev` - For local development and testing
- **Staging**: `nutrisync-staging` - For pre-production testing and QA
- **Production**: `nutrisyncapp-97089` - For live production deployment

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Google Cloud account with billing enabled (for Cloud Functions)
- Access to create Firebase projects

## Step 1: Create Firebase Projects

### 1.1 Development Environment

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Project name: `NutriSync Development`
4. Project ID: `nutrisync-dev`
5. Enable Google Analytics (optional for development)

### 1.2 Staging Environment

1. Create another project
2. Project name: `NutriSync Staging`
3. Project ID: `nutrisync-staging`
4. Enable Google Analytics

### 1.3 Production Environment

1. Create production project
2. Project name: `NutriSync`
3. Project ID: `nutrisyncapp-97089` (or your preferred ID)
4. Enable Google Analytics

## Step 2: Configure Firebase Services

For each environment, enable and configure the following services:

### 2.1 Authentication

1. Go to Authentication > Sign-in method
2. Enable Email/Password authentication
3. Enable Google Sign-In
   - Add your domain to authorized domains
   - Configure OAuth consent screen

### 2.2 Firestore Database

1. Go to Firestore Database
2. Create database in production mode
3. Choose a location (preferably close to your users)
4. Deploy security rules (see Step 4)

### 2.3 Cloud Storage

1. Go to Storage
2. Get started with default bucket
3. Deploy storage rules (see Step 4)

### 2.4 Cloud Functions

1. Go to Functions
2. Upgrade to Blaze plan (required for Cloud Functions)
3. Functions will be deployed via CI/CD

### 2.5 Hosting

1. Go to Hosting
2. Get started
3. Note the hosting URL for each environment

## Step 3: Configure Project Settings

### 3.1 Web App Configuration

For each project:

1. Go to Project Settings
2. Add a web app
3. App nickname: `NutriSync Web`
4. Enable Firebase Hosting
5. Copy the configuration object

### 3.2 Android App Configuration

For each project:

1. Add an Android app
2. Package name:
   - Development: `com.example.nutrisync.dev`
   - Staging: `com.example.nutrisync.staging`
   - Production: `com.example.nutrisync`
3. Download `google-services.json`

### 3.3 iOS App Configuration (Future)

For each project:

1. Add an iOS app
2. Bundle ID:
   - Development: `com.example.nutrisync.dev`
   - Staging: `com.example.nutrisync.staging`
   - Production: `com.example.nutrisync`
3. Download `GoogleService-Info.plist`

## Step 4: Deploy Security Rules

### 4.1 Firestore Rules

Deploy the security rules to each environment:

```bash
# Development
firebase deploy --only firestore:rules --project nutrisync-dev

# Staging
firebase deploy --only firestore:rules --project nutrisync-staging

# Production
firebase deploy --only firestore:rules --project nutrisyncapp-97089
```

### 4.2 Storage Rules

Deploy storage rules:

```bash
# Development
firebase deploy --only storage --project nutrisync-dev

# Staging
firebase deploy --only storage --project nutrisync-staging

# Production
firebase deploy --only storage --project nutrisyncapp-97089
```

### 4.3 Firestore Indexes

Deploy database indexes:

```bash
# Development
firebase deploy --only firestore:indexes --project nutrisync-dev

# Staging
firebase deploy --only firestore:indexes --project nutrisync-staging

# Production
firebase deploy --only firestore:indexes --project nutrisyncapp-97089
```

## Step 5: Service Account Setup

### 5.1 Create Service Accounts

For each environment, create a service account for CI/CD:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to IAM & Admin > Service Accounts
4. Create Service Account:
   - Name: `nutrisync-cicd`
   - Description: `Service account for CI/CD deployment`
5. Grant roles:
   - Firebase Admin
   - Cloud Functions Admin
   - Storage Admin
   - Firestore Service Agent

### 5.2 Generate Service Account Keys

1. Click on the created service account
2. Go to Keys tab
3. Add Key > Create new key
4. Choose JSON format
5. Download and securely store the key file

### 5.3 Configure GitHub Secrets

Add the service account keys as GitHub repository secrets:

```bash
# Base64 encode the service account files
base64 -i nutrisync-dev-service-account.json | pbcopy
base64 -i nutrisync-staging-service-account.json | pbcopy
base64 -i nutrisync-prod-service-account.json | pbcopy
```

Add these as GitHub secrets:
- `FIREBASE_SERVICE_ACCOUNT_DEV`
- `FIREBASE_SERVICE_ACCOUNT_STAGING`
- `FIREBASE_SERVICE_ACCOUNT_PROD`

## Step 6: Environment Configuration

### 6.1 Update Configuration Files

Update the environment configuration files with your actual Firebase project details:

**assets/config/environments/development.json**:
```json
{
  "firebase": {
    "projectId": "nutrisync-dev",
    "apiKey": "your-dev-api-key",
    "authDomain": "nutrisync-dev.firebaseapp.com",
    "storageBucket": "nutrisync-dev.appspot.com",
    "messagingSenderId": "your-dev-sender-id",
    "appId": "your-dev-app-id"
  }
}
```

**assets/config/environments/staging.json**:
```json
{
  "firebase": {
    "projectId": "nutrisync-staging",
    "apiKey": "your-staging-api-key",
    "authDomain": "nutrisync-staging.firebaseapp.com",
    "storageBucket": "nutrisync-staging.appspot.com",
    "messagingSenderId": "your-staging-sender-id",
    "appId": "your-staging-app-id"
  }
}
```

**assets/config/environments/production.json**:
```json
{
  "firebase": {
    "projectId": "nutrisyncapp-97089",
    "apiKey": "your-prod-api-key",
    "authDomain": "nutrisyncapp-97089.firebaseapp.com",
    "storageBucket": "nutrisyncapp-97089.appspot.com",
    "messagingSenderId": "your-prod-sender-id",
    "appId": "your-prod-app-id"
  }
}
```

### 6.2 Update Firebase Configuration

Update `.firebaserc` with all project aliases:

```json
{
  "projects": {
    "default": "nutrisyncapp-97089",
    "development": "nutrisync-dev",
    "staging": "nutrisync-staging",
    "production": "nutrisyncapp-97089"
  }
}
```

## Step 7: Data Seeding

### 7.1 Seed Development Data

For development environment, seed with test data:

```bash
# Deploy functions first
firebase deploy --only functions --project nutrisync-dev

# Call seeding function
curl -X POST https://us-central1-nutrisync-dev.cloudfunctions.net/seedIndianFoods \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json"
```

### 7.2 Seed Production Data

For production, seed with real data:

```bash
# Deploy functions
firebase deploy --only functions --project nutrisyncapp-97089

# Seed production data (be careful!)
curl -X POST https://us-central1-nutrisyncapp-97089.cloudfunctions.net/seedIndianFoods \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json"
```

## Step 8: Testing Multi-Environment Setup

### 8.1 Local Development

Test with development environment:

```bash
# Set environment
export ENVIRONMENT=development

# Run app
flutter run -d chrome --dart-define=ENVIRONMENT=development
```

### 8.2 Staging Deployment

Test staging deployment:

```bash
# Push to develop branch (triggers staging deployment)
git checkout develop
git push origin develop

# Check deployment status in GitHub Actions
```

### 8.3 Production Deployment

Test production deployment:

```bash
# Create release (triggers production deployment)
git tag v1.0.0
git push origin v1.0.0

# Or create release through GitHub UI
```

## Step 9: Monitoring and Maintenance

### 9.1 Set Up Monitoring

For each environment:

1. Enable Firebase Performance Monitoring
2. Set up Crashlytics
3. Configure Analytics
4. Set up alerting rules

### 9.2 Regular Maintenance

- Monitor usage and costs
- Update security rules as needed
- Review and rotate service account keys
- Monitor performance metrics
- Update Firebase SDK versions

## Troubleshooting

### Common Issues

1. **Permission Denied**: Check service account roles and permissions
2. **Project Not Found**: Verify project IDs in configuration files
3. **Quota Exceeded**: Check Firebase usage limits and upgrade plan if needed
4. **CORS Issues**: Add your domains to Firebase authorized domains

### Useful Commands

```bash
# List Firebase projects
firebase projects:list

# Switch project
firebase use nutrisync-dev

# Check current project
firebase projects:list --filter="CURRENT"

# Deploy specific services
firebase deploy --only hosting,functions --project nutrisync-staging

# View logs
firebase functions:log --project nutrisync-prod
```

## Security Best Practices

1. **Never commit service account keys** to version control
2. **Use least privilege principle** for service accounts
3. **Regularly rotate keys** and credentials
4. **Monitor access logs** for suspicious activity
5. **Keep Firebase SDK updated** to latest versions
6. **Use environment-specific domains** for CORS configuration
7. **Enable audit logging** for production environment

## Cost Optimization

1. **Use Spark plan** for development (free tier)
2. **Monitor usage** regularly through Firebase console
3. **Set up billing alerts** to avoid unexpected charges
4. **Optimize Firestore queries** to reduce read/write operations
5. **Use Cloud Functions efficiently** to minimize execution time
6. **Implement proper caching** to reduce API calls

---

This multi-environment setup ensures proper isolation between development, staging, and production while maintaining consistency across all environments.