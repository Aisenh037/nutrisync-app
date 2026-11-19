import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import '../config/api_configuration_manager.dart';
import '../config/secure_key_manager.dart';
import '../config/environment_config.dart';

/// GCP Service Account Manager
/// Handles environment-specific service account key loading, validation, and management
class GcpServiceAccountManager {
  static GcpServiceAccountManager? _instance;
  static GcpServiceAccountManager get instance => _instance ??= GcpServiceAccountManager._();
  
  GcpServiceAccountManager._();
  
  ServiceAccountCredentials? _credentials;
  String? _currentEnvironment;
  bool _isInitialized = false;
  
  /// Initialize service account manager
  Future<void> initialize() async {
    try {
      _currentEnvironment = EnvironmentConfig.instance.environment;
      await _loadServiceAccountForEnvironment(_currentEnvironment!);
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ GCP Service Account Manager initialized for environment: $_currentEnvironment');
        if (_credentials != null) {
          print('✓ Service account loaded: ${_credentials!.clientEmail}');
          print('✓ Project ID: ${_credentials!.projectId}');
        } else {
          print('⚠ No service account credentials loaded');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize GCP Service Account Manager: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Load service account for specific environment
  Future<void> _loadServiceAccountForEnvironment(String environment) async {
    try {
      // Try multiple sources for service account credentials
      ServiceAccountCredentials? credentials;
      
      // 1. Try loading from secure key manager
      credentials = await _loadFromSecureKeyManager(environment);
      
      // 2. Try loading from assets
      if (credentials == null) {
        credentials = await _loadFromAssets(environment);
      }
      
      // 3. Try loading from environment variables
      if (credentials == null) {
        credentials = await _loadFromEnvironmentVariables();
      }
      
      // 4. Try loading from file system (for local development)
      if (credentials == null && kDebugMode) {
        credentials = await _loadFromFileSystem(environment);
      }
      
      if (credentials != null) {
        await _validateServiceAccount(credentials);
        _credentials = credentials;
        
        if (kDebugMode) {
          print('✓ Service account credentials loaded and validated');
        }
      } else {
        if (kDebugMode) {
          print('⚠ No service account credentials found for environment: $environment');
          _printSetupInstructions(environment);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load service account for environment $environment: $e');
      }
      throw GcpServiceAccountException('Failed to load service account: $e');
    }
  }
  
  /// Load service account from secure key manager
  Future<ServiceAccountCredentials?> _loadFromSecureKeyManager(String environment) async {
    try {
      final keyJson = SecureKeyManager.instance.getApiKey('gcp_service_account_$environment');
      if (keyJson != null && keyJson.isNotEmpty && !keyJson.startsWith('YOUR_')) {
        final keyData = json.decode(keyJson) as Map<String, dynamic>;
        return ServiceAccountCredentials.fromJson(keyData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load service account from secure key manager: $e');
      }
    }
    return null;
  }
  
  /// Load service account from assets
  Future<ServiceAccountCredentials?> _loadFromAssets(String environment) async {
    try {
      final keyPath = 'assets/config/gcp/service-account-$environment.json';
      final keyJson = await rootBundle.loadString(keyPath);
      
      if (keyJson.isNotEmpty && !keyJson.contains('EXAMPLE_')) {
        final keyData = json.decode(keyJson) as Map<String, dynamic>;
        return ServiceAccountCredentials.fromJson(keyData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Service account file not found in assets: assets/config/gcp/service-account-$environment.json');
      }
    }
    return null;
  }
  
  /// Load service account from environment variables
  Future<ServiceAccountCredentials?> _loadFromEnvironmentVariables() async {
    try {
      // Check for Google Application Credentials environment variable
      const credentialsJson = String.fromEnvironment('GOOGLE_APPLICATION_CREDENTIALS_JSON');
      if (credentialsJson.isNotEmpty) {
        final keyData = json.decode(credentialsJson) as Map<String, dynamic>;
        return ServiceAccountCredentials.fromJson(keyData);
      }
      
      // Check for individual environment variables
      const projectId = String.fromEnvironment('GCP_PROJECT_ID');
      const clientEmail = String.fromEnvironment('GCP_CLIENT_EMAIL');
      const privateKey = String.fromEnvironment('GCP_PRIVATE_KEY');
      const privateKeyId = String.fromEnvironment('GCP_PRIVATE_KEY_ID');
      
      if (projectId.isNotEmpty && clientEmail.isNotEmpty && privateKey.isNotEmpty) {
        return ServiceAccountCredentials(
          type: 'service_account',
          projectId: projectId,
          privateKeyId: privateKeyId.isNotEmpty ? privateKeyId : 'env-key-id',
          privateKey: privateKey.replaceAll('\\n', '\n'), // Handle escaped newlines
          clientEmail: clientEmail,
          clientId: '',
          authUri: 'https://accounts.google.com/o/oauth2/auth',
          tokenUri: 'https://oauth2.googleapis.com/token',
          authProviderX509CertUrl: 'https://www.googleapis.com/oauth2/v1/certs',
          clientX509CertUrl: 'https://www.googleapis.com/robot/v1/metadata/x509/${Uri.encodeComponent(clientEmail)}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load service account from environment variables: $e');
      }
    }
    return null;
  }
  
  /// Load service account from file system (development only)
  Future<ServiceAccountCredentials?> _loadFromFileSystem(String environment) async {
    if (!kDebugMode) return null;
    
    try {
      // Common paths for service account files in development
      final possiblePaths = [
        'service-account-$environment.json',
        'gcp-service-account-$environment.json',
        '../service-account-$environment.json',
        '../../service-account-$environment.json',
      ];
      
      for (final path in possiblePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final keyJson = await file.readAsString();
            final keyData = json.decode(keyJson) as Map<String, dynamic>;
            return ServiceAccountCredentials.fromJson(keyData);
          }
        } catch (e) {
          // Continue to next path
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load service account from file system: $e');
      }
    }
    return null;
  }
  
  /// Validate service account credentials
  Future<void> _validateServiceAccount(ServiceAccountCredentials credentials) async {
    // Validate required fields
    if (credentials.projectId.isEmpty) {
      throw GcpServiceAccountException('Service account project_id is empty');
    }
    
    if (credentials.clientEmail.isEmpty) {
      throw GcpServiceAccountException('Service account client_email is empty');
    }
    
    if (credentials.privateKey.isEmpty) {
      throw GcpServiceAccountException('Service account private_key is empty');
    }
    
    // Validate email format
    if (!credentials.clientEmail.contains('@') || !credentials.clientEmail.contains('.iam.gserviceaccount.com')) {
      throw GcpServiceAccountException('Invalid service account email format: ${credentials.clientEmail}');
    }
    
    // Validate private key format
    if (!credentials.privateKey.contains('BEGIN PRIVATE KEY') || !credentials.privateKey.contains('END PRIVATE KEY')) {
      throw GcpServiceAccountException('Invalid private key format');
    }
    
    // Validate project ID format
    if (credentials.projectId.contains('example') || credentials.projectId.contains('YOUR_')) {
      throw GcpServiceAccountException('Service account contains placeholder values');
    }
    
    if (kDebugMode) {
      print('✓ Service account validation passed');
    }
  }
  
  /// Get current service account credentials
  ServiceAccountCredentials? get credentials => _credentials;
  
  /// Check if service account is configured
  bool get hasServiceAccount => _credentials != null;
  
  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get project ID
  String? get projectId => _credentials?.projectId;
  
  /// Get client email
  String? get clientEmail => _credentials?.clientEmail;
  
  /// Store service account credentials securely
  Future<void> storeServiceAccount(String environment, Map<String, dynamic> credentialsJson) async {
    try {
      // Validate the credentials first
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      await _validateServiceAccount(credentials);
      
      // Store in secure key manager
      await SecureKeyManager.instance.storeApiKey(
        'gcp_service_account_$environment',
        json.encode(credentialsJson),
      );
      
      // Update current credentials if this is the current environment
      if (environment == _currentEnvironment) {
        _credentials = credentials;
      }
      
      if (kDebugMode) {
        print('✓ Service account stored securely for environment: $environment');
      }
    } catch (e) {
      throw GcpServiceAccountException('Failed to store service account: $e');
    }
  }
  
  /// Switch to different environment
  Future<void> switchEnvironment(String environment) async {
    if (environment == _currentEnvironment) return;
    
    _currentEnvironment = environment;
    _credentials = null;
    
    await _loadServiceAccountForEnvironment(environment);
    
    if (kDebugMode) {
      print('✓ Switched to environment: $environment');
    }
  }
  
  /// Get service account status
  ServiceAccountStatus getStatus() {
    return ServiceAccountStatus(
      isInitialized: _isInitialized,
      hasCredentials: _credentials != null,
      environment: _currentEnvironment,
      projectId: _credentials?.projectId,
      clientEmail: _credentials?.clientEmail,
      isValid: _credentials != null && _isValidCredentials(_credentials!),
    );
  }
  
  /// Check if credentials are valid
  bool _isValidCredentials(ServiceAccountCredentials credentials) {
    try {
      // Basic validation
      return credentials.projectId.isNotEmpty &&
             credentials.clientEmail.isNotEmpty &&
             credentials.privateKey.isNotEmpty &&
             credentials.clientEmail.contains('@') &&
             credentials.privateKey.contains('BEGIN PRIVATE KEY');
    } catch (e) {
      return false;
    }
  }
  
  /// Print setup instructions for missing service account
  void _printSetupInstructions(String environment) {
    print('''
⚠ GCP Service Account Setup Required for environment: $environment

To set up GCP service account authentication:

1. Create a service account in Google Cloud Console:
   - Go to https://console.cloud.google.com/iam-admin/serviceaccounts
   - Select your project or create a new one
   - Click "Create Service Account"
   - Give it a name like "nutrisync-ai-service"
   - Grant necessary roles (see documentation)

2. Download the service account key:
   - Click on the created service account
   - Go to "Keys" tab
   - Click "Add Key" > "Create new key"
   - Choose JSON format
   - Download the file

3. Add the key to your project:
   Option A: Place the file at assets/config/gcp/service-account-$environment.json
   Option B: Set environment variables:
     - GCP_PROJECT_ID=your-project-id
     - GCP_CLIENT_EMAIL=service-account@your-project.iam.gserviceaccount.com
     - GCP_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n"
   Option C: Use GOOGLE_APPLICATION_CREDENTIALS_JSON environment variable with full JSON

4. Required GCP APIs to enable:
   - Cloud Speech-to-Text API
   - Cloud Text-to-Speech API
   - Cloud Vision API
   - Cloud Translation API
   - Dialogflow API
   - Maps JavaScript API
   - Places API

For detailed setup instructions, see: docs/GCP_SETUP_GUIDE.md
''');
  }
  
  /// Clear credentials (for testing)
  @visibleForTesting
  void reset() {
    _credentials = null;
    _currentEnvironment = null;
    _isInitialized = false;
  }
}

/// Service Account Credentials model
class ServiceAccountCredentials {
  final String type;
  final String projectId;
  final String privateKeyId;
  final String privateKey;
  final String clientEmail;
  final String clientId;
  final String authUri;
  final String tokenUri;
  final String authProviderX509CertUrl;
  final String clientX509CertUrl;
  
  const ServiceAccountCredentials({
    required this.type,
    required this.projectId,
    required this.privateKeyId,
    required this.privateKey,
    required this.clientEmail,
    required this.clientId,
    required this.authUri,
    required this.tokenUri,
    required this.authProviderX509CertUrl,
    required this.clientX509CertUrl,
  });
  
  factory ServiceAccountCredentials.fromJson(Map<String, dynamic> json) {
    return ServiceAccountCredentials(
      type: json['type'] as String? ?? 'service_account',
      projectId: json['project_id'] as String? ?? '',
      privateKeyId: json['private_key_id'] as String? ?? '',
      privateKey: json['private_key'] as String? ?? '',
      clientEmail: json['client_email'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      authUri: json['auth_uri'] as String? ?? 'https://accounts.google.com/o/oauth2/auth',
      tokenUri: json['token_uri'] as String? ?? 'https://oauth2.googleapis.com/token',
      authProviderX509CertUrl: json['auth_provider_x509_cert_url'] as String? ?? 'https://www.googleapis.com/oauth2/v1/certs',
      clientX509CertUrl: json['client_x509_cert_url'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'project_id': projectId,
      'private_key_id': privateKeyId,
      'private_key': privateKey,
      'client_email': clientEmail,
      'client_id': clientId,
      'auth_uri': authUri,
      'token_uri': tokenUri,
      'auth_provider_x509_cert_url': authProviderX509CertUrl,
      'client_x509_cert_url': clientX509CertUrl,
    };
  }
  
  /// Get service account hash for caching
  String get hash {
    final content = '$projectId:$clientEmail:$privateKeyId';
    return sha256.convert(utf8.encode(content)).toString().substring(0, 8);
  }
}

/// Service Account Status information
class ServiceAccountStatus {
  final bool isInitialized;
  final bool hasCredentials;
  final String? environment;
  final String? projectId;
  final String? clientEmail;
  final bool isValid;
  
  const ServiceAccountStatus({
    required this.isInitialized,
    required this.hasCredentials,
    this.environment,
    this.projectId,
    this.clientEmail,
    required this.isValid,
  });
  
  bool get isHealthy => isInitialized && hasCredentials && isValid;
  
  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'hasCredentials': hasCredentials,
      'environment': environment,
      'projectId': projectId,
      'clientEmail': clientEmail,
      'isValid': isValid,
      'isHealthy': isHealthy,
    };
  }
}

/// GCP Service Account Exception
class GcpServiceAccountException implements Exception {
  final String message;
  
  const GcpServiceAccountException(this.message);
  
  @override
  String toString() => 'GcpServiceAccountException: $message';
}