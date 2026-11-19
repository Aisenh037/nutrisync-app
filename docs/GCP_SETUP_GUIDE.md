# Google Cloud Platform Setup Guide for NutriSync

This guide walks you through setting up Google Cloud Platform (GCP) services for the NutriSync AI enhancement features.

## Prerequisites

1. **Google Cloud CLI**: Install from [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)
2. **Google Cloud Account**: With billing enabled
3. **Project Access**: Owner or Editor permissions on the GCP project

## Quick Setup

### Option 1: Automated Setup (Recommended)

Run the setup script for your platform:

**Windows (PowerShell):**
```powershell
.\scripts\setup_gcp.ps1
```

**Linux/macOS (Bash):**
```bash
./scripts/setup_gcp.sh
```

The script will:
- Enable required APIs
- Create service accounts
- Set up IAM permissions
- Generate service account keys
- Update environment configurations

### Option 2: Manual Setup

If you prefer to set up manually or need custom configuration:

#### 1. Create GCP Project

```bash
# Set your project ID
export PROJECT_ID="nutrisync-gcp-dev"

# Create project (if it doesn't exist)
gcloud projects create $PROJECT_ID

# Set as active project
gcloud config set project $PROJECT_ID
```

#### 2. Enable Required APIs

```bash
# Enable all required APIs
gcloud services enable \
  speech.googleapis.com \
  texttospeech.googleapis.com \
  vision.googleapis.com \
  translate.googleapis.com \
  dialogflow.googleapis.com \
  maps-backend.googleapis.com \
  places-backend.googleapis.com \
  run.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com
```

#### 3. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create nutrisync-ai-service \
  --display-name="NutriSync AI Service Account" \
  --description="Service account for NutriSync AI services"

# Get service account email
export SERVICE_ACCOUNT_EMAIL="nutrisync-ai-service@$PROJECT_ID.iam.gserviceaccount.com"
```

#### 4. Grant IAM Roles

```bash
# Grant required roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/speech.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/texttospeech.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/vision.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/translate.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/dialogflow.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/maps.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/places.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/run.invoker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/cloudfunctions.invoker"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/monitoring.viewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/logging.viewer"
```

#### 5. Create Service Account Key

```bash
# Create and download service account key
gcloud iam service-accounts keys create assets/config/gcp/service-account-development.json \
  --iam-account=$SERVICE_ACCOUNT_EMAIL
```

## Environment Configuration

### Development Environment

Update `assets/config/environments/development.json`:

```json
{
  "gcp": {
    "projectId": "your-gcp-project-id",
    "region": "us-central1",
    "apis": {
      "speechToText": {
        "enabled": true,
        "languageCode": "en-US",
        "model": "latest_long",
        "useEnhanced": true
      },
      "textToSpeech": {
        "enabled": true,
        "languageCode": "en-US",
        "voiceName": "en-US-Neural2-F",
        "audioEncoding": "MP3"
      },
      "vision": {
        "enabled": true,
        "features": ["OBJECT_LOCALIZATION", "TEXT_DETECTION", "LABEL_DETECTION"],
        "maxResults": 10
      },
      "translation": {
        "enabled": true,
        "defaultTargetLanguage": "en",
        "supportedLanguages": ["en", "es", "fr", "de", "it", "pt", "hi", "zh"]
      },
      "dialogflow": {
        "enabled": true,
        "agentId": "nutrisync-agent-dev",
        "sessionTimeout": 300
      },
      "maps": {
        "enabled": true,
        "defaultRadius": 5000,
        "maxResults": 20
      },
      "places": {
        "enabled": true,
        "types": ["grocery_or_supermarket", "health", "restaurant"],
        "maxResults": 20
      }
    }
  }
}
```

### Service Account Key Placement

Place your service account keys in the correct location:

```
assets/config/gcp/
├── service-account-development.json     # Development environment
├── service-account-staging.json        # Staging environment
└── service-account-production.json     # Production environment
```

## Security Best Practices

### 1. Service Account Keys

- **Never commit service account keys to version control**
- Use environment variables or secret management in production
- Rotate keys regularly
- Use least privilege principle for IAM roles

### 2. API Keys

- Restrict API keys to specific services and domains
- Use separate keys for different environments
- Monitor API usage and set up billing alerts

### 3. Network Security

- Use VPC networks for Cloud Run services
- Implement proper firewall rules
- Use Cloud Armor for DDoS protection

## Testing the Setup

### 1. Verify Configuration

```dart
// In your Flutter app
import 'package:nutrisync/config/gcp_config.dart';

void testGCPConfig() async {
  await GCPConfig.instance.initialize();
  
  print('Project ID: ${GCPConfig.instance.projectId}');
  print('Region: ${GCPConfig.instance.region}');
  print('Enabled APIs: ${GCPConfig.instance.enabledApis}');
  print('Has Service Account: ${GCPConfig.instance.hasServiceAccount}');
}
```

### 2. Test API Access

```dart
// Test authentication
import 'package:nutrisync/services/gcp_auth_service.dart';

void testGCPAuth() async {
  await GCPAuthService.instance.initialize();
  
  final token = await GCPAuthService.instance.getAccessToken();
  print('Access Token: ${token != null ? 'Available' : 'Not available'}');
}
```

## Troubleshooting

### Common Issues

#### 1. "API not enabled" Error

```bash
# Enable the specific API
gcloud services enable [API_NAME].googleapis.com
```

#### 2. "Permission denied" Error

```bash
# Check IAM roles
gcloud projects get-iam-policy $PROJECT_ID

# Add missing role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/[REQUIRED_ROLE]"
```

#### 3. "Service account key not found" Error

- Verify the key file exists in `assets/config/gcp/`
- Check the file name matches the environment
- Ensure the file is not corrupted

#### 4. "Invalid credentials" Error

- Regenerate the service account key
- Verify the service account has required permissions
- Check the project ID in the configuration

### Debug Mode

Enable debug logging in development:

```dart
// In main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    // Enable detailed logging
  }
  runApp(MyApp());
}
```

## Cost Management

### 1. Set Up Billing Alerts

```bash
# Create budget alert
gcloud billing budgets create \
  --billing-account=[BILLING_ACCOUNT_ID] \
  --display-name="NutriSync GCP Budget" \
  --budget-amount=100USD \
  --threshold-rule=percent=0.5,basis=CURRENT_SPEND \
  --threshold-rule=percent=0.9,basis=CURRENT_SPEND \
  --threshold-rule=percent=1.0,basis=CURRENT_SPEND
```

### 2. Monitor Usage

- Use Cloud Monitoring dashboards
- Set up custom alerts for API usage
- Review billing reports regularly

### 3. Optimize Costs

- Use appropriate machine types for Cloud Run
- Implement caching to reduce API calls
- Use regional resources when possible
- Clean up unused resources

## Next Steps

After completing the GCP setup:

1. **Test the configuration** using the Flutter app
2. **Implement AI services** following the task list
3. **Set up monitoring** and alerting
4. **Configure CI/CD** for automated deployments
5. **Implement cost optimization** strategies

## Support

For issues with this setup:

1. Check the [troubleshooting section](#troubleshooting)
2. Review GCP documentation
3. Check the project's GitHub issues
4. Contact the development team

## References

- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-for-service-accounts)
- [API Security Best Practices](https://cloud.google.com/apis/docs/best-practices)
- [Cost Management Guide](https://cloud.google.com/billing/docs/how-to/budgets)