import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';

/// Configuration service for GCP and external APIs
class ServiceConfig {
  static ServiceConfig? _instance;
  static ServiceConfig get instance => _instance ??= ServiceConfig._();
  
  ServiceConfig._();
  
  final _logger = Logger('ServiceConfig');
  
  String? _projectId;
  String? _region;
  String? _usdaApiKey;
  ServiceAccountCredentials? _serviceAccountCredentials;
  
  /// Initialize service configuration
  Future<void> initialize() async {
    try {
      // Load from environment variables
      _projectId = Platform.environment['GCP_PROJECT_ID'] ?? 'nutrisync-ai-project';
      _region = Platform.environment['GCP_REGION'] ?? 'us-central1';
      _usdaApiKey = Platform.environment['USDA_API_KEY'];
      
      // Load service account credentials
      await _loadServiceAccountCredentials();
      
      _logger.info('Service configuration initialized');
      _logger.info('Project ID: $_projectId');
      _logger.info('Region: $_region');
      _logger.info('USDA API Key: ${_usdaApiKey != null ? 'configured' : 'not configured'}');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize service configuration: $e', e, stackTrace);
      rethrow;
    }
  }
  
  /// Get GCP project ID
  String get projectId => _projectId ?? 'nutrisync-ai-project';
  
  /// Get GCP region
  String get region => _region ?? 'us-central1';
  
  /// Get USDA API key
  Future<String?> getUSDAApiKey() async {
    return _usdaApiKey;
  }
  
  /// Get service account credentials
  Future<ServiceAccountCredentials> getServiceAccountCredentials() async {
    if (_serviceAccountCredentials == null) {
      await _loadServiceAccountCredentials();
    }
    
    if (_serviceAccountCredentials == null) {
      throw Exception('Service account credentials not available');
    }
    
    return _serviceAccountCredentials!;
  }
  
  /// Load service account credentials
  Future<void> _loadServiceAccountCredentials() async {
    try {
      // Try to load from environment variable (JSON string)
      final credentialsJson = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS_JSON'];
      if (credentialsJson != null) {
        final credentialsMap = json.decode(credentialsJson) as Map<String, dynamic>;
        _serviceAccountCredentials = ServiceAccountCredentials.fromJson(credentialsMap);
        _logger.info('Loaded service account credentials from environment variable');
        return;
      }
      
      // Try to load from file path
      final credentialsPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
      if (credentialsPath != null) {
        final credentialsFile = File(credentialsPath);
        if (await credentialsFile.exists()) {
          final credentialsContent = await credentialsFile.readAsString();
          final credentialsMap = json.decode(credentialsContent) as Map<String, dynamic>;
          _serviceAccountCredentials = ServiceAccountCredentials.fromJson(credentialsMap);
          _logger.info('Loaded service account credentials from file: $credentialsPath');
          return;
        }
      }
      
      // Try default locations
      final defaultPaths = [
        'config/service-account-key.json',
        '../config/service-account-key.json',
        '../../config/service-account-key.json',
      ];
      
      for (final path in defaultPaths) {
        final file = File(path);
        if (await file.exists()) {
          final credentialsContent = await file.readAsString();
          final credentialsMap = json.decode(credentialsContent) as Map<String, dynamic>;
          _serviceAccountCredentials = ServiceAccountCredentials.fromJson(credentialsMap);
          _logger.info('Loaded service account credentials from: $path');
          return;
        }
      }
      
      // Create mock credentials for development
      _serviceAccountCredentials = _createMockCredentials();
      _logger.warning('Using mock credentials for development');
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to load service account credentials: $e', e, stackTrace);
      
      // Create mock credentials as fallback
      _serviceAccountCredentials = _createMockCredentials();
      _logger.warning('Using mock credentials as fallback');
    }
  }
  
  /// Create mock credentials for development/testing
  ServiceAccountCredentials _createMockCredentials() {
    return ServiceAccountCredentials.fromJson({
      'type': 'service_account',
      'project_id': projectId,
      'private_key_id': 'mock_key_id',
      'private_key': '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKB
wjlCYfcqlyEOgEdlBObAzCKycsHUw+Wz5eZrTuWHiSxhQGvgGg0Q4fMqCXmPiH7s
sY62HcnOHISHBKJ+2BdFyaDOr2wjw8lbgGlHUQ3TX4ytnp1cfcedgAIBBg==
-----END PRIVATE KEY-----''',
      'client_email': 'mock-service-account@${projectId}.iam.gserviceaccount.com',
      'client_id': 'mock_client_id',
      'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
      'token_uri': 'https://oauth2.googleapis.com/token',
    });
  }
  
  /// Get service configuration for health checks
  Map<String, dynamic> getHealthInfo() {
    return {
      'projectId': projectId,
      'region': region,
      'hasServiceAccount': _serviceAccountCredentials != null,
      'hasUSDAKey': _usdaApiKey != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}