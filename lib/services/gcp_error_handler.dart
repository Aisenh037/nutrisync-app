import 'package:flutter/foundation.dart';
import 'gcp_service_account_manager.dart';
import 'gcp_auth_service.dart';

/// GCP Error Handler
/// Provides clear error messages and setup guidance for GCP authentication issues
class GcpErrorHandler {
  static GcpErrorHandler? _instance;
  static GcpErrorHandler get instance => _instance ??= GcpErrorHandler._();
  
  GcpErrorHandler._();
  
  /// Handle missing service account key error
  GcpErrorResult handleMissingServiceAccount(String environment) {
    return GcpErrorResult(
      errorType: GcpErrorType.missingServiceAccount,
      title: 'GCP Service Account Not Found',
      message: 'No service account credentials found for environment: $environment',
      technicalDetails: 'The system could not locate service account credentials in any of the expected locations:\n'
          '• Secure key manager\n'
          '• Assets (assets/config/gcp/service-account-$environment.json)\n'
          '• Environment variables\n'
          '• File system (development only)',
      userFriendlyMessage: 'Google Cloud services are not configured. Please contact your administrator or follow the setup guide.',
      setupInstructions: _getServiceAccountSetupInstructions(environment),
      severity: ErrorSeverity.critical,
      isRetryable: false,
      suggestedActions: [
        'Follow the GCP setup guide in docs/GCP_SETUP_GUIDE.md',
        'Contact your system administrator for service account credentials',
        'Check if you have the correct environment configuration',
      ],
    );
  }
  
  /// Handle invalid service account format error
  GcpErrorResult handleInvalidServiceAccount(String details) {
    return GcpErrorResult(
      errorType: GcpErrorType.invalidServiceAccount,
      title: 'Invalid Service Account Format',
      message: 'The service account credentials are not in the correct format',
      technicalDetails: details,
      userFriendlyMessage: 'The Google Cloud configuration is invalid. Please check the setup.',
      setupInstructions: _getServiceAccountFormatInstructions(),
      severity: ErrorSeverity.high,
      isRetryable: false,
      suggestedActions: [
        'Verify the service account JSON file is valid',
        'Check that all required fields are present',
        'Ensure the private key is properly formatted',
        'Re-download the service account key from Google Cloud Console',
      ],
    );
  }
  
  /// Handle authentication failure error
  GcpErrorResult handleAuthenticationFailure(int statusCode, String responseBody) {
    switch (statusCode) {
      case 400:
        return GcpErrorResult(
          errorType: GcpErrorType.invalidCredentials,
          title: 'Invalid Service Account Credentials',
          message: 'The service account credentials are invalid or malformed',
          technicalDetails: 'HTTP 400: $responseBody',
          userFriendlyMessage: 'Google Cloud authentication failed. The credentials may be expired or invalid.',
          setupInstructions: _getCredentialRefreshInstructions(),
          severity: ErrorSeverity.high,
          isRetryable: false,
          suggestedActions: [
            'Verify the service account key is correct',
            'Check if the service account has been deleted or disabled',
            'Ensure the private key is properly formatted',
            'Re-download a new service account key',
          ],
        );
      
      case 403:
        return GcpErrorResult(
          errorType: GcpErrorType.insufficientPermissions,
          title: 'Insufficient Permissions',
          message: 'The service account does not have the required permissions',
          technicalDetails: 'HTTP 403: $responseBody',
          userFriendlyMessage: 'Google Cloud services are not accessible. The account may not have the required permissions.',
          setupInstructions: _getPermissionSetupInstructions(),
          severity: ErrorSeverity.high,
          isRetryable: false,
          suggestedActions: [
            'Grant the required IAM roles to the service account',
            'Enable the necessary Google Cloud APIs',
            'Check the project billing status',
            'Verify the service account is in the correct project',
          ],
        );
      
      case 429:
        return GcpErrorResult(
          errorType: GcpErrorType.rateLimited,
          title: 'Rate Limit Exceeded',
          message: 'Too many authentication requests',
          technicalDetails: 'HTTP 429: $responseBody',
          userFriendlyMessage: 'Google Cloud services are temporarily unavailable due to high usage. Please try again later.',
          setupInstructions: null,
          severity: ErrorSeverity.medium,
          isRetryable: true,
          suggestedActions: [
            'Wait a few minutes before retrying',
            'Implement exponential backoff in your requests',
            'Check if you have quota limits configured',
          ],
        );
      
      default:
        return GcpErrorResult(
          errorType: GcpErrorType.networkError,
          title: 'Authentication Network Error',
          message: 'Failed to authenticate with Google Cloud services',
          technicalDetails: 'HTTP $statusCode: $responseBody',
          userFriendlyMessage: 'Unable to connect to Google Cloud services. Please check your internet connection.',
          setupInstructions: null,
          severity: ErrorSeverity.medium,
          isRetryable: true,
          suggestedActions: [
            'Check your internet connection',
            'Verify firewall settings allow HTTPS traffic',
            'Try again in a few minutes',
          ],
        );
    }
  }
  
  /// Handle API permission error
  GcpErrorResult handleApiPermissionError(String apiName, String details) {
    return GcpErrorResult(
      errorType: GcpErrorType.apiNotEnabled,
      title: 'API Not Enabled',
      message: 'The $apiName API is not enabled or accessible',
      technicalDetails: details,
      userFriendlyMessage: 'Some Google Cloud features are not available. The $apiName service may not be configured.',
      setupInstructions: _getApiEnableInstructions(apiName),
      severity: ErrorSeverity.high,
      isRetryable: false,
      suggestedActions: [
        'Enable the $apiName API in Google Cloud Console',
        'Check the service account has the required roles',
        'Verify the project has billing enabled',
        'Ensure the API quota is not exceeded',
      ],
    );
  }
  
  /// Handle environment switching error
  GcpErrorResult handleEnvironmentSwitchError(String fromEnv, String toEnv, String details) {
    return GcpErrorResult(
      errorType: GcpErrorType.environmentSwitchFailed,
      title: 'Environment Switch Failed',
      message: 'Failed to switch from $fromEnv to $toEnv environment',
      technicalDetails: details,
      userFriendlyMessage: 'Unable to switch to the $toEnv environment. Configuration may be missing.',
      setupInstructions: _getEnvironmentSetupInstructions(toEnv),
      severity: ErrorSeverity.medium,
      isRetryable: true,
      suggestedActions: [
        'Verify service account exists for $toEnv environment',
        'Check environment configuration files',
        'Ensure proper credentials are stored',
      ],
    );
  }
  
  /// Get comprehensive diagnostic information
  Future<GcpDiagnosticInfo> getDiagnosticInfo() async {
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    final authStatus = GCPAuthService.instance.getAuthStatus();
    
    final issues = <GcpErrorResult>[];
    final recommendations = <String>[];
    
    // Check service account
    if (!serviceAccountStatus.hasCredentials) {
      issues.add(handleMissingServiceAccount(serviceAccountStatus.environment ?? 'unknown'));
    } else if (!serviceAccountStatus.isValid) {
      issues.add(handleInvalidServiceAccount('Service account validation failed'));
    }
    
    // Check authentication
    if (!authStatus.hasValidToken && serviceAccountStatus.hasCredentials) {
      issues.add(GcpErrorResult(
        errorType: GcpErrorType.tokenExpired,
        title: 'Access Token Expired',
        message: 'The GCP access token has expired',
        technicalDetails: 'Token expiry: ${authStatus.tokenExpiry}',
        userFriendlyMessage: 'Google Cloud authentication needs to be refreshed.',
        setupInstructions: null,
        severity: ErrorSeverity.low,
        isRetryable: true,
        suggestedActions: ['The system will automatically refresh the token'],
      ));
    }
    
    // Generate recommendations
    if (issues.isEmpty) {
      recommendations.add('✓ GCP authentication is properly configured');
    } else {
      recommendations.add('Configure GCP service account credentials');
      recommendations.add('Enable required Google Cloud APIs');
      recommendations.add('Verify service account permissions');
    }
    
    return GcpDiagnosticInfo(
      serviceAccountStatus: serviceAccountStatus,
      authStatus: authStatus,
      issues: issues,
      recommendations: recommendations,
      overallHealth: issues.isEmpty ? DiagnosticHealth.healthy : 
                     issues.any((i) => i.severity == ErrorSeverity.critical) ? DiagnosticHealth.critical :
                     DiagnosticHealth.warning,
    );
  }
  
  /// Get service account setup instructions
  String _getServiceAccountSetupInstructions(String environment) {
    return '''
# GCP Service Account Setup for $environment

## Step 1: Create Service Account
1. Go to Google Cloud Console: https://console.cloud.google.com/iam-admin/serviceaccounts
2. Select your project (or create a new one)
3. Click "Create Service Account"
4. Name: nutrisync-ai-service-$environment
5. Description: NutriSync AI services for $environment

## Step 2: Grant Roles
Add these IAM roles to the service account:
• Cloud Speech Client
• Cloud Text-to-Speech Client
• Cloud Vision Client
• Cloud Translation Client
• Dialogflow Client
• Service Account Token Creator

## Step 3: Create and Download Key
1. Click on the created service account
2. Go to "Keys" tab
3. Click "Add Key" > "Create new key"
4. Choose JSON format
5. Download the file

## Step 4: Add Key to Project
Choose one of these options:

### Option A: Assets (Recommended for mobile)
Place the downloaded file at:
assets/config/gcp/service-account-$environment.json

### Option B: Environment Variables
Set these environment variables:
```
GCP_PROJECT_ID=your-project-id
GCP_CLIENT_EMAIL=nutrisync-ai-service-$environment@your-project.iam.gserviceaccount.com
GCP_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n"
GCP_PRIVATE_KEY_ID=key-id-from-json
```

### Option C: Full JSON Environment Variable
```
GOOGLE_APPLICATION_CREDENTIALS_JSON='{"type":"service_account",...}'
```

## Step 5: Enable APIs
Enable these APIs in Google Cloud Console:
• Cloud Speech-to-Text API
• Cloud Text-to-Speech API
• Cloud Vision API
• Cloud Translation API
• Dialogflow API

For detailed instructions, see: docs/GCP_SETUP_GUIDE.md
''';
  }
  
  /// Get service account format instructions
  String _getServiceAccountFormatInstructions() {
    return '''
# Service Account Format Requirements

The service account JSON file must contain these fields:
• type: "service_account"
• project_id: Your GCP project ID
• private_key_id: Key identifier
• private_key: RSA private key (with \\n newlines)
• client_email: Service account email
• client_id: Numeric client ID
• auth_uri: OAuth2 auth URI
• token_uri: OAuth2 token URI
• auth_provider_x509_cert_url: Certificate URL
• client_x509_cert_url: Client certificate URL

Common issues:
• Missing or empty required fields
• Invalid private key format
• Placeholder values (YOUR_PROJECT_ID, etc.)
• Malformed JSON syntax

To fix: Re-download the service account key from Google Cloud Console.
''';
  }
  
  /// Get credential refresh instructions
  String _getCredentialRefreshInstructions() {
    return '''
# Refresh Service Account Credentials

If authentication is failing:

1. Check service account status in Google Cloud Console
2. Verify the service account hasn't been deleted
3. Ensure the private key hasn't been rotated
4. Download a new service account key if needed

Steps to refresh:
1. Go to Google Cloud Console > IAM & Admin > Service Accounts
2. Find your service account
3. Click on it and go to "Keys" tab
4. Delete old keys if needed
5. Create a new key (JSON format)
6. Update your application configuration
''';
  }
  
  /// Get permission setup instructions
  String _getPermissionSetupInstructions() {
    return '''
# Required IAM Permissions

Grant these roles to your service account:

## Basic Roles
• Cloud Speech Client (roles/speech.client)
• Cloud Text-to-Speech Client (roles/texttospeech.client)
• Cloud Vision Client (roles/vision.client)
• Cloud Translation Client (roles/translation.client)
• Dialogflow Client (roles/dialogflow.client)

## Additional Permissions
• Service Account Token Creator (if using impersonation)
• Project Viewer (for basic project access)

## To Grant Permissions:
1. Go to Google Cloud Console > IAM & Admin > IAM
2. Find your service account
3. Click "Edit" (pencil icon)
4. Add the required roles
5. Save changes

## Verify Billing:
Ensure your project has billing enabled for API access.
''';
  }
  
  /// Get API enable instructions
  String _getApiEnableInstructions(String apiName) {
    final apiUrls = {
      'Speech-to-Text': 'https://console.cloud.google.com/apis/library/speech.googleapis.com',
      'Text-to-Speech': 'https://console.cloud.google.com/apis/library/texttospeech.googleapis.com',
      'Vision': 'https://console.cloud.google.com/apis/library/vision.googleapis.com',
      'Translation': 'https://console.cloud.google.com/apis/library/translate.googleapis.com',
      'Dialogflow': 'https://console.cloud.google.com/apis/library/dialogflow.googleapis.com',
    };
    
    final url = apiUrls[apiName] ?? 'https://console.cloud.google.com/apis/library';
    
    return '''
# Enable $apiName API

1. Go to Google Cloud Console: $url
2. Select your project
3. Click "Enable" button
4. Wait for the API to be enabled (may take a few minutes)
5. Verify the API appears in your enabled APIs list

Note: Enabling APIs may require billing to be set up on your project.
''';
  }
  
  /// Get environment setup instructions
  String _getEnvironmentSetupInstructions(String environment) {
    return '''
# Environment Setup: $environment

Ensure you have:
1. Service account credentials for $environment
2. Environment configuration file: assets/config/environments/$environment.json
3. GCP project configured for $environment
4. Required APIs enabled in the $environment project

Check these files exist:
• assets/config/gcp/service-account-$environment.json
• assets/config/environments/$environment.json

Or set environment variables for $environment configuration.
''';
  }
}

/// GCP Error Result
class GcpErrorResult {
  final GcpErrorType errorType;
  final String title;
  final String message;
  final String technicalDetails;
  final String userFriendlyMessage;
  final String? setupInstructions;
  final ErrorSeverity severity;
  final bool isRetryable;
  final List<String> suggestedActions;
  
  const GcpErrorResult({
    required this.errorType,
    required this.title,
    required this.message,
    required this.technicalDetails,
    required this.userFriendlyMessage,
    this.setupInstructions,
    required this.severity,
    required this.isRetryable,
    required this.suggestedActions,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'errorType': errorType.name,
      'title': title,
      'message': message,
      'technicalDetails': technicalDetails,
      'userFriendlyMessage': userFriendlyMessage,
      'setupInstructions': setupInstructions,
      'severity': severity.name,
      'isRetryable': isRetryable,
      'suggestedActions': suggestedActions,
    };
  }
}

/// GCP Diagnostic Information
class GcpDiagnosticInfo {
  final ServiceAccountStatus serviceAccountStatus;
  final GcpAuthStatus authStatus;
  final List<GcpErrorResult> issues;
  final List<String> recommendations;
  final DiagnosticHealth overallHealth;
  
  const GcpDiagnosticInfo({
    required this.serviceAccountStatus,
    required this.authStatus,
    required this.issues,
    required this.recommendations,
    required this.overallHealth,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'serviceAccountStatus': serviceAccountStatus.toJson(),
      'authStatus': authStatus.toJson(),
      'issues': issues.map((i) => i.toJson()).toList(),
      'recommendations': recommendations,
      'overallHealth': overallHealth.name,
    };
  }
}

/// GCP Error Types
enum GcpErrorType {
  missingServiceAccount,
  invalidServiceAccount,
  invalidCredentials,
  insufficientPermissions,
  rateLimited,
  networkError,
  apiNotEnabled,
  tokenExpired,
  environmentSwitchFailed,
}

/// Error Severity Levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Diagnostic Health Levels
enum DiagnosticHealth {
  healthy,
  warning,
  critical,
}