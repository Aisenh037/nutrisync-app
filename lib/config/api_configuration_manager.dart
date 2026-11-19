import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'environment_config.dart';

/// Comprehensive API Configuration Manager
/// Handles environment-specific API configurations, validation, and secure key management
class ApiConfigurationManager {
  static ApiConfigurationManager? _instance;
  static ApiConfigurationManager get instance => _instance ??= ApiConfigurationManager._();
  
  ApiConfigurationManager._();
  
  Map<String, ApiServiceConfig>? _apiConfigs;
  Map<String, String>? _encryptedKeys;
  String? _currentEnvironment;
  DateTime? _lastLoadTime;
  bool _isInitialized = false;
  
  /// Cache duration for configuration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// Current environment
  String get environment => _currentEnvironment ?? 'development';
  
  /// Check if configuration is initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if configuration cache is valid
  bool get isCacheValid {
    if (_lastLoadTime == null) return false;
    return DateTime.now().difference(_lastLoadTime!) < _cacheDuration;
  }
  
  /// Initialize configuration manager
  Future<void> initialize({String? environment}) async {
    _currentEnvironment = environment ?? EnvironmentConfig.instance.environment;
    
    try {
      await _loadApiConfigurations();
      await _loadSecureKeys();
      _lastLoadTime = DateTime.now();
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ API Configuration Manager initialized for environment: $_currentEnvironment');
        print('✓ Loaded ${_apiConfigs?.length ?? 0} API service configurations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize API Configuration Manager: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Load API configurations from environment-specific files
  Future<void> _loadApiConfigurations() async {
    _apiConfigs = {};
    
    // Load base configuration from environment config
    final envConfig = EnvironmentConfig.instance;
    
    // ElevenLabs Configuration
    _apiConfigs!['elevenlabs'] = ApiServiceConfig(
      serviceName: 'elevenlabs',
      baseUrl: 'https://api.elevenlabs.io/v1',
      apiKey: await _getSecureApiKey('elevenlabs'),
      timeout: const Duration(seconds: 30),
      retryAttempts: 3,
      rateLimitPerMinute: 100,
      isEnabled: envConfig.getValue<bool>('features.enableVoiceFeatures', defaultValue: true) ?? true,
      additionalConfig: {
        'supportedModels': [
          'eleven_turbo_v2_5',
          'eleven_turbo_v2',
          'eleven_multilingual_v2',
          'eleven_monolingual_v1'
        ],
        'defaultVoiceId': '21m00Tcm4TlvDq8ikWAM',
        'fallbackEnabled': true,
        'maxRetries': 3,
      },
    );
    
    // Google Maps Configuration
    _apiConfigs!['googlemaps'] = ApiServiceConfig(
      serviceName: 'googlemaps',
      baseUrl: 'https://maps.googleapis.com/maps/api',
      apiKey: await _getSecureApiKey('googlemaps'),
      timeout: const Duration(seconds: 15),
      retryAttempts: 2,
      rateLimitPerMinute: 1000,
      isEnabled: true,
      additionalConfig: {
        'corsEnabled': kIsWeb,
        'allowedOrigins': _getAllowedOrigins(),
        'restrictedApis': ['places', 'geocoding', 'directions'],
        'defaultRadius': 5000,
        'maxResults': 20,
      },
    );
    
    // Google Places Configuration
    _apiConfigs!['googleplaces'] = ApiServiceConfig(
      serviceName: 'googleplaces',
      baseUrl: 'https://places.googleapis.com/v1',
      apiKey: await _getSecureApiKey('googleplaces'),
      timeout: const Duration(seconds: 15),
      retryAttempts: 2,
      rateLimitPerMinute: 1000,
      isEnabled: true,
      additionalConfig: {
        'types': ['grocery_or_supermarket', 'health', 'restaurant'],
        'maxResults': 20,
        'corsEnabled': kIsWeb,
      },
    );
    
    // GCP Service Account Configuration
    _apiConfigs!['gcp'] = ApiServiceConfig(
      serviceName: 'gcp',
      baseUrl: 'https://googleapis.com',
      apiKey: null, // Uses service account instead
      timeout: const Duration(seconds: 30),
      retryAttempts: 3,
      rateLimitPerMinute: 1000,
      isEnabled: true,
      additionalConfig: {
        'projectId': envConfig.getValue<String>('gcp.projectId', defaultValue: 'nutrisync-gcp-dev'),
        'region': envConfig.getValue<String>('gcp.region', defaultValue: 'us-central1'),
        'serviceAccountPath': 'assets/config/gcp/service-account-$_currentEnvironment.json',
        'enabledApis': [
          'speechToText',
          'textToSpeech',
          'vision',
          'translation',
          'dialogflow'
        ],
      },
    );
  }
  
  /// Get secure API key for a service
  Future<String?> _getSecureApiKey(String serviceName) async {
    try {
      // In development, use environment variables or config files
      if (_currentEnvironment == 'development') {
        return _getDevApiKey(serviceName);
      }
      
      // In production, use secure storage or encrypted keys
      return await _getEncryptedApiKey(serviceName);
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load API key for $serviceName: $e');
      }
      return null;
    }
  }
  
  /// Get development API key (from environment or config)
  String? _getDevApiKey(String serviceName) {
    // Try environment variables first
    const apiKeys = {
      'elevenlabs': String.fromEnvironment('ELEVENLABS_API_KEY'),
      'googlemaps': String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
      'googleplaces': String.fromEnvironment('GOOGLE_PLACES_API_KEY'),
    };
    
    final envKey = apiKeys[serviceName];
    if (envKey != null && envKey.isNotEmpty && !envKey.startsWith('YOUR_')) {
      return envKey;
    }
    
    // Fallback to placeholder for development
    return 'DEV_${serviceName.toUpperCase()}_KEY';
  }
  
  /// Get encrypted API key from secure storage
  Future<String?> _getEncryptedApiKey(String serviceName) async {
    if (_encryptedKeys == null) return null;
    
    final encryptedKey = _encryptedKeys![serviceName];
    if (encryptedKey == null) return null;
    
    // In a real implementation, this would decrypt the key
    // For now, return the key as-is
    return encryptedKey;
  }
  
  /// Load secure keys from encrypted storage
  Future<void> _loadSecureKeys() async {
    _encryptedKeys = {};
    
    try {
      // Try to load encrypted keys file
      final keysPath = 'assets/config/secure/api-keys-$_currentEnvironment.json';
      final keysString = await rootBundle.loadString(keysPath);
      final keysData = json.decode(keysString) as Map<String, dynamic>;
      
      _encryptedKeys = keysData.cast<String, String>();
      
      if (kDebugMode) {
        print('✓ Loaded ${_encryptedKeys!.length} encrypted API keys');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ No encrypted keys file found, using environment variables: $e');
      }
      // This is expected in development
    }
  }
  
  /// Get allowed origins for CORS
  List<String> _getAllowedOrigins() {
    switch (_currentEnvironment) {
      case 'development':
        return ['http://localhost:*', 'http://127.0.0.1:*'];
      case 'staging':
        return ['https://nutrisync-staging.web.app', 'https://nutrisync-staging.firebaseapp.com'];
      case 'production':
        return ['https://nutrisyncapp.web.app', 'https://nutrisyncapp-97089.firebaseapp.com'];
      default:
        return ['*'];
    }
  }
  
  /// Get API configuration for a service
  ApiServiceConfig? getServiceConfig(String serviceName) {
    if (!_isInitialized) {
      throw StateError('ApiConfigurationManager not initialized. Call initialize() first.');
    }
    
    if (!isCacheValid) {
      if (kDebugMode) {
        print('⚠ Configuration cache expired, consider reloading');
      }
    }
    
    return _apiConfigs?[serviceName];
  }
  
  /// Get all service configurations
  Map<String, ApiServiceConfig> getAllConfigs() {
    if (!_isInitialized) {
      throw StateError('ApiConfigurationManager not initialized. Call initialize() first.');
    }
    
    return Map.unmodifiable(_apiConfigs ?? {});
  }
  
  /// Check if a service is configured and enabled
  bool isServiceEnabled(String serviceName) {
    final config = getServiceConfig(serviceName);
    return config?.isEnabled ?? false;
  }
  
  /// Get API key for a service
  String? getApiKey(String serviceName) {
    final config = getServiceConfig(serviceName);
    return config?.apiKey;
  }
  
  /// Get Google Maps configuration
  Future<Map<String, dynamic>> getGoogleMapsConfig() async {
    if (!_isInitialized) {
      throw StateError('ApiConfigurationManager not initialized. Call initialize() first.');
    }
    
    final config = getServiceConfig('googlemaps');
    if (config == null) {
      throw StateError('Google Maps configuration not found');
    }
    
    return {
      'apiKey': config.apiKey,
      'functionsBaseUrl': _getFunctionsBaseUrl(),
      'allowedOrigins': config.getConfig<List<String>>('allowedOrigins', defaultValue: ['*']),
      'restrictedApis': config.getConfig<List<String>>('restrictedApis', defaultValue: []),
      'corsEnabled': config.getConfig<bool>('corsEnabled', defaultValue: true),
      'defaultRadius': config.getConfig<int>('defaultRadius', defaultValue: 5000),
      'maxResults': config.getConfig<int>('maxResults', defaultValue: 20),
    };
  }
  
  /// Get Firebase Functions base URL for the current environment
  String _getFunctionsBaseUrl() {
    final gcpConfig = getServiceConfig('gcp');
    final projectId = gcpConfig?.getConfig<String>('projectId', defaultValue: 'nutrisync-gcp-dev');
    final region = gcpConfig?.getConfig<String>('region', defaultValue: 'us-central1');
    
    return 'https://$region-$projectId.cloudfunctions.net';
  }
  
  /// Validate API key format
  bool isValidApiKey(String? apiKey, String serviceName) {
    if (apiKey == null || apiKey.isEmpty) return false;
    
    // Check for placeholder keys
    if (apiKey.startsWith('YOUR_') || 
        apiKey.startsWith('REPLACE_') || 
        apiKey.startsWith('DEMO_') ||
        apiKey == 'your-api-key-here') {
      return false;
    }
    
    // Service-specific validation
    switch (serviceName) {
      case 'elevenlabs':
        return apiKey.length >= 32 && !apiKey.contains(' ');
      case 'googlemaps':
      case 'googleplaces':
        return apiKey.startsWith('AIza') && apiKey.length == 39;
      default:
        return apiKey.length >= 10;
    }
  }
  
  /// Reload configuration (useful for hot reload)
  Future<void> reload() async {
    _isInitialized = false;
    _apiConfigs = null;
    _encryptedKeys = null;
    _lastLoadTime = null;
    
    await initialize(environment: _currentEnvironment);
  }
  
  /// Switch environment and reload configuration
  Future<void> switchEnvironment(String newEnvironment) async {
    if (_currentEnvironment == newEnvironment) return;
    
    _currentEnvironment = newEnvironment;
    await reload();
    
    if (kDebugMode) {
      print('✓ Switched to environment: $newEnvironment');
    }
  }
  
  /// Get configuration summary for debugging
  Map<String, dynamic> getConfigurationSummary() {
    return {
      'environment': _currentEnvironment,
      'initialized': _isInitialized,
      'cacheValid': isCacheValid,
      'lastLoadTime': _lastLoadTime?.toIso8601String(),
      'services': _apiConfigs?.keys.toList() ?? [],
      'enabledServices': _apiConfigs?.entries
          .where((entry) => entry.value.isEnabled)
          .map((entry) => entry.key)
          .toList() ?? [],
    };
  }
  
  /// Reset configuration (for testing)
  @visibleForTesting
  void reset() {
    _apiConfigs = null;
    _encryptedKeys = null;
    _currentEnvironment = null;
    _lastLoadTime = null;
    _isInitialized = false;
  }
  
  /// Set configuration directly (for testing)
  @visibleForTesting
  void setConfig(Map<String, ApiServiceConfig> configs, String environment) {
    _apiConfigs = configs;
    _currentEnvironment = environment;
    _lastLoadTime = DateTime.now();
    _isInitialized = true;
  }
}

/// API Service Configuration Model
class ApiServiceConfig {
  final String serviceName;
  final String baseUrl;
  final String? apiKey;
  final Duration timeout;
  final int retryAttempts;
  final int rateLimitPerMinute;
  final bool isEnabled;
  final Map<String, dynamic> additionalConfig;
  
  const ApiServiceConfig({
    required this.serviceName,
    required this.baseUrl,
    this.apiKey,
    required this.timeout,
    required this.retryAttempts,
    required this.rateLimitPerMinute,
    required this.isEnabled,
    this.additionalConfig = const {},
  });
  
  /// Check if the service configuration is valid
  bool get isValid {
    return serviceName.isNotEmpty &&
           baseUrl.isNotEmpty &&
           timeout.inMilliseconds > 0 &&
           retryAttempts >= 0 &&
           rateLimitPerMinute > 0;
  }
  
  /// Check if API key is required and present
  bool get hasValidApiKey {
    // Some services (like GCP) don't use API keys
    if (serviceName == 'gcp') return true;
    
    return apiKey != null && 
           apiKey!.isNotEmpty && 
           !apiKey!.startsWith('YOUR_') &&
           !apiKey!.startsWith('DEMO_');
  }
  
  /// Get configuration value by key
  T? getConfig<T>(String key, {T? defaultValue}) {
    final value = additionalConfig[key];
    if (value is T) return value;
    return defaultValue;
  }
  
  /// Create a copy with updated values
  ApiServiceConfig copyWith({
    String? serviceName,
    String? baseUrl,
    String? apiKey,
    Duration? timeout,
    int? retryAttempts,
    int? rateLimitPerMinute,
    bool? isEnabled,
    Map<String, dynamic>? additionalConfig,
  }) {
    return ApiServiceConfig(
      serviceName: serviceName ?? this.serviceName,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      rateLimitPerMinute: rateLimitPerMinute ?? this.rateLimitPerMinute,
      isEnabled: isEnabled ?? this.isEnabled,
      additionalConfig: additionalConfig ?? this.additionalConfig,
    );
  }
  
  @override
  String toString() {
    return 'ApiServiceConfig(serviceName: $serviceName, baseUrl: $baseUrl, '
           'isEnabled: $isEnabled, hasApiKey: ${apiKey != null})';
  }
}

/// Extension for easier access to common configurations
extension ApiServiceConfigExtension on ApiServiceConfig {
  /// Get headers for API requests
  Map<String, String> get headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'NutriSync/${additionalConfig['version'] ?? '1.0.0'}',
    };
    
    // Add service-specific headers
    switch (serviceName) {
      case 'elevenlabs':
        if (apiKey != null) {
          headers['xi-api-key'] = apiKey!;
        }
        break;
      case 'googlemaps':
      case 'googleplaces':
        // API key is usually added as query parameter for Google APIs
        break;
      case 'gcp':
        // GCP uses OAuth2 tokens, handled separately
        break;
    }
    
    return headers;
  }
  
  /// Get query parameters for API requests
  Map<String, String> get queryParameters {
    final params = <String, String>{};
    
    // Add service-specific query parameters
    switch (serviceName) {
      case 'googlemaps':
      case 'googleplaces':
        if (apiKey != null) {
          params['key'] = apiKey!;
        }
        break;
    }
    
    return params;
  }
}