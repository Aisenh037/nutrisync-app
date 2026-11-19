import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'environment_config.dart';
import '../services/gcp_service_account_manager.dart';

/// Google Cloud Platform configuration manager
/// Handles GCP service authentication and API configuration
class GCPConfig {
  static GCPConfig? _instance;
  static GCPConfig get instance => _instance ??= GCPConfig._();
  
  GCPConfig._();
  
  Map<String, dynamic>? _gcpConfig;
  bool _isInitialized = false;
  
  /// Initialize GCP configuration
  Future<void> initialize() async {
    final environment = EnvironmentConfig.instance.environment;
    
    try {
      // Load GCP configuration from environment config
      _gcpConfig = EnvironmentConfig.instance.getValue<Map<String, dynamic>>('gcp') ?? {};
      
      // Initialize service account manager
      await GcpServiceAccountManager.instance.initialize();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ GCP configuration loaded for environment: $environment');
        print('✓ Project ID: $projectId');
        print('✓ Enabled APIs: ${enabledApis.join(', ')}');
        
        final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
        if (serviceAccountStatus.hasCredentials) {
          print('✓ Service account: ${serviceAccountStatus.clientEmail}');
        } else {
          print('⚠ No service account credentials found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load GCP configuration: $e');
      }
      _gcpConfig = _getDefaultGCPConfig();
      _isInitialized = true; // Still initialize with defaults
    }
  }
  
  /// Get default GCP configuration
  Map<String, dynamic> _getDefaultGCPConfig() {
    return {
      'projectId': 'nutrisync-gcp-dev',
      'region': 'us-central1',
      'apis': {
        'speechToText': {
          'enabled': true,
          'languageCode': 'en-US',
          'model': 'latest_long',
          'useEnhanced': true
        },
        'textToSpeech': {
          'enabled': true,
          'languageCode': 'en-US',
          'voiceName': 'en-US-Neural2-F',
          'audioEncoding': 'MP3'
        },
        'vision': {
          'enabled': true,
          'features': ['OBJECT_LOCALIZATION', 'TEXT_DETECTION', 'LABEL_DETECTION'],
          'maxResults': 10
        },
        'translation': {
          'enabled': true,
          'defaultTargetLanguage': 'en',
          'supportedLanguages': ['en', 'es', 'fr', 'de', 'it', 'pt', 'hi', 'zh']
        },
        'dialogflow': {
          'enabled': true,
          'agentId': 'nutrisync-agent',
          'sessionTimeout': 300
        },
        'maps': {
          'enabled': true,
          'defaultRadius': 5000,
          'maxResults': 20
        },
        'places': {
          'enabled': true,
          'types': ['grocery_or_supermarket', 'health', 'restaurant'],
          'maxResults': 20
        }
      },
      'services': {
        'cloudRun': {
          'region': 'us-central1',
          'maxInstances': 10,
          'memory': '512Mi',
          'cpu': '1000m'
        },
        'cloudFunctions': {
          'region': 'us-central1',
          'runtime': 'nodejs18',
          'memory': '256MB',
          'timeout': '60s'
        }
      },
      'monitoring': {
        'enabled': true,
        'alerting': true,
        'costThreshold': 100.0
      }
    };
  }
  
  /// GCP Project ID (from service account or config)
  String get projectId {
    // Try to get from service account first
    final serviceAccountProjectId = GcpServiceAccountManager.instance.projectId;
    if (serviceAccountProjectId != null && serviceAccountProjectId.isNotEmpty) {
      return serviceAccountProjectId;
    }
    
    // Fallback to configuration
    return _gcpConfig?['projectId'] ?? 'nutrisync-gcp-dev';
  }
  
  /// GCP Region
  String get region => _gcpConfig?['region'] ?? 'us-central1';
  
  /// Check if service account is configured (delegate to service account manager)
  bool get hasServiceAccount => GcpServiceAccountManager.instance.hasServiceAccount;
  
  /// Get service account credentials (delegate to service account manager)
  ServiceAccountCredentials? get serviceAccountCredentials => GcpServiceAccountManager.instance.credentials;
  
  /// Get API configuration for a specific service
  Map<String, dynamic> getApiConfig(String apiName) {
    return _gcpConfig?['apis']?[apiName] ?? {};
  }
  
  /// Check if an API is enabled
  bool isApiEnabled(String apiName) {
    return getApiConfig(apiName)['enabled'] ?? false;
  }
  
  /// Get list of enabled APIs
  List<String> get enabledApis {
    final apis = _gcpConfig?['apis'] as Map<String, dynamic>? ?? {};
    return apis.entries
        .where((entry) => entry.value['enabled'] == true)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Speech-to-Text configuration
  Map<String, dynamic> get speechToTextConfig => getApiConfig('speechToText');
  
  /// Text-to-Speech configuration
  Map<String, dynamic> get textToSpeechConfig => getApiConfig('textToSpeech');
  
  /// Vision API configuration
  Map<String, dynamic> get visionConfig => getApiConfig('vision');
  
  /// Translation API configuration
  Map<String, dynamic> get translationConfig => getApiConfig('translation');
  
  /// Dialogflow configuration
  Map<String, dynamic> get dialogflowConfig => getApiConfig('dialogflow');
  
  /// Maps API configuration
  Map<String, dynamic> get mapsConfig => getApiConfig('maps');
  
  /// Places API configuration
  Map<String, dynamic> get placesConfig => getApiConfig('places');
  
  /// Cloud Run service configuration
  Map<String, dynamic> get cloudRunConfig => _gcpConfig?['services']?['cloudRun'] ?? {};
  
  /// Cloud Functions configuration
  Map<String, dynamic> get cloudFunctionsConfig => _gcpConfig?['services']?['cloudFunctions'] ?? {};
  
  /// Monitoring configuration
  Map<String, dynamic> get monitoringConfig => _gcpConfig?['monitoring'] ?? {};
  
  /// Check if monitoring is enabled
  bool get isMonitoringEnabled => monitoringConfig['enabled'] ?? false;
  
  /// Check if alerting is enabled
  bool get isAlertingEnabled => monitoringConfig['alerting'] ?? false;
  
  /// Get cost threshold for alerts
  double get costThreshold => (monitoringConfig['costThreshold'] ?? 100.0).toDouble();
  
  /// Validate GCP configuration
  bool get isValid {
    return _isInitialized &&
           projectId.isNotEmpty && 
           region.isNotEmpty && 
           enabledApis.isNotEmpty;
  }
  
  /// Get comprehensive configuration status
  GcpConfigStatus getStatus() {
    final serviceAccountStatus = GcpServiceAccountManager.instance.getStatus();
    
    return GcpConfigStatus(
      isInitialized: _isInitialized,
      hasServiceAccount: serviceAccountStatus.hasCredentials,
      projectId: projectId,
      region: region,
      enabledApis: enabledApis,
      environment: serviceAccountStatus.environment,
      isValid: isValid && serviceAccountStatus.isValid,
    );
  }
  
  /// Reset configuration (for testing)
  @visibleForTesting
  void reset() {
    _gcpConfig = null;
    _isInitialized = false;
  }
  
  /// Set configuration directly (for testing)
  @visibleForTesting
  void setConfig(Map<String, dynamic> config) {
    _gcpConfig = config;
    _isInitialized = true;
  }
}

/// GCP Configuration Status
class GcpConfigStatus {
  final bool isInitialized;
  final bool hasServiceAccount;
  final String projectId;
  final String region;
  final List<String> enabledApis;
  final String? environment;
  final bool isValid;
  
  const GcpConfigStatus({
    required this.isInitialized,
    required this.hasServiceAccount,
    required this.projectId,
    required this.region,
    required this.enabledApis,
    this.environment,
    required this.isValid,
  });
  
  bool get isHealthy => isInitialized && hasServiceAccount && isValid;
  
  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'hasServiceAccount': hasServiceAccount,
      'projectId': projectId,
      'region': region,
      'enabledApis': enabledApis,
      'environment': environment,
      'isValid': isValid,
      'isHealthy': isHealthy,
    };
  }
}

/// Extension for easier access to GCP configuration
extension GCPConfigExtension on GCPConfig {
  /// Quick check if all required APIs are enabled
  bool get hasRequiredApis {
    final required = ['speechToText', 'textToSpeech', 'vision', 'translation', 'dialogflow'];
    return required.every((api) => isApiEnabled(api));
  }
  
  /// Get authentication headers for API calls (delegate to auth service)
  Future<Map<String, String>> getAuthHeaders() async {
    // This will be handled by GCPAuthService
    return {
      'Content-Type': 'application/json',
      'X-Goog-User-Project': projectId,
    };
  }
}